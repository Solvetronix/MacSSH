# MacSSH 1.8.0 Release Notes

## 🎉 New Features

### Multiple File Browser Windows
- **Fixed**: Each profile now opens in its own separate file browser window
- **Improved**: No more conflicts between different profile file browsers
- **Enhanced**: Each window maintains its own state and shows correct files for its profile

## 🐛 Bug Fixes

### File Browser Window Management
- **Fixed**: Issue where opening file browser from second profile would show first profile's files
- **Fixed**: Window titles now correctly display the associated profile name
- **Fixed**: Each file browser window now operates independently

### State Management
- **Improved**: Better separation of file browser state between different windows
- **Enhanced**: Profile-specific file browser state management
- **Fixed**: Thread safety improvements in asynchronous operations

## 🔧 Technical Improvements

### Architecture Updates
- **Added**: `WindowManager` service for managing file browser windows
- **Enhanced**: `ProfileViewModel` with better state isolation
- **Improved**: SwiftUI view lifecycle management

### Code Quality
- **Updated**: SwiftUI `onChange` modifiers to use modern syntax
- **Enhanced**: Error handling and logging
- **Improved**: Memory management for multiple windows

## 📋 System Requirements

- **macOS**: 14.0 or later
- **Architecture**: Apple Silicon (ARM64) and Intel (x86_64)
- **Memory**: 8GB RAM recommended
- **Storage**: 50MB available space

## 🚀 Installation

1. Download `MacSSH-1.8.0.dmg`
2. Open the DMG file
3. Drag MacSSH to your Applications folder
4. Launch MacSSH from Applications

## 🔄 Update Process

If you have a previous version installed:
1. The app will automatically check for updates
2. Click "Check for Updates" in the menu if needed
3. Download and install the new version
4. Your existing profiles and settings will be preserved

## 📝 Known Issues

- None reported in this release

## 🎯 What's Next

- Enhanced file transfer capabilities
- Improved terminal integration
- Additional security features
- Performance optimizations

## 📞 Support

For support or bug reports, please visit:
- GitHub Issues: [Repository Issues Page]
- Email: [Support Email]

---

**Release Date**: August 21, 2025  
**Version**: 1.8.0  
**Build**: Release  
**Size**: ~1.1MB (DMG)
