import Foundation
import AppKit

class UpdateService {
    private static let repositoryOwner = "Solvetronix" // Replace with your GitHub username
    private static let repositoryName = "MacSSH" // Replace with your repository name
    private static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    /// Checks for available updates from GitHub
    static func checkForUpdates() async -> UpdateInfo? {
        print("🔍 [UpdateService] Starting update check...")
        print("🔍 [UpdateService] Current version: \(currentVersion)")
        
        let urlString = "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest"
        print("🔍 [UpdateService] Checking URL: \(urlString)")
        
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
            
            print("🔍 [UpdateService] HTTP Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [UpdateService] Failed to fetch release info: \(httpResponse.statusCode)")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let release = try decoder.decode(GitHubRelease.self, from: data)
            print("🔍 [UpdateService] Found release: \(release.tagName)")
            
            // Find .dmg asset
            guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
                print("❌ [UpdateService] No .dmg file found in release")
                return nil
            }
            
            // Parse version and compare
            let releaseVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            let isNewer = compareVersions(releaseVersion, currentVersion) > 0
            
            // TEMPORARY: Always show update for testing purposes
            let alwaysShowUpdate = true
            
            print("🔍 [UpdateService] Release version: \(releaseVersion)")
            print("🔍 [UpdateService] Is newer: \(isNewer)")
            print("🔍 [UpdateService] Always show update (testing): \(alwaysShowUpdate)")
            
            let dateFormatter = ISO8601DateFormatter()
            let publishedDate = dateFormatter.date(from: release.publishedAt) ?? Date()
            
            return UpdateInfo(
                version: releaseVersion,
                downloadUrl: dmgAsset.browserDownloadUrl,
                releaseNotes: release.body,
                isNewer: alwaysShowUpdate, // TEMPORARY: Always show as newer for testing
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
    
    /// Installs the downloaded update
    static func installUpdate(from fileURL: URL) async -> Bool {
        print("🔍 [UpdateService] Starting update installation...")
        print("🔍 [UpdateService] File URL: \(fileURL.path)")
        
        do {
            // Mount the .dmg file
            let mountProcess = Process()
            mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            mountProcess.arguments = ["attach", fileURL.path, "-nobrowse"]
            
            let mountPipe = Pipe()
            mountProcess.standardOutput = mountPipe
            mountProcess.standardError = mountPipe
            
            try mountProcess.run()
            mountProcess.waitUntilExit()
            
            let mountOutput = String(data: mountPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("🔍 [UpdateService] Mount output: \(mountOutput)")
            
            // Extract volume path from output
            let lines = mountOutput.components(separatedBy: .newlines)
            var volumePath: String?
            
            for line in lines {
                if line.contains("/Volumes/") && line.contains("MacSSH") {
                    let components = line.components(separatedBy: .whitespaces)
                    for component in components {
                        if component.hasPrefix("/Volumes/") {
                            volumePath = component
                            break
                        }
                    }
                    break
                }
            }
            
            guard let volumePath = volumePath else {
                print("❌ [UpdateService] Could not find mounted volume")
                return false
            }
            
            print("🔍 [UpdateService] Found volume: \(volumePath)")
            
            // Copy the new app to Applications
            let sourceAppPath = "\(volumePath)/MacSSH.app"
            let destAppPath = "/Applications/MacSSH.app"
            
            // Remove old app first
            let removeProcess = Process()
            removeProcess.executableURL = URL(fileURLWithPath: "/bin/rm")
            removeProcess.arguments = ["-rf", destAppPath]
            
            try removeProcess.run()
            removeProcess.waitUntilExit()
            
            print("🔍 [UpdateService] Removed old app")
            
            // Copy new app
            let copyProcess = Process()
            copyProcess.executableURL = URL(fileURLWithPath: "/bin/cp")
            copyProcess.arguments = ["-R", sourceAppPath, destAppPath]
            
            try copyProcess.run()
            copyProcess.waitUntilExit()
            
            print("🔍 [UpdateService] Copied new app")
            
            // Unmount the volume
            let unmountProcess = Process()
            unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmountProcess.arguments = ["detach", volumePath]
            
            try unmountProcess.run()
            unmountProcess.waitUntilExit()
            
            print("🔍 [UpdateService] Unmounted volume")
            
            // Wait a bit for file system to settle
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Restart the application
            print("🔍 [UpdateService] Restarting application...")
            await restartApplication()
            
            return true
            
        } catch {
            print("❌ [UpdateService] Error installing update: \(error)")
            return false
        }
    }
    
    /// Restarts the current application
    private static func restartApplication() async {
        print("🔍 [UpdateService] Preparing to restart application...")
        
        // Get the current app bundle path
        let appPath = Bundle.main.bundlePath
        if appPath.isEmpty {
            print("❌ [UpdateService] Could not get app bundle path")
            return
        }
        
        print("🔍 [UpdateService] App path: \(appPath)")
        
        // Create a script to restart the app
        let script = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """
        
        let tempScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("restart_app.sh")
        
        do {
            try script.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            
            // Make script executable
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", tempScriptURL.path]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            // Run the restart script
            let restartProcess = Process()
            restartProcess.executableURL = tempScriptURL
            try restartProcess.run()
            
            print("✅ [UpdateService] Restart script executed")
            
            // Exit the current app
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔍 [UpdateService] Exiting application...")
                NSApplication.shared.terminate(nil)
            }
            
        } catch {
            print("❌ [UpdateService] Error creating restart script: \(error)")
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
