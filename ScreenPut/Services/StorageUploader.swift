import Foundation

protocol StorageUploader {
    func upload(fileURL: URL, data: Data) async throws -> URL
}

enum UploadError: LocalizedError {
    case serverError(statusCode: Int, body: String)
    case notConfigured
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serverError(let code, let body):
            return "Upload failed (HTTP \(code)): \(body)"
        case .notConfigured:
            return "Storage not configured. Open Settings to add credentials."
        case .invalidResponse:
            return "Invalid response from storage service."
        }
    }
}
