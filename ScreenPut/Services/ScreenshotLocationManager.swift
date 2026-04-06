import Foundation

enum ScreenshotLocationManager {
    static let screenshotDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Screenshots")
    }()

    static func ensureConfigured() {
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: screenshotDirectory,
            withIntermediateDirectories: true
        )

        // Set macOS screenshot location
        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = [
            "write", "com.apple.screencapture", "location",
            screenshotDirectory.path
        ]
        try? defaults.run()
        defaults.waitUntilExit()
    }
}
