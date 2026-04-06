import Foundation

struct ScreenshotRecord: Identifiable, Codable {
    let id: UUID
    let originalFileName: String
    let capturedAt: Date
    let uploadedAt: Date
    let remoteURL: URL
    let fileSizeBytes: Int64
    let fileType: FileType

    enum FileType: String, Codable {
        case png, jpg, mov
    }
}
