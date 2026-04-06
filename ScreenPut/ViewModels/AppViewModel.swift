import Foundation
import SwiftUI
import AppKit
import ServiceManagement

@Observable
@MainActor
final class AppViewModel {
    var recentScreenshots: [ScreenshotRecord] = []
    var isUploading = false
    var errorMessage: String?
    var uploadCount = 0
    private var uploadTask: Task<Void, Never>?

    // Settings
    var storageProvider: StorageProvider {
        didSet { saveSettings() }
    }
    var s3Config: S3Config {
        didSet { saveSettings() }
    }
    var azureConfig: AzureConfig {
        didSet { saveSettings() }
    }
    var deleteAfterUpload: Bool {
        didSet { UserDefaults.standard.set(deleteAfterUpload, forKey: "deleteAfterUpload") }
    }
    var resizeImages: Bool {
        didSet { UserDefaults.standard.set(resizeImages, forKey: "resizeImages") }
    }
    var resizeScale: Double {
        didSet { UserDefaults.standard.set(resizeScale, forKey: "resizeScale") }
    }
    var launchAtLogin: Bool = false {
        didSet { toggleLaunchAtLogin() }
    }

    private let watcher = FolderWatcher()
    private let historyURL: URL

    init() {
        let defaults = UserDefaults.standard

        // Load storage provider
        if let raw = defaults.string(forKey: "storageProvider"),
           let provider = StorageProvider(rawValue: raw) {
            storageProvider = provider
        } else {
            storageProvider = .s3
        }

        // Load S3 config with secret from Keychain
        var loadedS3 = S3Config()
        if let data = defaults.data(forKey: "s3Config"),
           let config = try? JSONDecoder().decode(S3Config.self, from: data) {
            loadedS3 = config
        }
        loadedS3.secretAccessKey = KeychainHelper.load(key: "s3SecretAccessKey") ?? ""
        s3Config = loadedS3

        // Load Azure config with SAS token from Keychain
        var loadedAzure = AzureConfig()
        if let data = defaults.data(forKey: "azureConfig"),
           let config = try? JSONDecoder().decode(AzureConfig.self, from: data) {
            loadedAzure = config
        }
        loadedAzure.sasToken = KeychainHelper.load(key: "azureSasToken") ?? ""
        azureConfig = loadedAzure

        deleteAfterUpload = defaults.bool(forKey: "deleteAfterUpload")
        resizeImages = defaults.object(forKey: "resizeImages") as? Bool ?? true
        resizeScale = defaults.object(forKey: "resizeScale") as? Double ?? 0.8

        // History persistence
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ScreenPut")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        historyURL = appDir.appendingPathComponent("history.json")
        loadHistory()

        // Setup
        NotificationManager.requestPermission()
        ScreenshotLocationManager.ensureConfigured()
        setupWatcher()
    }

    // MARK: - File Watching

    private func setupWatcher() {
        watcher.onNewFiles = { [weak self] urls in
            Task { @MainActor in
                self?.uploadTask = Task { @MainActor in
                    await self?.processNewFiles(urls)
                }
            }
        }
        watcher.startWatching(directory: ScreenshotLocationManager.screenshotDirectory)
    }

    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        isUploading = false
        errorMessage = "Upload cancelled"
    }

    private func processNewFiles(_ urls: [URL]) async {
        for url in urls {
            guard !Task.isCancelled else { break }
            do {
                isUploading = true
                errorMessage = nil

                // Wait for MOV files to finish writing
                if url.pathExtension.lowercased() == "mov" {
                    try await waitForFileStability(url)
                }

                // Small delay to ensure PNG is fully written
                if url.pathExtension.lowercased() == "png" {
                    try await Task.sleep(for: .milliseconds(500))
                }

                let data = try Data(contentsOf: url)

                // Optionally resize PNG
                let uploadData: Data
                if ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) && resizeImages {
                    uploadData = resizeImage(data: data, scale: resizeScale) ?? data
                } else {
                    uploadData = data
                }

                // Upload
                let remoteURL = try await uploadWithRetry(fileURL: url, data: uploadData)

                // Copy URL
                let urlString = remoteURL.absoluteString
                #if DEBUG
                print("[Clipboard] Copying: \(urlString)")
                #endif
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(urlString, forType: .string)

                // Record
                let ext = url.pathExtension.lowercased()
                let fileType: ScreenshotRecord.FileType = ext == "mov" ? .mov :
                    (ext == "jpg" || ext == "jpeg") ? .jpg : .png

                let record = ScreenshotRecord(
                    id: UUID(),
                    originalFileName: url.lastPathComponent,
                    capturedAt: Date(),
                    uploadedAt: Date(),
                    remoteURL: remoteURL,
                    fileSizeBytes: Int64(data.count),
                    fileType: fileType
                )
                recentScreenshots.insert(record, at: 0)
                if recentScreenshots.count > 50 {
                    recentScreenshots.removeLast()
                }
                uploadCount += 1
                saveHistory()

                // Notify
                NotificationManager.send(
                    title: "Screenshot Uploaded",
                    body: "URL copied to clipboard"
                )

                // Delete original if configured
                if deleteAfterUpload {
                    try? FileManager.default.removeItem(at: url)
                }

                isUploading = false
            } catch {
                isUploading = false
                errorMessage = error.localizedDescription
                NotificationManager.send(
                    title: "Upload Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Upload with Retry

    private func uploadWithRetry(fileURL: URL, data: Data, maxRetries: Int = 3) async throws -> URL {
        let uploader = makeUploader()
        var lastError: Error = UploadError.notConfigured

        for attempt in 0..<maxRetries {
            do {
                return try await uploader.upload(fileURL: fileURL, data: data)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError
    }

    private func makeUploader() -> StorageUploader {
        switch storageProvider {
        case .s3:
            return S3Uploader(config: s3Config)
        case .azure:
            return AzureBlobUploader(config: azureConfig)
        }
    }

    // MARK: - File Stability

    private func waitForFileStability(_ url: URL) async throws {
        var previousSize: Int64 = -1
        for _ in 0..<60 {
            try await Task.sleep(for: .seconds(1))
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs[.size] as? Int64) ?? 0
            if size == previousSize && size > 0 { return }
            previousSize = size
        }
    }

    // MARK: - Image Resize

    private func resizeImage(data: Data, scale: Double) -> Data? {
        guard let nsImage = NSImage(data: data) else { return nil }
        let originalSize = nsImage.size
        let newWidth = originalSize.width * scale
        let newHeight = originalSize.height * scale
        let newSize = NSSize(width: newWidth, height: newHeight)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        nsImage.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }

    // MARK: - Persistence

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(storageProvider.rawValue, forKey: "storageProvider")

        // Save S3 config (without secret key)
        var s3ForSaving = s3Config
        let s3Secret = s3ForSaving.secretAccessKey
        s3ForSaving.secretAccessKey = ""
        if let data = try? JSONEncoder().encode(s3ForSaving) {
            defaults.set(data, forKey: "s3Config")
        }
        KeychainHelper.save(key: "s3SecretAccessKey", value: s3Secret)

        // Save Azure config (without SAS token)
        var azureForSaving = azureConfig
        let sasToken = azureForSaving.sasToken
        azureForSaving.sasToken = ""
        if let data = try? JSONEncoder().encode(azureForSaving) {
            defaults.set(data, forKey: "azureConfig")
        }
        KeychainHelper.save(key: "azureSasToken", value: sasToken)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(recentScreenshots) {
            try? data.write(to: historyURL)
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let records = try? JSONDecoder().decode([ScreenshotRecord].self, from: data) else {
            return
        }
        recentScreenshots = records
        uploadCount = records.count
    }

    // MARK: - Launch at Login

    private func toggleLaunchAtLogin() {
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func copyURL(_ url: URL) {
        ClipboardManager.copy(url.absoluteString)
        NotificationManager.send(title: "Copied", body: "URL copied to clipboard")
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.screenput.app",
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.screenput.app",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
