#!/bin/bash

# Script to prepare GitHub release
echo "🚀 Preparing GitHub release for MacSSH v1.0.0"

# Check if .dmg file exists
if [ ! -f "MacSSH-1.0.0.dmg" ]; then
    echo "❌ Error: MacSSH-1.0.0.dmg not found!"
    echo "Please build the app first with: xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build"
    exit 1
fi

# Check file size
FILE_SIZE=$(ls -lh MacSSH-1.0.0.dmg | awk '{print $5}')
echo "✅ Found MacSSH-1.0.0.dmg ($FILE_SIZE)"

# Create release data
echo "📝 Creating release data..."

cat > release_data.json << EOF
{
  "tag_name": "v1.0.0",
  "name": "MacSSH 1.0.0",
  "body": "## What's New\n\n• Initial release with SSH connection management\n• File browser with VS Code integration\n• Automatic file synchronization\n• macOS permissions management\n• Automatic update system\n\n## Features\n\n- SSH connection profile management\n- Password and private key authentication\n- File browser with remote file editing\n- VS Code/Cursor integration with auto-sync\n- Mount remote directories in Finder\n- Automatic update checking via GitHub\n\n## Requirements\n\n- macOS 13.0 or newer\n- VS Code or Cursor (for file editing)\n- sshpass and sshfs (optional)",
  "draft": false,
  "prerelease": false
}
EOF

echo "✅ Created release_data.json"

# Instructions for manual release creation
echo ""
echo "📋 To create the release manually:"
echo ""
echo "1. Go to: https://github.com/Solvetronix/MacSSH/releases"
echo "2. Click 'Create a new release'"
echo "3. Select tag: v1.0.0"
echo "4. Copy the content from release_data.json"
echo "5. Upload file: MacSSH-1.0.0.dmg"
echo "6. Click 'Publish release'"
echo ""
echo "📁 Files ready for release:"
echo "   - MacSSH-1.0.0.dmg ($FILE_SIZE)"
echo "   - release_data.json (release description)"
echo ""
echo "🎯 After creating the release, you can test the update system!"
echo "   - Install MacSSH-1.0.0.dmg"
echo "   - Open the app and click 'Check for Updates'"
echo "   - It should find version 1.1.0 as an update"
