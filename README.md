# MacSSH - SSH Terminal & File Manager

MacSSH is a native macOS application for managing SSH connections with a built-in file manager for working with remote files and folders.

## 🚀 **INSTALLATION GUIDE** 🚀

> **⚠️ IMPORTANT: Follow these steps carefully to install MacSSH**

### **Step 1: Download and Install**

1. **Download** the `.dmg` file from [GitHub Releases](https://github.com/Solvetronix/MacSSH/releases)
   - Go to the latest release
   - Download `MacSSH-vX.X.X.dmg` file
2. Double-click the `.dmg` file to mount it
3. Drag the `MacSSH` application to the `Applications` folder
4. Eject the disk and delete the `.dmg` file

### **Step 2: First Launch - Gatekeeper Warning**

When you first try to launch MacSSH, macOS will show this security warning:

![Gatekeeper Warning](docs/installation/01-gatekeeper-warning.png)

**Don't click "Move to Trash"** - this is normal for unsigned applications.

### **Step 3: Open System Settings**

1. Go to **System Settings** → **Privacy & Security**
2. Scroll down to find the security section
3. You'll see: **"MacSSH" was blocked to protect your Mac**

![Privacy & Security Settings](docs/installation/02-privacy-security-settings.png)

### **Step 4: Click "Open Anyway"**

1. Click the **"Open Anyway"** button next to the MacSSH warning
2. A confirmation dialog will appear

### **Step 5: Final Confirmation**

In the final dialog, click **"Open Anyway"** (not "Move to Trash"):

![Open Anyway Confirmation](docs/installation/03-open-anyway-confirmation.png)

3. Enter your administrator password when prompted
4. MacSSH will launch successfully

---

## **✅ That's It!**

Your MacSSH application is now installed and ready to use. You may need to repeat steps 2-5 when updating to new versions.

---

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
