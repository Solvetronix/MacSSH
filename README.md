# MacSSH Terminal

A modern macOS application for managing SSH connections with a beautiful SwiftUI interface.

## 🚀 Features

- **SSH Connection Management**: Save and manage multiple SSH server connections
- **One-Click Terminal Access**: Open terminal connections to remote servers instantly
- **Password & Key Authentication**: Support for both password and private key authentication
- **Connection Testing**: Test server connectivity before connecting
- **Modern UI**: Clean, native macOS interface built with SwiftUI
- **Detailed Logs**: View detailed connection logs and debugging information

## 📱 Screenshots

*Screenshots will be added here*

## 🛠 Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for development)
- Swift 5.9 or later

## 🚀 Installation

### From Source

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

### From DMG

1. Download the latest DMG file from releases
2. Open the DMG file
3. Drag MacSSH Terminal to Applications folder
4. Launch from Applications

## 📖 Usage

1. **Add a Connection**:
   - Click the "+" button to add a new SSH connection
   - Fill in the server details (host, port, username)
   - Choose authentication method (password or private key)
   - Save the connection

2. **Test Connection**:
   - Select a connection from the list
   - Click "Test Connection" to verify connectivity
   - View detailed logs in the center panel

3. **Open Terminal**:
   - Select a connection
   - Click "Open Terminal" to launch Terminal.app with SSH connection
   - The terminal will automatically connect to the remote server

## 🔧 Configuration

### SSH Key Authentication

1. Generate an SSH key pair (if you haven't already):
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

2. Add the public key to your remote server:
```bash
ssh-copy-id username@your-server.com
```

3. In MacSSH Terminal, select "Private Key" authentication and browse to your private key file

### Password Authentication

For password authentication, simply enter your password in the connection form. The app will use `sshpass` for automated login.

## 🏗 Architecture

- **MVVM Pattern**: Model-View-ViewModel architecture
- **SwiftUI**: Modern declarative UI framework
- **UserDefaults**: Local storage for connection profiles
- **Process**: System integration for SSH commands

## 📁 Project Structure

```
MacSSH/
├── MacSSH/                    # Main application source
│   ├── Models/               # Data models
│   ├── Views/                # SwiftUI views
│   ├── ViewModels/           # View models
│   ├── Services/             # Business logic services
│   └── Assets.xcassets/      # App icons and assets
├── MacSSHTests/              # Unit tests
├── MacSSHUITests/            # UI tests
└── MacSSH.xcodeproj/         # Xcode project file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI and Xcode
- Icons designed for SSH terminal functionality
- Inspired by the need for a modern SSH connection manager on macOS

## 📞 Support

If you encounter any issues or have questions, please open an issue on GitHub.

---

**MacSSH Terminal** - Making SSH connections beautiful and simple on macOS 🖥️ 
