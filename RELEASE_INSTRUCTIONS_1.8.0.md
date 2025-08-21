# MacSSH 1.8.0 Release Instructions

## 📦 Release Files Created

✅ **MacSSH-1.8.0.dmg** - Installer package (1.1MB)  
✅ **RELEASE_NOTES_1.8.0.md** - Detailed release notes  
✅ **GITHUB_RELEASE_DESCRIPTION.md** - GitHub release description  

## 🚀 How to Release

### 1. GitHub Release

1. Go to your GitHub repository
2. Click "Releases" in the right sidebar
3. Click "Create a new release"
4. Set the following:
   - **Tag version**: `v1.8.0`
   - **Release title**: `MacSSH 1.8.0 - Multiple File Browser Windows`
   - **Description**: Copy content from `GITHUB_RELEASE_DESCRIPTION.md`
5. Upload `MacSSH-1.8.0.dmg` as a release asset
6. Click "Publish release"

### 2. Automatic Update System

The app includes an automatic update system that will:
- Check GitHub releases for new versions
- Compare with current version (1.7.0 → 1.8.0)
- Show update dialog to users
- Download and install the new version

### 3. User Experience

When users have version 1.7.0 installed:
1. App will automatically detect the new version
2. Users will see an update notification
3. They can click "Download & Install"
4. The DMG will open automatically
5. Users drag the app to Applications folder
6. Their existing profiles and settings are preserved

## 🔧 Technical Details

### Version Changes
- **Previous**: 1.7.0
- **New**: 1.8.0
- **Update Type**: Bug fix release

### Key Fixes
- Multiple file browser windows now work correctly
- Each profile opens in its own window
- No more conflicts between different profiles
- Window titles display correct profile names

### Files Modified
- `Info.plist` - Version updated to 1.8.0
- `clonnerApp.swift` - File browser window management
- `ContentView.swift` - Window opening logic
- `WindowManager.swift` - New service for window management
- `ProfileViewModel.swift` - State management improvements

## 📋 Pre-Release Checklist

- [x] Version updated in Info.plist
- [x] Release build created successfully
- [x] DMG file created and tested
- [x] Release notes written
- [x] GitHub description prepared
- [x] All files are in English (no Russian text)

## 🎯 Post-Release Actions

1. **Monitor**: Check for any issues reported by users
2. **Update**: Update any documentation if needed
3. **Support**: Be ready to help users with installation
4. **Feedback**: Collect user feedback for next release

## 📞 Support Information

Users can:
- Check for updates in the app menu
- Download manually from GitHub releases
- Report issues through GitHub issues
- Get help through the app's built-in support

---

**Release Status**: ✅ Ready for Release  
**Created**: August 21, 2025  
**Version**: 1.8.0
