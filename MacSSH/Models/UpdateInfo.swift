import Foundation

struct UpdateInfo: Codable {
    let version: String
    let downloadUrl: String
    let releaseNotes: String
    let isNewer: Bool
    let publishedAt: Date
    
    init(version: String, downloadUrl: String, releaseNotes: String, isNewer: Bool, publishedAt: Date) {
        self.version = version
        self.downloadUrl = downloadUrl
        self.releaseNotes = releaseNotes
        self.isNewer = isNewer
        self.publishedAt = publishedAt
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let publishedAt: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}
