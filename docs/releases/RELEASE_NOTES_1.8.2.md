# MacSSH 1.8.2 Release Notes

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

- **macOS**: 14.0 or later
- **Architecture**: Apple Silicon (ARM64) and Intel (x86_64)
- **Memory**: 8GB RAM recommended
- **Storage**: 50MB available space

### 🚀 Installation

1. Download `MacSSH-1.8.2.dmg`
2. Open the DMG file
3. Drag MacSSH to your Applications folder
4. Launch MacSSH from Applications

### 🔄 Update Process

If you have a previous version installed:
1. The app will automatically check for updates on launch
2. Click "Check for Updates" in the menu if needed
3. Download and install the new version
4. Your existing profiles and settings will be preserved

### 📝 Known Issues

- None reported in this release

### 🎯 What's Next

- Enhanced file transfer capabilities
- Improved terminal integration
- Additional security features
- Performance optimizations

### 📞 Support

For support or bug reports, please visit:
- GitHub Issues: [Repository Issues Page]
- Email: [Support Email]

---

**Release Date**: August 21, 2025  
**Version**: 1.8.2  
**Build**: Release  
**Size**: ~1.1MB (DMG)
