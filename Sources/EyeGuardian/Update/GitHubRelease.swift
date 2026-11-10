import Foundation

struct GitHubRelease: Decodable, Equatable {
    struct Asset: Codable, Equatable {
        let name: String
        let size: Int
        let digest: String?
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }

        init(name: String, size: Int, digest: String?, browserDownloadURL: URL) {
            self.name = name
            self.size = size
            self.digest = digest
            self.browserDownloadURL = browserDownloadURL
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let publishedAt: Date?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case publishedAt = "published_at"
        case htmlURL = "html_url"
        case draft, prerelease, assets
    }
}

struct UpdateRelease: Codable, Equatable {
    let version: UpdateVersion
    let tag: String
    let notes: String
    let publishedAt: Date?
    let dmg: GitHubRelease.Asset
    let signature: GitHubRelease.Asset
    let htmlURL: URL

    init(version: UpdateVersion,
         tag: String,
         notes: String,
         publishedAt: Date?,
         dmg: GitHubRelease.Asset,
         signature: GitHubRelease.Asset,
         htmlURL: URL) {
        self.version = version
        self.tag = tag
        self.notes = notes
        self.publishedAt = publishedAt
        self.dmg = dmg
        self.signature = signature
        self.htmlURL = htmlURL
    }

    init?(githubRelease: GitHubRelease) {
        guard !githubRelease.draft,
              !githubRelease.prerelease,
              let version = UpdateVersion.releaseTag(githubRelease.tagName) else {
            return nil
        }
        let dmgName = "EyeGuardian-\(version).dmg"
        guard let dmg = githubRelease.assets.first(where: { $0.name == dmgName }),
              let signature = githubRelease.assets.first(where: { $0.name == dmgName + ".sig" }) else {
            return nil
        }
        self.init(version: version,
                  tag: githubRelease.tagName,
                  notes: githubRelease.body ?? "",
                  publishedAt: githubRelease.publishedAt,
                  dmg: dmg,
                  signature: signature,
                  htmlURL: githubRelease.htmlURL)
    }
}

struct DownloadedUpdate: Codable, Equatable {
    let release: UpdateRelease
    let fileURL: URL
    let signature: String
}
