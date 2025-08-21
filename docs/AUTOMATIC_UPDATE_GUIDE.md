# MacSSH Automatic Update System Guide

## Overview

This guide explains how to implement proper automatic updates for MacSSH using the Sparkle framework, which is the same system used by professional applications like Telegram, Discord, and many others.

## What We've Implemented

### ✅ Professional Automatic Update System

We've replaced the manual DMG download system with a proper automatic update system using **Sparkle framework**, which provides:

- **Automatic update checking** on app launch
- **Background download** of updates
- **Silent installation** without user intervention
- **Automatic app restart** after installation
- **Professional update UI** with progress indicators
- **Digital signature verification** for security

### 🔧 Key Components

1. **Sparkle Framework Integration** - Professional update framework
2. **Appcast XML** - Update feed configuration
3. **Automatic Installation** - No manual DMG handling required
4. **Fallback System** - Legacy GitHub API as backup

## How It Works

### 1. Automatic Update Check
- App checks for updates automatically on launch
- Uses GitHub releases as the update source
- Compares versions and downloads if newer version available

### 2. Background Download
- Updates are downloaded in the background
- User can continue using the app during download
- Progress is shown in the update dialog

### 3. Automatic Installation
- Once downloaded, update installs automatically
- App restarts with new version
- No manual DMG mounting or file dragging required

### 4. Professional UI
- Native macOS update dialog
- Progress indicators and status messages
- Release notes display
- User can postpone or install immediately

## Setup Requirements

### 1. Add Sparkle Framework to Xcode Project

```swift
// In your Xcode project, add Sparkle as a dependency:
// File -> Add Package Dependencies
// URL: https://github.com/sparkle-project/Sparkle
```

### 2. Configure Info.plist

Add these keys to your `Info.plist`:

```xml
<key>SUFeedURL</key>
<string>https://github.com/Solvetronix/MacSSH/releases.atom</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUEnableAutomaticDownloads</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer>
```

### 3. Code Integration

The `UpdateService.swift` file now includes:

```swift
// Initialize Sparkle updater
UpdateService.initializeUpdater()

// Check for updates
let update = await UpdateService.checkForUpdates()

// Install update automatically
let success = await UpdateService.installUpdate()
```

## GitHub Releases Configuration

### 1. Release Structure
Your GitHub releases should include:
- **DMG file** for distribution
- **Version tag** (e.g., "v1.8.2")
- **Release notes** in the description
- **Digital signature** (optional but recommended)

### 2. Appcast Feed
The appcast.xml file provides the update feed:
- RSS format with Sparkle extensions
- Version information
- Download URLs
- Release notes
- Digital signatures

## Security Features

### 1. Digital Signatures
- Updates are cryptographically signed
- Prevents tampering and ensures authenticity
- Uses Ed25519 signatures

### 2. HTTPS Downloads
- All downloads use HTTPS
- Prevents man-in-the-middle attacks
- Ensures download integrity

### 3. Version Verification
- Compares version strings
- Prevents downgrade attacks
- Ensures update compatibility

## User Experience

### 1. Automatic Updates
- Updates check automatically on launch
- Background download while using app
- Silent installation when convenient

### 2. Manual Updates
- "Check for Updates" menu item
- Shows update dialog with options
- User can choose to install or postpone

### 3. Update Dialog
- Professional macOS-native UI
- Shows version comparison
- Displays release notes
- Progress indicators

## Troubleshooting

### Common Issues

1. **Updates not found**
   - Check GitHub release tags
   - Verify appcast.xml format
   - Ensure version comparison works

2. **Download fails**
   - Check network connectivity
   - Verify download URLs
   - Check file permissions

3. **Installation fails**
   - Check app permissions
   - Verify digital signatures
   - Ensure app is not running

### Debug Information

Enable debug logging by adding to `UpdateService.swift`:

```swift
print("🔧 [UpdateService] Debug: \(message)")
```

## Comparison with Previous System

### ❌ Old System (Manual DMG)
- User had to download DMG manually
- Required manual mounting and installation
- App had to be closed manually
- No progress indicators
- Error-prone installation process

### ✅ New System (Sparkle)
- Automatic background download
- Silent installation
- Automatic app restart
- Professional UI
- Digital signature verification
- Error handling and recovery

## Best Practices

### 1. Version Management
- Use semantic versioning (e.g., "1.0.0", "1.1.0")
- Tag releases consistently
- Include release notes

### 2. Testing
- Test updates on different macOS versions
- Verify installation process
- Check rollback functionality

### 3. User Communication
- Clear release notes
- Inform users about major changes
- Provide migration guides if needed

## Deployment Checklist

- [ ] Add Sparkle framework to Xcode project
- [ ] Configure Info.plist with update settings
- [ ] Create and host appcast.xml
- [ ] Sign DMG files with Ed25519
- [ ] Test update process thoroughly
- [ ] Verify automatic update checks
- [ ] Test manual update functionality
- [ ] Check error handling scenarios

## Conclusion

This implementation provides a professional, secure, and user-friendly automatic update system that matches the quality of commercial applications. Users will now experience seamless updates without any manual intervention, just like they do with Telegram, Discord, and other professional macOS applications.
