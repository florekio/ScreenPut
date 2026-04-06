import Foundation

@Observable
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var knownFiles: Set<String> = []
    var onNewFiles: (([URL]) -> Void)?

    func startWatching(directory: URL) {
        stopWatching()

        // Snapshot existing files so we don't re-upload old ones
        knownFiles = Set(existingFileNames(in: directory))

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            #if DEBUG
            print("[FolderWatcher] Failed to open directory: \(directory.path)")
            #endif
            return
        }
        self.fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange(directory: directory)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
        #if DEBUG
        print("[FolderWatcher] Watching: \(directory.path)")
        #endif
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    func markAsKnown(_ fileName: String) {
        knownFiles.insert(fileName)
    }

    private func handleDirectoryChange(directory: URL) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let validExtensions: Set<String> = ["png", "jpg", "jpeg", "mov", "mp4"]
        let newFiles = items.filter { url in
            let ext = url.pathExtension.lowercased()
            let name = url.lastPathComponent
            return validExtensions.contains(ext) && !knownFiles.contains(name)
        }

        if !newFiles.isEmpty {
            for file in newFiles {
                knownFiles.insert(file.lastPathComponent)
            }
            onNewFiles?(newFiles)
        }
    }

    private func existingFileNames(in directory: URL) -> [String] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return items.map(\.lastPathComponent)
    }

    deinit {
        stopWatching()
    }
}
