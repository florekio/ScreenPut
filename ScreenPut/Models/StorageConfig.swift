import Foundation

enum StorageProvider: String, Codable, CaseIterable {
    case s3 = "AWS S3"
    case azure = "Azure Blob Storage"
}

struct S3Config: Codable, Equatable {
    var bucket: String = ""
    var region: String = "us-east-1"
    var accessKeyID: String = ""
    var secretAccessKey: String = ""
    var pathPrefix: String = "screenshots/"
    var customDomain: String = ""

    var isConfigured: Bool {
        !bucket.isEmpty && !accessKeyID.isEmpty && !secretAccessKey.isEmpty
    }
}

struct AzureConfig: Codable, Equatable {
    var accountName: String = ""
    var containerName: String = ""
    var sasToken: String = ""

    var isConfigured: Bool {
        !accountName.isEmpty && !containerName.isEmpty && !sasToken.isEmpty
    }
}
