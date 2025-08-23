#!/bin/bash
# Script to update version locally after automatic release
# Usage: ./update_version_locally.sh <new_version> <new_build> <dmg_name>

NEW_VERSION=$1
NEW_BUILD=$2
DMG_NAME=$3

if [ -z "$NEW_VERSION" ] || [ -z "$NEW_BUILD" ] || [ -z "$DMG_NAME" ]; then
    echo "Usage: $0 <new_version> <new_build> <dmg_name>"
    echo "Example: $0 1.8.13 193 MacSSH-1.8.13.dmg"
    exit 1
fi

echo "🔄 Updating version to $NEW_VERSION (build $NEW_BUILD)..."

# Get current versions
CURRENT_VERSION=$(grep 'MARKETING_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/')
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1 | sed 's/.*CURRENT_PROJECT_VERSION = \([^;]*\);.*/\1/')

echo "📊 Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"
echo "📊 New version: $NEW_VERSION (build $NEW_BUILD)"

# Update project.pbxproj
echo "🔧 Updating project.pbxproj..."
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION/MARKETING_VERSION = $NEW_VERSION/g" MacSSH.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" MacSSH.xcodeproj/project.pbxproj

# Update Info.plist
echo "🔧 Updating Info.plist..."
CURRENT_INFO_VERSION=$(grep -A 1 'CFBundleShortVersionString' MacSSH/Info.plist | tail -1 | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/')
sed -i '' "s/<string>$CURRENT_INFO_VERSION<\/string>/<string>$NEW_VERSION<\/string>/g" MacSSH/Info.plist

# Update appcast.xml
echo "🔧 Updating appcast.xml..."
chmod +x update_appcast.sh
./update_appcast.sh "$NEW_VERSION" "$NEW_BUILD" "$DMG_NAME"

# Verify changes
echo "✅ Version update completed!"
echo ""
echo "📋 Verification:"
echo "project.pbxproj MARKETING_VERSION: $(grep 'MARKETING_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1)"
echo "project.pbxproj CURRENT_PROJECT_VERSION: $(grep 'CURRENT_PROJECT_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1)"
echo "Info.plist version: $(grep -A 1 'CFBundleShortVersionString' MacSSH/Info.plist | tail -1)"
echo ""
echo "🚀 Ready to commit and push:"
echo "git add MacSSH.xcodeproj/project.pbxproj MacSSH/Info.plist appcast.xml"
echo "git commit -m \"Update version to $NEW_VERSION after automatic release\""
echo "git push origin main"
