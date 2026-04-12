import Foundation

actor ShareXUploader: StorageUploader {
    private let config: ShareXConfig

    init(config: ShareXConfig) {
        self.config = config
    }

    func upload(fileURL: URL, data: Data) async throws -> URL {
        guard config.isConfigured else { throw UploadError.notConfigured }
        guard let requestURL = URL(string: config.requestURL) else {
            throw UploadError.invalidResponse
        }

        let boundary = "ScreenPut-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = config.requestType
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("ScreenPut/1.0", forHTTPHeaderField: "User-Agent")

        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Build multipart body
        var body = Data()

        for (key, value) in config.arguments {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        let filename = fileURL.lastPathComponent
        let mimeType = contentType(for: fileURL)
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(config.fileFormName)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        #if DEBUG
        print("[ShareX] Uploading to \(config.requestURL) (\(config.requestType))")
        print("[ShareX] File: \(filename) (\(mimeType), \(data.count) bytes)")
        print("[ShareX] Form field: \(config.fileFormName)")
        print("[ShareX] Arguments: \(config.arguments)")
        print("[ShareX] Body size: \(body.count) bytes")
        #endif

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        #if DEBUG
        let responseBody = String(data: responseData, encoding: .utf8) ?? "no body"
        print("[ShareX] Response: HTTP \(http.statusCode)")
        print("[ShareX] Body: \(responseBody)")
        #endif

        if http.statusCode < 200 || http.statusCode >= 300 {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "no body"
            throw UploadError.serverError(statusCode: http.statusCode, body: errorBody)
        }

        let urlString = try extractURL(from: responseData, pattern: config.responseURLPattern)
        guard let resultURL = URL(string: urlString) else {
            throw UploadError.invalidResponse
        }

        return resultURL
    }

    // MARK: - Response Parsing

    private func extractURL(from data: Data, pattern: String) throws -> String {
        let jsonPrefix = "$json:"
        let suffix = "$"

        guard pattern.contains(jsonPrefix) else {
            // No $json:...$ pattern — treat the raw response as the URL
            if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return raw
            }
            throw UploadError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UploadError.invalidResponse
        }

        var result = pattern

        // Replace all $json:path$ tokens in the pattern
        while let startRange = result.range(of: jsonPrefix) {
            let afterPrefix = result[startRange.upperBound...]
            guard let endRange = afterPrefix.range(of: suffix) else {
                break
            }

            let jsonPath = String(afterPrefix[afterPrefix.startIndex..<endRange.lowerBound])
            let fullToken = "\(jsonPrefix)\(jsonPath)\(suffix)"

            guard let value = resolveJSONPath(jsonPath, in: json) else {
                throw ShareXParseError.missingResponseField(jsonPath)
            }

            result = result.replacingOccurrences(of: fullToken, with: "\(value)")
        }

        return result
    }

    private func resolveJSONPath(_ path: String, in json: [String: Any]) -> Any? {
        let components = path.split(separator: ".").map(String.init)
        var current: Any = json
        for component in components {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else {
                return nil
            }
        }
        return current
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

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
