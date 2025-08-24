# MacSSH - Professional SSH Terminal & File Manager for macOS

> **🚀 The easiest way to manage SSH connections and remote files on your Mac**

MacSSH combines the power of a professional SSH terminal with an intuitive file manager, making remote server management simple and efficient.

## ✨ **Why Choose MacSSH?**

- **🔐 One-Click SSH Connections** - Connect to servers instantly with saved profiles
- **📁 Visual File Browser** - Browse remote files like in Finder
- **💻 Built-in Terminal** - Professional SwiftTerm terminal with copy/paste support
- **📝 Smart File Editing** - Open files in VS Code/Cursor with auto-sync
- **🔄 Auto Updates** - Always get the latest version automatically
- **🎯 Zero Configuration** - Works out of the box with macOS

## 🚀 **INSTALLATION GUIDE** 🚀

> **⚠️ IMPORTANT: Follow these steps carefully to install MacSSH**

📖 **[📋 Complete Installation Guide with Screenshots](docs/installation/INSTALLATION_GUIDE.md)**

### **Quick Steps:**
1. **Download** from [GitHub Releases](https://github.com/Solvetronix/MacSSH/releases)
2. **Install** to Applications folder
3. **Launch** and follow Gatekeeper bypass steps

---

## 🔧 **Required Dependencies**

### **sshpass - Password Authentication Tool**

MacSSH requires `sshpass` for automatic password transmission to SSH terminals. This is the main dependency you need to install.

**Install via Homebrew:**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install sshpass
brew install sshpass
```

**Why sshpass?**
- Enables automatic password entry for SSH connections
- Allows MacSSH to handle password authentication seamlessly
- Required for the terminal integration feature

**Alternative installation methods:**
- Download from [sshpass website](https://sourceforge.net/projects/sshpass/)
- Install via MacPorts: `sudo port install sshpass`

---

## 🎯 **Key Features**

### **SSH Made Simple**
- ✅ **Profile Management** - Save and organize your server connections
- ✅ **Password & Key Auth** - Support for both authentication methods
- ✅ **Connection Testing** - Verify your setup before connecting
- ✅ **Recent History** - Quick access to your last connections

### **File Management**
- ✅ **Visual Browser** - Navigate remote files like local folders
- ✅ **Smart Editing** - Open files in VS Code/Cursor with live sync
- ✅ **Finder Integration** - Download and open files in Finder
- ✅ **SSHFS Mounting** - Mount remote directories as local drives

### **Developer Friendly**
- ✅ **Auto-Sync Editing** - Changes sync automatically when you save
- ✅ **Terminal Integration** - Built-in professional terminal
- ✅ **Update System** - Stay current with automatic updates
- ✅ **macOS Native** - Designed specifically for macOS

## 🤖 **Coming Soon: AI-Powered Terminal**

> **🚀 Future Enhancement: AI Terminal Assistant**

- **🧠 AI Command Execution** - Write prompts and let AI execute terminal commands
- **🔑 Token-Based AI Integration** - Connect your AI service via API tokens
- **⚡ Smart Task Automation** - AI will handle complex terminal tasks automatically
- **🎯 Professional Terminal** - Built on native SwiftTerm with AI capabilities

---

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
