import Foundation
import AppKit

class UpdateService {
    private static let repositoryOwner = "dmitryborisenko" // Replace with your GitHub username
    private static let repositoryName = "MacSSH" // Replace with your repository name
    private static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    /// Checks for available updates from GitHub
    static func checkForUpdates() async -> UpdateInfo? {
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL for GitHub API")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to fetch release info: \(response)")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            
            // Find .dmg asset
            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                print("❌ No .dmg file found in release")
                return nil
            }
            
            // Parse version and compare
            let releaseVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            let isNewer = compareVersions(releaseVersion, currentVersion) > 0
            
            let dateFormatter = ISO8601DateFormatter()
            let publishedDate = dateFormatter.date(from: release.publishedAt) ?? Date()
            
            return UpdateInfo(
                version: releaseVersion,
                downloadUrl: dmgAsset.browserDownloadUrl,
                releaseNotes: release.body,
                isNewer: isNewer,
                publishedAt: publishedDate
            )
            
        } catch {
            print("❌ Error checking for updates: \(error)")
            return nil
        }
    }
    
    /// Downloads the update file
    static func downloadUpdate(from urlString: String) async -> URL? {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid download URL")
            return nil
        }
        
        let documentsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileName = url.lastPathComponent
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to download update: \(response)")
                return nil
            }
            
            try data.write(to: destinationURL)
            print("✅ Update downloaded to: \(destinationURL.path)")
            return destinationURL
            
        } catch {
            print("❌ Error downloading update: \(error)")
            return nil
        }
    }
    
    /// Installs the downloaded update
    static func installUpdate(from fileURL: URL) async -> Bool {
        do {
            // Open the .dmg file
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [fileURL.path]
            
            try process.run()
            process.waitUntilExit()
            
            print("✅ Update installer opened")
            return true
            
        } catch {
            print("❌ Error installing update: \(error)")
            return false
        }
    }
    
    /// Compares two version strings
    private static func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.components(separatedBy: ".").compactMap { Int($0) }
        let components2 = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxLength = max(components1.count, components2.count)
        
        for i in 0..<maxLength {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            
            if v1 > v2 { return 1 }
            if v1 < v2 { return -1 }
        }
        
        return 0
    }
    
    /// Gets current app version
    static func getCurrentVersion() -> String {
        return currentVersion
    }
    
    /// Opens GitHub releases page
    static func openGitHubReleases() {
        let urlString = "https://github.com/\(repositoryOwner)/\(repositoryName)/releases"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
