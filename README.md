# MacSSH - SSH Terminal & File Manager

MacSSH is a native macOS application for managing SSH connections with a built-in file manager for working with remote files and folders.

## 🚀 Quick Installation

### Download & Install

1. **Download** the `.dmg` file from [GitHub Releases](https://github.com/Solvetronix/MacSSH/releases)
   - Go to the latest release
   - Download `MacSSH-vX.X.X.dmg` file
2. **Install** the application to the `Applications` folder
3. **Launch** the application

### ⚠️ macOS blocked the application?

This is normal! Follow these steps:

1. **System Settings** → **Privacy & Security**
2. Find **"MacSSH" was blocked**
3. Click **"Open Anyway"**
4. Enter administrator password

📖 **Detailed Instructions**: See [Installation Guide](docs/installation/INSTALLATION_GUIDE.md) for step-by-step guide with screenshots.

## Features

### SSH Connections
- ✅ SSH connection profile management
- ✅ Password and private key authentication support
- ✅ Automatic Terminal.app opening with SSH connection
- ✅ Connection testing
- ✅ Recent connections history

### File Manager
- ✅ Browse files and folders on remote hosts
- ✅ Navigate through the file system
- ✅ Open files in VS Code/Cursor with automatic change synchronization
- ✅ Open files in Finder (automatic download)
- ✅ Mount remote directories in Finder via SSHFS
- ✅ Display file information (size, permissions, modification date)

### Updates
- ✅ Automatic update checking via GitHub
- ✅ One-click download and installation
- ✅ Version comparison and release notes
- ✅ Manual update option

## ⚠️ Important: macOS Permissions

The MacSSH application requires special permissions to execute external commands (ssh, sftp, scp). The application automatically checks and requests necessary permissions.

**Required permissions:**
1. **Full Disk Access** - required for executing SSH commands
2. **Accessibility** - for automation (optional)

**Automatic setup:**
- The application automatically checks permissions on startup
- You can see the status of all permissions in SSH Tools Manager
- The "Request Full Disk Access" button automatically opens System Settings
- Detailed instructions are available in SSH Tools Manager

**Manual setup:**
If automatic setup doesn't work, follow the instructions in the [PERMISSIONS_FIX.md](PERMISSIONS_FIX.md) file.

## 👥 Contributing & Development

### **Looking for Developers!**

MacSSH is actively seeking **other programmers and developers** to help create and improve this application. We welcome contributions from the community!

### **How to Contribute**

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch** for your changes
4. **Make your improvements** and test thoroughly
5. **Submit a pull request** with detailed description

### **Areas Needing Help**

- **UI/UX Improvements** - Better user interface design
- **Feature Development** - New SSH and file management features
- **Bug Fixes** - Help identify and fix issues
- **Documentation** - Improve user guides and developer docs
- **Testing** - Comprehensive testing across different macOS versions
- **Performance Optimization** - Improve app speed and efficiency

### **Development Setup**

```bash
# Clone the repository
git clone https://github.com/Solvetronix/MacSSH.git
cd MacSSH

# Open in Xcode
open MacSSH.xcodeproj

# Build and run
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Debug build
```

### **Contact & Collaboration**

- **GitHub Issues**: Report bugs and request features
- **Pull Requests**: Submit code improvements
- **Discussions**: Join project discussions on GitHub

**🎯 Goal**: Create the best SSH management tool for macOS with community input!
