import Foundation
import AppKit

class UpdateService {
    private static let repositoryOwner = "Solvetronix" // Replace with your GitHub username
    private static let repositoryName = "MacSSH" // Replace with your repository name
    
    /// Checks for available updates from GitHub
    static func checkForUpdates() async -> UpdateInfo? {
        let currentVersion = getCurrentVersion()
        print("📝 [UpdateService] Starting update check...")
        print("📝 [UpdateService] Current version: \(currentVersion)")
        
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        print("📝 [UpdateService] Checking URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [UpdateService] Invalid URL for GitHub API")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [UpdateService] Invalid HTTP response")
                return nil
            }
            
            print("📝 [UpdateService] HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [UpdateService] Failed to fetch release info: \(httpResponse.statusCode)")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            print("📝 [UpdateService] Found release: \(release.tagName)")
            
            // Find .dmg asset
            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                print("❌ [UpdateService] No .dmg file found in release")
                return nil
            }
            
            // Parse version and compare
            let releaseVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            let isNewer = compareVersions(releaseVersion, currentVersion) > 0
            
            print("📝 [UpdateService] Release version: \(releaseVersion)")
            print("📝 [UpdateService] Is newer: \(isNewer)")
            
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
            print("❌ [UpdateService] Error checking for updates: \(error)")
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
    
    /// Installs the downloaded update using proper macOS installation method
    static func installUpdate(from fileURL: URL) async -> Bool {
        print("🔍 [UpdateService] Starting update installation...")
        print("🔍 [UpdateService] File URL: \(fileURL.path)")
        
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("❌ [UpdateService] DMG file does not exist: \(fileURL.path)")
                return false
            }
            
            print("✅ [UpdateService] DMG file exists")
            
            // Use NSWorkspace to open the DMG file
            // This will trigger the standard macOS installation process
            let success = NSWorkspace.shared.open(fileURL)
            
            if success {
                print("✅ [UpdateService] Successfully opened DMG file with NSWorkspace")
                
                // Wait a bit for the DMG to mount and user to see the installation dialog
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                // Show a helpful message to the user
                await MainActor.run {
                    showInstallationInstructions()
                }
                
                // Wait a bit more before exiting
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Exit the current app to allow installation
                await MainActor.run {
                    print("🔍 [UpdateService] Exiting application for installation...")
                    NSApplication.shared.terminate(nil)
                }
                
                return true
            } else {
                print("❌ [UpdateService] Failed to open DMG file with NSWorkspace")
                return false
            }
            
        } catch {
            print("❌ [UpdateService] Error installing update: \(error)")
            return false
        }
    }
    
    /// Shows installation instructions to the user
    private static func showInstallationInstructions() {
        let alert = NSAlert()
        alert.messageText = "Installation Instructions"
        alert.informativeText = """
        The DMG file has been opened. To complete the installation:
        
        1. Drag MacSSH to your Applications folder
        2. Replace the existing version if prompted
        3. Launch MacSSH from Applications
        
        This app will now close to allow the installation.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
        // Try to read version directly from Info.plist
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let version = plist["CFBundleShortVersionString"] as? String {
            print("🔍 [UpdateService] Version from Info.plist: \(version)")
            return version
        }
        
        // Fallback to Bundle.main.infoDictionary
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            print("🔍 [UpdateService] Version from Bundle.main: \(version)")
            return version
        }
        
        // Final fallback
        print("🔍 [UpdateService] Using fallback version: 1.0.0")
        return "1.0.0"
    }
    
    /// Opens GitHub releases page
    static func openGitHubReleases() {
        let urlString = "https://github.com/\(repositoryOwner)/\(repositoryName)/releases"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
