# MacSSH - SSH Terminal & File Manager

MacSSH is a native macOS application for managing SSH connections with a built-in file manager for working with remote files and folders.

## 🔍 What MacSSH Searches For

MacSSH automatically detects and checks for the following software on your system:

### **Text Editors** (Required for file editing)
- **VS Code** or **Cursor** - for editing remote files with automatic synchronization
- Searches in: `/usr/local/bin/code`, `/opt/homebrew/bin/code`, `/Applications/Visual Studio Code.app/`, `/Applications/Cursor.app/`

### **SSH Tools** (Built into macOS)
- **ssh**, **ssh-keyscan**, **sftp**, **scp** - for SSH connections and file operations
- Located in: `/usr/bin/`

### **Additional Tools** (Optional but recommended)
- **sshpass** - for password-based authentication
- **sshfs** - for mounting remote directories in Finder
- Searches in: `/opt/homebrew/bin/`, `/usr/local/bin/`, `/usr/bin/`

### **System Permissions**
- **Full Disk Access** - required for executing external commands
- **Accessibility** - for automation features

**💡 Tip**: You can check the status of all tools and permissions in **Tools > SSH Tools Manager**

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

## Installation

### Requirements
- macOS 13.0 or newer
- Xcode 15.0 or newer (for building from source)
- VS Code or Cursor (for editing files with automatic synchronization)

### ⚠️ Important: macOS Permissions

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

### 🔍 Required Tools & Software

MacSSH automatically searches for the following tools and software on your system:

#### **Text Editors (Required for file editing)**
The application searches for VS Code or Cursor in these locations:
- `/usr/local/bin/code`
- `/opt/homebrew/bin/code`
- `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`
- `/Applications/Cursor.app/Contents/Resources/app/bin/code`
- Also checks if `code` command is available in PATH

**Installation:**
- **VS Code**: Download from https://code.visualstudio.com/
- **Cursor**: Download from https://cursor.sh/

#### **SSH Tools (Required for SSH operations)**
The application checks for these built-in macOS tools:
- **ssh** - `/usr/bin/ssh`
- **ssh-keyscan** - `/usr/bin/ssh-keyscan`
- **sftp** - `/usr/bin/sftp`
- **scp** - `/usr/bin/scp`

These are included with macOS by default.

#### **Additional Tools (Optional but recommended)**
The application searches for these tools in multiple locations:

**sshpass** (for password-based authentication):
- `/opt/homebrew/bin/sshpass`
- `/usr/local/bin/sshpass`
- `/usr/bin/sshpass`

**sshfs** (for mounting remote directories):
- `/usr/bin/sshfs`
- `/usr/local/bin/sshfs`
- `/opt/homebrew/bin/sshfs`

**Installation:**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install sshpass
brew install --cask macfuse
brew install sshfs
```

#### **Tool Status Checking**
You can check the status of all tools in the application:
1. Open **Tools > SSH Tools Manager**
2. Click **Check Tools** button
3. Review the status of all required tools and permissions

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/MacSSH.git
cd MacSSH
```

2. Open the project in Xcode:
```bash
open MacSSH.xcodeproj
```

3. Build and run the project (⌘+R)

## Usage

### Checking Permissions

The application automatically checks permissions on startup. For manual checking:

1. Open **Tools > SSH Tools Manager** menu
2. Review the status of all permissions and tools
3. Use the buttons:
   - **Check Tools** - recheck status
   - **Request Full Disk Access** - request permission
   - **Show Instructions** - show detailed instructions
4. Follow the recommendations to configure missing permissions

### Creating an SSH Profile

1. Click the "+" button to create a new profile
2. Fill in the connection information:
   - **Name** - profile name
   - **Host** - IP address or domain name of the server
   - **Port** - SSH port (default 22)
   - **Username** - username
   - **Authentication** - choose authentication type:
     - Password - password
     - Private Key - private key

### Connecting to Server

1. Select a profile from the list
2. Click "Test Connection & Open Terminal" button to:
   - Test the connection
   - Automatically open Terminal.app with SSH session

### Working with Files

1. Select a profile from the list
2. Click "Open File Browser" button (folder icon)
3. In the opened file browser window:
   - Browse files and folders
   - Double-click on a folder to navigate into it
   - Use action buttons:
     - 📁 **Open directory** - navigate to folder (for directories)
     - 📝 **Open in VS Code/Cursor** - open file in VS Code/Cursor with synchronization (for files)
     - 📄 **Open in Finder** - download and open file in Finder (for files)

### Mounting in Finder

To mount a remote directory in Finder:

1. Make sure `sshfs` is installed
2. Use the file browser to navigate to the desired directory
3. The mounting functionality is available through the SSH Tools Manager
4. The folder will appear in Finder as an external drive

### Opening Files

To open files:

1. In the file browser, select a file
2. Use action buttons:
   - 📝 **Open in VS Code/Cursor** - open file in VS Code/Cursor with automatic change synchronization
   - 📄 **Open in Finder** - download and open file in Finder

#### Editing in VS Code/Cursor

When opening a file in VS Code/Cursor:
- The file is automatically downloaded to a temporary folder
- VS Code/Cursor opens with the downloaded file
- All changes are automatically synchronized with the remote server when saved
- Change tracking works in the background

### Checking for Updates

MacSSH includes an automatic update system:

1. Click the "More Options" menu (⋯) in the toolbar
2. Select "Check for Updates"
3. If an update is available:
   - Review version changes and release notes
   - Click "Download & Install" to update
   - Or click "View on GitHub" for manual download

For detailed information about the update system, see [UPDATE_SYSTEM.md](UPDATE_SYSTEM.md).

## Project Structure

```
MacSSH/
├── MacSSH/
│   ├── Views/
│   │   ├── ContentView.swift          # Main interface
│   │   ├── ProfileFormView.swift      # Profile form
│   │   ├── FileBrowserView.swift      # File browser
│   │   └── ToolsInfoView.swift        # Tools information
│   ├── ViewModels/
│   │   └── ProfileViewModel.swift     # Application logic
│   ├── Models/
│   │   └── Profile.swift              # Profile model
│   ├── Services/
│   │   └── RepositoryService.swift    # SSH and SFTP services
│   └── Assets.xcassets/               # Resources
├── MacSSHTests/                       # Unit tests
└── MacSSHUITests/                     # UI tests
```

## Technical Details

### SSH Connections
- Uses built-in macOS SSH clients
- Support for `sshpass` for automatic password transmission
- Automatic acceptance of SSH host keys

### File Manager
- **SFTP** for browsing the file system
- **SCP** for downloading files
- **SSHFS** for mounting directories
- Parsing `ls -la` output to get file information

### Security
- Passwords stored in Keychain (planned)
- Temporary files automatically deleted
- SSH private key support

## Development Plans

- [ ] Integration with macOS Keychain for secure password storage
- [ ] Support for uploading files to server
- [ ] Remote file editing
- [ ] Multiple SSH session support
- [ ] Integration with popular code editors
- [ ] SFTP bookmarks support
- [ ] Profile export/import

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

If you have questions or suggestions, create an Issue in the repository. 
