# MacSSH Release Guide

## Overview

This guide describes the complete process for creating and publishing new releases of MacSSH on GitHub. The process includes version management, building, packaging, and publishing.

## Prerequisites

- macOS development environment
- Xcode installed
- Git repository access
- GitHub CLI (`gh`) installed and authenticated
- `create-dmg` tool installed (`brew install create-dmg`)

## Release Process

### 1. Update Version in Project

**File to modify**: `MacSSH/Info.plist`

Update both version strings:
```xml
<key>CFBundleVersion</key>
<string>X.Y.Z</string>
<key>CFBundleShortVersionString</key>
<string>X.Y.Z</string>
```

**Example for version 1.8.0**:
```xml
<key>CFBundleVersion</key>
<string>1.8.0</string>
<key>CFBundleShortVersionString</key>
<string>1.8.0</string>
```

### 2. Create Release Description

**File**: `release_description_v<version>.md`

Create a markdown file with release notes:
```markdown
# MacSSH v<version>

## What's New

- **Feature 1**: Description of new feature
- **Bug Fix**: Description of bug fix
- **Improvement**: Description of improvement

## Features

- SSH connection management
- Password-based authentication
- File browser with remote server access
- VS Code/Cursor integration for file editing
- Mount remote directories
- Automatic update checking via GitHub

## Requirements

- macOS 13.0 or newer
- VS Code or Cursor (for file editing)
- sshpass and sshfs (optional)

## Installation

Download the .dmg file and drag MacSSH to your Applications folder.

## Updates

Description of update system improvements or changes.
```

### 3. Commit and Tag Changes

```bash
# Add all changes
git add .

# Commit with descriptive message
git commit -m "Update to version X.Y.Z for release"

# Create version tag
git tag vX.Y.Z

# Push changes and tags to GitHub
git push origin main --tags
```

### 4. Build Application

```bash
# Clean previous builds (optional but recommended)
xcodebuild clean -project MacSSH.xcodeproj -scheme MacSSH

# Build in Release configuration
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
```

### 5. Create DMG Package

```bash
# Create DMG file
create-dmg \
  --volname "MacSSH" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacSSH.app" 200 190 \
  --hide-extension "MacSSH.app" \
  --app-drop-link 600 185 \
  "MacSSH-X.Y.Z.dmg" \
  "/Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/"
```

**Note**: Replace `X.Y.Z` with actual version number and adjust the DerivedData path if needed.

### 6. Create GitHub Release

```bash
# Create release on GitHub
gh release create vX.Y.Z \
  "MacSSH-X.Y.Z.dmg" \
  --title "MacSSH vX.Y.Z" \
  --notes-file "release_description_vX.Y.Z.md"
```

### 7. Clean Up

```bash
# Remove temporary files
rm -f release_description_vX.Y.Z.md
```

## Complete Example

Here's a complete example for creating version 1.8.0:

### Step 1: Update Info.plist
```xml
<key>CFBundleVersion</key>
<string>1.8.0</string>
<key>CFBundleShortVersionString</key>
<string>1.8.0</string>
```

### Step 2: Create release_description_v1.8.md
```markdown
# MacSSH v1.8.0

## What's New

- **New Feature**: Description
- **Bug Fix**: Fixed issue with...

## Features

- SSH connection management
- Password-based authentication
- File browser with remote server access
- VS Code/Cursor integration for file editing
- Mount remote directories
- Automatic update checking via GitHub

## Requirements

- macOS 13.0 or newer
- VS Code or Cursor (for file editing)
- sshpass and sshfs (optional)

## Installation

Download the .dmg file and drag MacSSH to your Applications folder.
```

### Step 3: Git operations
```bash
git add .
git commit -m "Update to version 1.8.0 for release"
git tag v1.8.0
git push origin main --tags
```

### Step 4: Build
```bash
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
```

### Step 5: Create DMG
```bash
create-dmg \
  --volname "MacSSH" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacSSH.app" 200 190 \
  --hide-extension "MacSSH.app" \
  --app-drop-link 600 185 \
  "MacSSH-1.8.0.dmg" \
  "/Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/"
```

### Step 6: GitHub Release
```bash
gh release create v1.8.0 \
  "MacSSH-1.8.0.dmg" \
  --title "MacSSH v1.8.0" \
  --notes-file "release_description_v1.8.md"
```

### Step 7: Clean up
```bash
rm -f release_description_v1.8.md
```

## Version Numbering

Use semantic versioning (SemVer):
- **MAJOR.MINOR.PATCH**
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality in backward-compatible manner
- **PATCH**: Backward-compatible bug fixes

Examples:
- 1.0.0 - Initial release
- 1.1.0 - New features added
- 1.1.1 - Bug fixes only
- 2.0.0 - Breaking changes

## Troubleshooting

### Version Not Updating
If the built application shows an old version:
1. Clean DerivedData: `rm -rf "/Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*"`
2. Clean build: `xcodebuild clean -project MacSSH.xcodeproj -scheme MacSSH`
3. Rebuild: `xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build`

### GitHub CLI Issues
If `gh` commands fail:
1. Check authentication: `gh auth status`
2. Re-authenticate if needed: `gh auth login`

### DMG Creation Issues
If `create-dmg` fails:
1. Ensure the app path is correct
2. Check that the app was built successfully
3. Verify `create-dmg` is installed: `brew install create-dmg`

## Automation

For frequent releases, consider creating a shell script that automates this process:

```bash
#!/bin/bash
VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

# Update Info.plist
sed -i '' "s/<string>.*<\/string>/<string>$VERSION<\/string>/g" MacSSH/Info.plist

# Create release description
cat > "release_description_v$VERSION.md" << EOF
# MacSSH v$VERSION

## What's New

- Release $VERSION

## Features

- SSH connection management
- Password-based authentication
- File browser with remote server access
- VS Code/Cursor integration for file editing
- Mount remote directories
- Automatic update checking via GitHub

## Requirements

- macOS 13.0 or newer
- VS Code or Cursor (for file editing)
- sshpass and sshfs (optional)

## Installation

Download the .dmg file and drag MacSSH to your Applications folder.
EOF

# Git operations
git add .
git commit -m "Update to version $VERSION for release"
git tag "v$VERSION"
git push origin main --tags

# Build
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build

# Create DMG
create-dmg \
  --volname "MacSSH" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacSSH.app" 200 190 \
  --hide-extension "MacSSH.app" \
  --app-drop-link 600 185 \
  "MacSSH-$VERSION.dmg" \
  "/Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/"

# GitHub Release
gh release create "v$VERSION" \
  "MacSSH-$VERSION.dmg" \
  --title "MacSSH v$VERSION" \
  --notes-file "release_description_v$VERSION.md"

# Clean up
rm -f "release_description_v$VERSION.md"

echo "Release v$VERSION created successfully!"
```

Usage: `./create_release.sh 1.9.0`

## Notes

- Always test the update system after creating a new release
- Keep release notes clear and informative
- Use consistent version numbering
- Verify that the DMG file installs correctly
- Test the update process from the previous version
