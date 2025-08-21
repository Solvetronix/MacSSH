# MacSSH 1.8.1 - Fixed Automatic Update System

## 🎉 Major Fix: Automatic Update System

This release completely fixes the automatic update system that was causing "Download Error" messages and preventing users from updating the application.

### ✅ What's Fixed

- **Automatic Update System**: Completely rewritten update installation process
- **Proper DMG Handling**: Now uses NSWorkspace to open DMG files correctly
- **User-Friendly Installation**: Clear instructions and proper app closure for installation
- **Automatic Update Checks**: App now checks for updates automatically on launch
- **Smart Update Frequency**: Prevents excessive update checks (once per hour maximum)

### 🔧 Technical Improvements

- **UpdateService.swift**: Completely rewritten installation logic
- **NSWorkspace Integration**: Proper macOS-native DMG handling
- **User Experience**: Better error messages and installation instructions
- **Performance**: Optimized update checking with time-based throttling
- **Reliability**: Removed problematic file system operations that required admin rights

### 🚀 How It Works Now

1. **Automatic Detection**: App checks for updates automatically when launched
2. **Download**: Updates are downloaded to Downloads folder
3. **Installation**: DMG file opens automatically with clear instructions
4. **User Action**: User drags app to Applications folder (standard macOS process)
5. **App Closure**: Current app closes to allow installation
6. **Launch**: User launches updated app from Applications

### 📋 System Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64) and Intel (x86_64) support
- 8GB RAM recommended

### 🚀 Installation

1. Download `MacSSH-1.8.1.dmg`
2. Open the DMG file
3. Drag MacSSH to your Applications folder
4. Launch MacSSH from Applications

### 🔄 Automatic Updates

The app will automatically check for updates on launch. If you have a previous version installed, the update will be available through the app's update system.

---

**Release Date**: August 21, 2025  
**Version**: 1.8.1  
**Size**: ~1.1MB
