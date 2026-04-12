import Foundation

struct ShareXConfig: Codable, Equatable {
    var name: String = ""
    var requestURL: String = ""
    var fileFormName: String = "file"
    var responseURLPattern: String = ""
    var headers: [String: String] = [:]
    var arguments: [String: String] = [:]
    var requestType: String = "POST"

    var isConfigured: Bool {
        !requestURL.isEmpty && !responseURLPattern.isEmpty
    }

    var secretHeaderKeys: [String] {
        let patterns = ["auth", "token", "key", "secret", "api-key", "apikey", "authorization"]
        return headers.keys.filter { key in
            patterns.contains(where: { key.lowercased().contains($0) })
        }
    }

    static func fromShareXJSON(_ jsonData: Data) throws -> ShareXConfig {
        guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ShareXParseError.invalidJSON
        }

        var config = ShareXConfig()
        config.name = dict["Name"] as? String ?? ""
        config.requestURL = dict["RequestURL"] as? String ?? ""
        config.fileFormName = dict["FileFormName"] as? String ?? "file"
        config.requestType = dict["RequestType"] as? String ?? "POST"
        config.responseURLPattern = dict["URL"] as? String ?? ""

        if let headers = dict["Headers"] as? [String: String] {
            config.headers = headers
        }
        if let args = dict["Arguments"] as? [String: String] {
            config.arguments = args
        }

        return config
    }
}

enum ShareXParseError: LocalizedError {
    case invalidJSON
    case missingResponseField(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid ShareX JSON format."
        case .missingResponseField(let path):
            return "Response field '\(path)' not found in server response."
        }
    }
}
