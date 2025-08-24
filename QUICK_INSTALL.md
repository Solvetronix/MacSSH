# MacSSH - Quick Installation

## 🚀 Quick Start

1. **Download** the `.dmg` file from [Releases](https://github.com/Solvetronix/MacSSH/releases)
2. **Install** the application to the `Applications` folder
3. **Launch** the application

## ⚠️ macOS blocked the application?

This is normal! MacSSH is not signed with Apple Developer ID.

### Solution:
1. **System Settings** → **Privacy & Security**
2. Find **"MacSSH" was blocked**
3. Click **"Open Anyway"**
4. Enter administrator password

## 📖 Detailed Instructions

See [docs/installation/INSTALLATION_GUIDE.md](docs/installation/INSTALLATION_GUIDE.md) for detailed instructions with screenshots.

## 🔧 Build from Source

```bash
git clone https://github.com/Solvetronix/MacSSH.git
cd MacSSH
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
```

## 🆘 Problems?

- Check [Issues](https://github.com/Solvetronix/MacSSH/issues)
- Create a new Issue with problem description
