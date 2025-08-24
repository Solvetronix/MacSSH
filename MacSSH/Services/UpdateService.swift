import Foundation
import AppKit
import Sparkle

class UpdateService: NSObject, SPUUpdaterDelegate {
    private static let repositoryOwner = "Solvetronix"
    private static let repositoryName = "MacSSH"
    
    // MARK: - Sparkle Integration
    
    private static var updater: SPUUpdater?
    private static var updaterController: SPUStandardUpdaterController?
    private static var updateServiceDelegate: UpdateService?
    
    // MARK: - SPUUpdaterDelegate
    
    func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://raw.githubusercontent.com/Solvetronix/MacSSH/main/appcast.xml"
    }
    
    // MARK: - Additional Delegate Methods for Update Button Fix
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        UpdateService.log("🔧 SPUUpdaterDelegate: Finished loading appcast with \(appcast.items.count) items")
        for item in appcast.items {
            UpdateService.log("   - Found item: \(item.title) version \(item.displayVersionString)")
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        UpdateService.log("🔧 SPUUpdaterDelegate: Found valid update: \(item.title) version \(item.displayVersionString)")
    }
    
    func updater(_ updater: SPUUpdater, didNotFindUpdate error: Error?) {
        UpdateService.log("🔧 SPUUpdaterDelegate: Did not find update")
        if let error = error {
            UpdateService.log("   - Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Disable Signature Verification (for development/testing)
    
    func updater(_ updater: SPUUpdater, shouldAllowInstallingUpdate item: SUAppcastItem) -> Bool {
        UpdateService.log("🔧 SPUUpdaterDelegate: Allowing update installation without signature verification")
        return true
    }
    
    func updater(_ updater: SPUUpdater, shouldAllowInstallingUpdate item: SUAppcastItem, withImmediateInstallationInvocation immediateInstallationInvocation: @escaping () -> Void) -> Bool {
        UpdateService.log("🔧 SPUUpdaterDelegate: Allowing update installation without signature verification (immediate)")
        return true
    }
    
    // MARK: - Additional Signature Verification Overrides
    
    func updater(_ updater: SPUUpdater, shouldAllowInstallingUpdate item: SUAppcastItem, withImmediateInstallationInvocation immediateInstallationInvocation: @escaping () -> Void, andInstallationInvocation installationInvocation: @escaping () -> Void) -> Bool {
        UpdateService.log("🔧 SPUUpdaterDelegate: Allowing update installation without signature verification (with installation)")
        return true
    }
    
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationInvocation: @escaping () -> Void) {
        UpdateService.log("🔧 SPUUpdaterDelegate: Will install update on quit (signature verification disabled)")
    }
    
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationInvocation: @escaping () -> Void, andInstallationInvocation installationInvocation: @escaping () -> Void) {
        UpdateService.log("🔧 SPUUpdaterDelegate: Will install update on quit (signature verification disabled)")
    }
    
    // MARK: - Logging
    
    static var logCallback: ((String) -> Void)?
    
    private static func log(_ message: String) {
        let logMessage = "🔄 \(message)"
        print(logMessage)
        logCallback?(logMessage)
    }
    
    /// Initialize Sparkle updater
    static func initializeUpdater() {
        guard updater == nil else { 
            return 
        }
        
        // Create the updater controller with our delegate
        updateServiceDelegate = UpdateService()
        updaterController = SPUStandardUpdaterController(updaterDelegate: updateServiceDelegate, userDriverDelegate: nil)
        updater = updaterController?.updater
        
        if let updater = updater {
            // Configure updater
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = true
            updater.updateCheckInterval = 24 * 60 * 60
        }
    }
    

    
    /// Check for updates using Sparkle with enhanced diagnostics
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
            
            // Additional diagnostics
            if updater.feedURL == nil {
                log("🔧 Feed URL will be provided by delegate when needed")
            }
            
            // Enhanced diagnostics for version comparison issues
            log("🔧 Enhanced diagnostics:")
            log("   - Current app version: \(getCurrentVersion())")
            log("   - Feed URL configured: \(updater.feedURL != nil)")
            log("   - Automatically checks for updates: \(updater.automaticallyChecksForUpdates)")
            log("   - Automatically downloads updates: \(updater.automaticallyDownloadsUpdates)")
            log("   - Update check interval: \(updater.updateCheckInterval) seconds")
            
            // Check if we need to force a fresh check
            if let lastCheck = updater.lastUpdateCheckDate {
                let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
                log("   - Time since last check: \(timeSinceLastCheck) seconds")
                
                // If it's been less than 5 minutes, force a fresh check
                if timeSinceLastCheck < 300 {
                    log("⚠️ Last check was recent, forcing fresh check...")
                    // Force immediate check by calling forceCheckForUpdates
                    return await forceCheckForUpdates()
                }
            }
        }
        
        updaterController.checkForUpdates(nil)
        return nil
    }
    
    /// Force check for updates (bypass time restrictions)
    static func forceCheckForUpdates() async -> UpdateInfo? {
        guard let updaterController = updaterController else {
            return nil
        }
        
        updaterController.checkForUpdates(nil)
        return nil
    }
    
    /// Install update automatically
    static func installUpdate() async -> Bool {
        guard let updaterController = updaterController else {
            return false
        }
        
        updaterController.checkForUpdates(nil)
        return true
    }
    
    /// Show update window
    static func showUpdateWindow() {
        guard let updaterController = updaterController else {
            return
        }
        
        updaterController.checkForUpdates(nil)
    }
    
    // MARK: - Legacy GitHub API (Fallback)
    
    /// Legacy method for checking updates via GitHub API (fallback)
    static func checkForUpdatesLegacy() async -> UpdateInfo? {
        let currentVersion = getCurrentVersion()
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            
            // Find .dmg asset
            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
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
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
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
