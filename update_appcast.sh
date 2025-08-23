#!/bin/bash

# Script to update appcast.xml with new version
# Usage: ./update_appcast.sh <version> <build> <dmg_name>

VERSION=$1
BUILD=$2
DMG_NAME=$3

if [ -z "$VERSION" ] || [ -z "$BUILD" ] || [ -z "$DMG_NAME" ]; then
    echo "Usage: $0 <version> <build> <dmg_name>"
    echo "Example: $0 1.8.9 189 MacSSH-1.8.9.dmg"
    exit 1
fi

# Get DMG size
DMG_SIZE=$(stat -f%z "$DMG_NAME")
CURRENT_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
TAG="v$VERSION"

# Create new item content
NEW_ITEM="        <item>
            <title>MacSSH $VERSION - Automatic Release</title>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New in MacSSH $VERSION</h2>
                <ul>
                    <li>🚀 Automatic release with GitHub Actions</li>
                    <li>🔧 Improved build process</li>
                    <li>📦 DMG package creation</li>
                    <li>⚡ Faster deployment pipeline</li>
                </ul>
            ]]></description>
            <pubDate>$CURRENT_DATE</pubDate>
            <enclosure url=\"https://github.com/Solvetronix/MacSSH/releases/download/$TAG/$DMG_NAME\"
                       sparkle:os=\"macos\"
                       length=\"$DMG_SIZE\"
                       type=\"application/octet-stream\"/>
        </item>"

            # Insert new item after <language>en</language>
            sed -i '' "/<language>en<\/language>/a\\
            $NEW_ITEM" appcast.xml

            # Remove all placeholder signatures from existing items
            sed -i '' 's/sparkle:edSignature="YOUR_ED_SIGNATURE_HERE"//g' appcast.xml

            echo "✅ Updated appcast.xml with version $VERSION and removed placeholder signatures"
