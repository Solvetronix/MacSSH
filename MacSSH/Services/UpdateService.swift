import Foundation
import AppKit
import Sparkle

class UpdateService {
    private static let repositoryOwner = "Solvetronix"
    private static let repositoryName = "MacSSH"
    
    // MARK: - Sparkle Integration
    
    private static var updater: SPUUpdater?
    private static var updaterController: SPUStandardUpdaterController?
    
    // MARK: - Logging
    
    static var logCallback: ((String) -> Void)?
    
    private static func log(_ message: String) {
        let timestamp = Date().timeIntervalSince1970
        let logMessage = "🔄 [\(timestamp)] [UpdateService] \(message)"
        print(logMessage)
        logCallback?(logMessage)
    }
    
    /// Initialize Sparkle updater
    static func initializeUpdater() {
        guard updater == nil else { 
            log("Updater already initialized, skipping...")
            return 
        }
        
        log("🔧 Initializing Sparkle updater...")
        
        // Create the updater controller
        updaterController = SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil)
        updater = updaterController?.updater
        
        if let updater = updater {
            log("✅ Updater controller created successfully")
            
            // Configure updater
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = true
            
            // Set update check interval (24 hours)
            updater.updateCheckInterval = 24 * 60 * 60
            
            log("✅ Updater configured - Auto checks: \(updater.automaticallyChecksForUpdates), Auto downloads: \(updater.automaticallyDownloadsUpdates)")
            log("✅ Update check interval: \(updater.updateCheckInterval) seconds (24 hours)")
            
            // Log current version
            let currentVersion = getCurrentVersion()
            log("📋 Current app version: \(currentVersion)")
            
            // Log feed URL
            if let feedURL = updater.feedURL {
                log("🔗 Feed URL: \(feedURL)")
            } else {
                log("⚠️ No feed URL configured")
            }
        } else {
            log("❌ Failed to create updater controller")
        }
        
        log("✅ Sparkle updater initialization completed")
    }
    
    /// Check for updates using Sparkle
    static func checkForUpdates() async -> UpdateInfo? {
        guard let updaterController = updaterController else {
            log("❌ Updater not initialized")
            return nil
        }
        
        log("🔍 Starting manual update check via Sparkle...")
        
        // Log current state
        if let updater = updater {
            log("📋 Current version: \(getCurrentVersion())")
            log("🔗 Feed URL: \(updater.feedURL?.absoluteString ?? "Not configured")")
            log("⏰ Last update check: \(updater.lastUpdateCheckDate?.description ?? "Never")")
            log("🔄 Update check interval: \(updater.updateCheckInterval) seconds")
        }
        
        // Use the standard Sparkle check for updates
        // Sparkle handles the UI automatically, so we don't need to return UpdateInfo
        log("🚀 Triggering Sparkle update check...")
        updaterController.checkForUpdates(nil)
        
        log("✅ Update check triggered - Sparkle will handle the UI")
        
        // Return nil since Sparkle handles everything automatically
        return nil
    }
    
    /// Install update automatically
    static func installUpdate() async -> Bool {
        guard let updaterController = updaterController else {
            print("❌ [UpdateService] Updater not initialized")
            return false
        }
        
        print("🔧 [UpdateService] Installing update...")
        
        // Sparkle handles installation automatically
        updaterController.checkForUpdates(nil)
        return true
    }
    
    /// Show update window
    static func showUpdateWindow() {
        guard let updaterController = updaterController else {
            print("❌ [UpdateService] Updater controller not initialized")
            return
        }
        
        print("📝 [UpdateService] Showing update window...")
        updaterController.checkForUpdates(nil)
    }
    
    // MARK: - Legacy GitHub API (Fallback)
    
    /// Legacy method for checking updates via GitHub API (fallback)
    static func checkForUpdatesLegacy() async -> UpdateInfo? {
        let currentVersion = getCurrentVersion()
        print("📝 [UpdateService] Starting legacy update check...")
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
    
    // MARK: - Utility Methods
    
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
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            print("🔍 [UpdateService] Version from Bundle.main: \(version)")
            return version
        }
        
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

// MARK: - UpdateInfo Extension for Sparkle

extension UpdateInfo {
    init?(from sparkleUpdateInfo: Any) {
        // For now, we'll use the legacy GitHub API
        // Sparkle 2.7.1 handles updates automatically through its UI
        return nil
    }
}
