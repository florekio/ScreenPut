import Foundation

actor AzureBlobUploader: StorageUploader {
    private let config: AzureConfig

    init(config: AzureConfig) {
        self.config = config
    }

    func upload(fileURL: URL, data: Data) async throws -> URL {
        guard config.isConfigured else { throw UploadError.notConfigured }

        let blobName = generateBlobName(from: fileURL)
        let host = "\(config.accountName).blob.core.windows.net"
        let uploadURLString = "https://\(host)/\(config.containerName)/\(blobName)?\(config.sasToken)"

        guard let uploadURL = URL(string: uploadURLString) else {
            throw UploadError.invalidResponse
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue(contentType(for: fileURL), forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("2024-11-04", forHTTPHeaderField: "x-ms-version")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else { throw UploadError.invalidResponse }

        if http.statusCode != 201 {
            throw UploadError.serverError(statusCode: http.statusCode, body: "Azure PUT failed")
        }

        // Public URL without SAS token
        let publicURLString = "https://\(host)/\(config.containerName)/\(blobName)"
        guard let publicURL = URL(string: publicURLString) else {
            throw UploadError.invalidResponse
        }

        return publicURL
    }

    private func generateBlobName(from url: URL) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let ext = url.pathExtension.lowercased()
        let finalExt = ext.isEmpty ? "png" : ext
        return "screenshots/\(formatter.string(from: Date()))/\(UUID().uuidString.prefix(8)).\(finalExt)"
    }

    private func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "mov": return "video/quicktime"
        case "mp4": return "video/mp4"
        default: return "application/octet-stream"
        }
    }
}
