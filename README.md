# MacSSH - SSH Terminal & File Manager

MacSSH is a native macOS application for managing SSH connections with a built-in file manager for working with remote files and folders.

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

### Required Tools

For full application functionality, you need to install additional tools:

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install sshpass sshfs
```

#### Tools and their purpose:

- **sshpass** - for automatic password transmission during SSH connections
- **sshfs** - for mounting remote directories in Finder

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
     - 📁 **Open directory** - navigate to folder
     - 💾 **Mount in Finder** - mount folder in Finder
     - 📝 **Open in VS Code/Cursor** - open file in VS Code/Cursor with synchronization
     - 📄 **Open in Finder** - download and open file in Finder

### Mounting in Finder

To mount a remote directory in Finder:

1. Make sure `sshfs` is installed
2. In the file browser, select a folder
3. Click "Mount in Finder" button
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
