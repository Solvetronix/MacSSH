# MacSSH 1.8.0 - Multiple File Browser Windows

## 🎉 Major Fix: Multiple File Browser Windows

This release fixes a critical issue where opening file browsers from different profiles would show the same files and cause conflicts.

### ✅ What's Fixed

- **Multiple File Browser Windows**: Each profile now opens in its own separate file browser window
- **Independent State Management**: Each window maintains its own state and shows correct files for its profile
- **Window Title Accuracy**: Window titles now correctly display the associated profile name
- **No More Conflicts**: File browsers from different profiles no longer interfere with each other

### 🔧 Technical Improvements

- Added `WindowManager` service for better window management
- Enhanced `ProfileViewModel` with improved state isolation
- Updated SwiftUI components for better performance
- Improved thread safety in asynchronous operations

### 📋 System Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64) and Intel (x86_64) support
- 8GB RAM recommended

### 🚀 Installation

1. Download `MacSSH-1.8.0.dmg`
2. Open the DMG file
3. Drag MacSSH to your Applications folder
4. Launch MacSSH from Applications

### 🔄 Automatic Updates

The app will automatically check for updates. If you have a previous version installed, the update will be available through the app's update system.

---

**Release Date**: August 21, 2025  
**Version**: 1.8.0  
**Size**: ~1.1MB
