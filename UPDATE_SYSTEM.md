# MacSSH Update System

## Overview

MacSSH includes an automatic update system that checks for new versions on GitHub and allows users to download and install updates directly from the application.

## How It Works

### 1. **Version Checking**
- The app checks GitHub Releases API for the latest version
- Compares the current app version with the latest release
- Shows update dialog if a newer version is available

### 2. **Update Process**
- Downloads the `.dmg` file from GitHub releases
- Opens the installer automatically
- User completes the installation manually

### 3. **User Interface**
- Menu option "Check for Updates" in the main toolbar
- Update dialog showing version comparison and release notes
- Progress indicator during download
- Error handling for failed downloads

## For Users

### Checking for Updates
1. Click the "More Options" menu (⋯) in the toolbar
2. Select "Check for Updates"
3. If an update is available, a dialog will appear

### Installing Updates
1. In the update dialog, click "Download & Install"
2. Wait for the download to complete
3. The `.dmg` file will open automatically
4. Follow the installation instructions

### Manual Update
1. Click "View on GitHub" to open the releases page
2. Download the latest `.dmg` file manually
3. Install as usual

## For Developers

### Configuration
Update the following in `UpdateService.swift`:
```swift
private static let repositoryOwner = "your-github-username"
private static let repositoryName = "your-repository-name"
```

### Version Management
- Update `CFBundleShortVersionString` in `Info.plist`
- Use semantic versioning (e.g., "1.0.0", "1.1.0")
- Create GitHub releases with matching version tags

### GitHub Release Requirements
1. **Tag Name**: Must match version (e.g., "v1.1.0")
2. **Assets**: Must include a `.dmg` file
3. **Release Notes**: Will be displayed in the update dialog

### Example GitHub Release
```
Tag: v1.1.0
Title: MacSSH 1.1.0
Description: 
• Bug fixes and improvements
• New features added
• Performance enhancements

Assets:
- MacSSH-1.1.0.dmg
```

## Technical Details

### Files Added
- `UpdateInfo.swift` - Data models for update information
- `UpdateService.swift` - Core update functionality
- `UpdateView.swift` - Update dialog UI

### API Endpoints
- GitHub Releases API: `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- GitHub Releases Page: `https://github.com/{owner}/{repo}/releases`

### Error Handling
- Network connectivity issues
- Invalid release data
- Download failures
- Installation errors

### Security
- Downloads only from configured GitHub repository
- Validates file integrity
- Uses HTTPS for all network requests

## Troubleshooting

### Update Not Found
- Check GitHub repository configuration
- Verify release exists with correct tag
- Ensure `.dmg` file is attached to release

### Download Fails
- Check internet connection
- Verify GitHub API access
- Check file permissions in Downloads folder

### Installation Issues
- Ensure `.dmg` file downloaded completely
- Check macOS security settings
- Try manual installation from GitHub

## Future Enhancements

- [ ] Automatic background update checking
- [ ] Delta updates for smaller downloads
- [ ] Update notifications
- [ ] Rollback functionality
- [ ] Update scheduling
