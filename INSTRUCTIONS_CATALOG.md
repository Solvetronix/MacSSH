# 📚 MacSSH Instructions and Documentation Catalog

## 📁 Documentation Structure

### 📖 Main Documentation
- **`README.md`** - Main project file with description and installation instructions
- **`docs/README.md`** - Documentation in docs folder

### 🔄 Automatic Update System

#### Main Instructions
- **`docs/AUTOMATIC_UPDATE_GUIDE.md`** - Complete guide for implementing automatic updates with Sparkle framework
- **`docs/SPARKLE_SETUP.md`** - Step-by-step instructions for setting up Sparkle in Xcode project
- **`docs/SPARKLE_XCODE_SETUP.md`** - 🆕 Detailed instruction for adding Sparkle to Xcode project
- **`docs/VERSION_MANAGEMENT_GUIDE.md`** - 🆕 Xcode Project Version Management (solving incorrect version problem)
- **`docs/QUICK_VERSION_FIX.md`** - 🆕 Quick Fix for Application Version Problem
- **`docs/SPARKLE_UPDATE_BUTTON_FIX.md`** - 🆕 Solution for Sparkle not showing update button despite newer version available
- **`docs/GITHUB_RELEASE_GUIDE.md`** - 🆕 GitHub Release Guide with GitHub CLI for Sparkle updates (⚠️ CRITICAL: version management)
- **`docs/UPDATE_SYSTEM_SUMMARY.md`** - Final summary of all changes in the update system

#### Configuration Files
- **`docs/appcast.xml`** - RSS feed for Sparkle automatic updates

### 📦 Releases and Versions

#### Release Instructions
- **`docs/RELEASE_INSTRUCTIONS.md`** - 🆕 **GLOBAL** release instructions for ALL versions

#### Release Notes
- **`docs/releases/RELEASE_NOTES_1.8.0.md`** - Release notes for 1.8.0
- **`docs/releases/RELEASE_NOTES_1.8.1.md`** - Release notes for 1.8.1
- **`docs/releases/RELEASE_NOTES_1.8.2.md`** - Release notes for 1.8.2
- **`docs/releases/RELEASE_NOTES_1.8.3.md`** - 🆕 Release notes for 1.8.3 with automatic updates
- **`docs/releases/RELEASE_NOTES_1.8.7.md`** - 🆕 Release notes for 1.8.7 with enhanced UI and logging system

#### GitHub Descriptions
- **`docs/releases/GITHUB_RELEASE_DESCRIPTION.md`** - General description for GitHub releases
- **`docs/releases/GITHUB_RELEASE_DESCRIPTION_1.8.1.md`** - Description for GitHub release 1.8.1
- **`docs/releases/GITHUB_RELEASE_DESCRIPTION_1.8.2.md`** - Description for GitHub release 1.8.2
- **`docs/releases/GITHUB_RELEASE_DESCRIPTION_1.8.3.md`** - 🆕 Description for GitHub release 1.8.3 with automatic updates
- **`docs/releases/GITHUB_RELEASE_DESCRIPTION_1.8.7.md`** - 🆕 Description for GitHub release 1.8.7 with enhanced UI and logging system

## 🎯 Instruction Categories

### 🚀 Development and Setup
1. **`docs/CODE_SIGNING_GUIDE.md`** - 🆕 **CRITICAL** Code signing with Apple Developer ID (prevents Gatekeeper warnings)
2. **`docs/SPARKLE_XCODE_SETUP.md`** - 🆕 Adding Sparkle to Xcode project
3. **`docs/SPARKLE_SETUP.md`** - Setting up automatic updates
4. **`docs/AUTOMATIC_UPDATE_GUIDE.md`** - Complete update guide
5. **`docs/VERSION_MANAGEMENT_GUIDE.md`** - 🆕 Xcode Project Version Management
6. **`docs/QUICK_VERSION_FIX.md`** - 🆕 Quick Fix for Application Version Problem
7. **`docs/SPARKLE_UPDATE_BUTTON_FIX.md`** - 🆕 Solution for Sparkle not showing update button despite newer version available
8. **`docs/SPARKLE_VERSION_FORMAT_FIX.md`** - 🆕 Fix for incorrect sparkle:version format in appcast.xml
9. **`docs/CRITICAL_APPCAST_UPDATE.md`** - 🆕 CRITICAL: Never forget to push appcast.xml after release
10. **`docs/GITHUB_RELEASE_GUIDE.md`** - 🆕 GitHub Release Guide with GitHub CLI (⚠️ CRITICAL: version management)

### 📋 Release Management
1. **`docs/RELEASE_INSTRUCTIONS.md`** - 🆕 **GLOBAL** release instructions for ALL versions
2. **`docs/GITHUB_RELEASE_GUIDE.md`** - 🆕 GitHub Release Guide with GitHub CLI for Sparkle updates (⚠️ CRITICAL: version management)
3. **`docs/releases/RELEASE_NOTES_*.md`** - Version-specific release notes
4. **`docs/releases/GITHUB_RELEASE_DESCRIPTION*.md`** - GitHub descriptions

### 📖 General Documentation
1. **`README.md`** - Main project documentation
2. **`docs/README.md`** - Documentation in docs folder
3. **`docs/UPDATE_SYSTEM_SUMMARY.md`** - Update system summary

## 🔧 Configuration Files
- **`docs/appcast.xml`** - RSS feed for Sparkle updates

## 📝 How to Use This Catalog

### For Developers
1. Start with `docs/SPARKLE_XCODE_SETUP.md` for adding Sparkle to the project
2. Study `docs/SPARKLE_SETUP.md` for setting up automatic updates
3. Study `docs/AUTOMATIC_UPDATE_GUIDE.md` for complete system understanding
4. **Use `docs/VERSION_MANAGEMENT_GUIDE.md` for solving application version problems**
5. **Use `docs/SPARKLE_UPDATE_BUTTON_FIX.md` for solving Sparkle update button issues**
6. **Use `docs/SPARKLE_VERSION_FORMAT_FIX.md` for fixing appcast.xml version format issues**
7. **Use `docs/CRITICAL_APPCAST_UPDATE.md` for the most common mistake that breaks updates**
8. **Use `docs/GITHUB_RELEASE_GUIDE.md` for creating releases with GitHub CLI (⚠️ CRITICAL: version management)**
7. Use `docs/RELEASE_INSTRUCTIONS.md` for creating ALL releases (global instruction with DMG cleanup requirements)

### For Users
1. Review `README.md` for basic information
2. Study `docs/releases/RELEASE_NOTES_*.md` for version information

### For Administrators
1. Use `docs/UPDATE_SYSTEM_SUMMARY.md` for understanding the architecture
2. Configure `docs/appcast.xml` for automatic updates
3. Follow instructions in `docs/releases/` for version management

## 🔄 Updating the Catalog

When adding new instruction files:
1. Add them to the appropriate section above
2. Update categories if necessary
3. Add a brief description of the file's purpose

## 📞 Related Files

### Update System Code
- `MacSSH/Services/UpdateService.swift` - Main update service
- `MacSSH/ViewModels/ProfileViewModel.swift` - UI integration
- `MacSSH/Views/UpdateView.swift` - Update interface
- `MacSSH/clonnerApp.swift` - Sparkle initialization

### Project Configuration
- `MacSSH/Info.plist` - Sparkle settings
- `MacSSH.xcodeproj/` - Xcode project settings
