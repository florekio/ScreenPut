import Foundation
import CryptoKit

actor S3Uploader: StorageUploader {
    private let config: S3Config

    init(config: S3Config) {
        self.config = config
    }

    func upload(fileURL: URL, data: Data) async throws -> URL {
        guard config.isConfigured else { throw UploadError.notConfigured }

        let ext = fileURL.pathExtension.lowercased().isEmpty ? "png" : fileURL.pathExtension.lowercased()
        let fullKey = generateUniqueKey(ext: ext)
        let contentType = contentType(for: fileURL)

        // Path-style URL for bucket names with dots
        let host = "s3.\(config.region).amazonaws.com"
        let path = "/\(config.bucket)/\(fullKey)"
        let urlString = "https://\(host)\(path)"
        guard let url = URL(string: urlString) else { throw UploadError.invalidResponse }

        let payloadHash = sha256Hex(data)

        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        // Build canonical headers (each ends with \n)
        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders =
            "content-type:\(contentType)\n" +
            "host:\(host)\n" +
            "x-amz-content-sha256:\(payloadHash)\n" +
            "x-amz-date:\(amzDate)\n"

        // Build canonical request
        let canonicalRequest =
            "PUT\n" +
            path + "\n" +
            "\n" +
            canonicalHeaders + "\n" +
            signedHeaders + "\n" +
            payloadHash

        // String to sign
        let scope = "\(dateStamp)/\(config.region)/s3/aws4_request"
        let stringToSign =
            "AWS4-HMAC-SHA256\n" +
            amzDate + "\n" +
            scope + "\n" +
            sha256Hex(Data(canonicalRequest.utf8))

        // Signing key
        let kSecret = Data(("AWS4" + config.secretAccessKey).utf8)
        let kDate = hmacSHA256(key: kSecret, data: Data(dateStamp.utf8))
        let kRegion = hmacSHA256(key: kDate, data: Data(config.region.utf8))
        let kService = hmacSHA256(key: kRegion, data: Data("s3".utf8))
        let kSigning = hmacSHA256(key: kService, data: Data("aws4_request".utf8))

        let signature = hmacSHA256(key: kSigning, data: Data(stringToSign.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let authorization = "AWS4-HMAC-SHA256 Credential=\(config.accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")

        #if DEBUG
        print("[S3] Uploading \(data.count) bytes to \(urlString)")
        #endif

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse else { throw UploadError.invalidResponse }

        #if DEBUG
        print("[S3] Response: HTTP \(http.statusCode)")
        #endif

        if http.statusCode != 200 {
            let body = String(data: responseData, encoding: .utf8) ?? "no body"
            #if DEBUG
            print("[S3] Error body: \(body)")
            #endif
            throw UploadError.serverError(statusCode: http.statusCode, body: body)
        }

        // Return custom domain URL if configured
        if !config.customDomain.isEmpty {
            let domain = config.customDomain
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let publicURL = URL(string: "https://\(domain)/\(fullKey)") {
                #if DEBUG
                print("[S3] Public URL: \(publicURL)")
                #endif
                return publicURL
            }
        }

        return url
    }

    // MARK: - Helpers

    private func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac)
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func generateUniqueKey(ext: String) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let randomString = String((0..<16).map { _ in chars.randomElement()! })
        return "\(randomString).\(ext)"
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
