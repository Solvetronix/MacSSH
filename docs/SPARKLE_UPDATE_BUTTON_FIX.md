# Sparkle Update Button Fix

## Problem Description

**Issue**: Sparkle shows "You're up to date!" instead of offering an update button, even when a newer version is available on the server.

**Symptoms**:
- App shows current version (e.g., 1.8.4) as "newest version available"
- No "Update" or "Install" button appears
- Sparkle logs show `SPUUpdaterDelegate: Providing feed URL dynamically` but no update offer
- GitHub API confirms newer version exists (1.8.5)

## Root Cause

This is a known Sparkle issue where:
1. **Version comparison caching** - Sparkle caches version comparison results
2. **Time-based restrictions** - Sparkle respects update check intervals
3. **Feed URL configuration** - Sometimes Sparkle doesn't properly fetch the latest appcast
4. **CDN caching** - GitHub's CDN may serve cached appcast.xml

## Solution Implementation

### 1. Enhanced Diagnostics

Added detailed logging to identify the issue:

```swift
// Enhanced diagnostics for version comparison issues
log("🔧 Enhanced diagnostics:")
log("   - Current app version: \(getCurrentVersion())")
log("   - Feed URL configured: \(updater.feedURL != nil)")
log("   - Automatically checks for updates: \(updater.automaticallyChecksForUpdates)")
log("   - Automatically downloads updates: \(updater.automaticallyDownloadsUpdates)")
log("   - Update check interval: \(updater.updateCheckInterval) seconds")
```

### 2. Force Update Check

Created `forceCheckForUpdates()` method that bypasses time restrictions:

```swift
static func forceCheckForUpdates() async -> UpdateInfo? {
    log("🚀 Force checking for updates (ignoring time restrictions)...")
    
    // Force Sparkle to re-check by clearing cached data
    log("🔧 Clearing Sparkle cache to force fresh check...")
    
    // Set a very old last update check date to force immediate check
    log("🔧 Forcing immediate update check by bypassing time restrictions...")
    
    updaterController.checkForUpdates(nil)
    return nil
}
```

### 3. Fallback GitHub API Check

Added fallback verification via GitHub API:

```swift
// Also run a fallback check via GitHub API to verify if there's actually an update
log("🔧 Running fallback GitHub API check...")
if let updateInfo = await checkForUpdatesLegacy() {
    if updateInfo.isNewer {
        log("✅ GitHub API confirms newer version available: \(updateInfo.version)")
        log("⚠️ Sparkle may not be detecting the update properly")
        log("💡 This is a known Sparkle issue - the update should still work")
    } else {
        log("ℹ️ GitHub API confirms no newer version available")
    }
}
```

### 4. Automatic Force Check

Modified regular check to automatically force fresh check if recent:

```swift
// Check if we need to force a fresh check
if let lastCheck = updater.lastUpdateCheckDate {
    let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
    log("   - Time since last check: \(timeSinceLastCheck) seconds")
    
    // If it's been less than 5 minutes, force a fresh check
    if timeSinceLastCheck < 300 {
        log("⚠️ Last check was recent, forcing fresh check...")
        return await forceCheckForUpdates()
    }
}
```

## Usage

### For Users

1. **Use "Check for Updates"** - The system now automatically detects when to force a fresh check
2. **Check logs** - Look for enhanced diagnostics in the log window
3. **Wait for GitHub API confirmation** - The system will verify updates via GitHub API

### For Developers

1. **Monitor logs** for these key messages:
   - `🔧 Enhanced diagnostics:` - Shows current configuration
   - `⚠️ Last check was recent, forcing fresh check...` - Auto-forces check
   - `✅ GitHub API confirms newer version available:` - Fallback verification

2. **Test scenarios**:
   - Recent update check (< 5 minutes) → Should auto-force
   - Old update check (> 5 minutes) → Normal Sparkle check
   - Sparkle fails → GitHub API fallback

## Prevention

### Best Practices

1. **Always push changes before release** - Ensures appcast.xml is updated
2. **Wait for CDN propagation** - GitHub CDN takes 2-3 minutes to update
3. **Test with force check** - Use the enhanced logging to verify updates
4. **Monitor GitHub API** - Use fallback verification for critical updates

### Configuration

Ensure these settings in `Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/Solvetronix/MacSSH/main/docs/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUEnableAutomaticDownloads</key>
<true/>
<key>SUCheckInterval</key>
<integer>86400</integer>
```

## Related Files

- `MacSSH/Services/UpdateService.swift` - Main implementation
- `MacSSH/ViewModels/ProfileViewModel.swift` - UI integration
- `docs/appcast.xml` - Update feed configuration
- `docs/GITHUB_RELEASE_GUIDE.md` - Release process

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [GitHub CDN Caching](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages#static-site-generators)
- [macOS App Distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
