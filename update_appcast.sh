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

# Create new item content from template
sed "s/VERSION_PLACEHOLDER/$VERSION/g; s/BUILD_PLACEHOLDER/$BUILD/g; s/DATE_PLACEHOLDER/$CURRENT_DATE/g; s/TAG_PLACEHOLDER/$TAG/g; s/DMG_PLACEHOLDER/$DMG_NAME/g; s/SIZE_PLACEHOLDER/$DMG_SIZE/g" appcast_template.xml > temp_item.xml

            # Insert new item after <language>en</language>
            sed -i '' "/<language>en<\/language>/r temp_item.xml" appcast.xml
            sed -i '' "/<language>en<\/language>/a\\
            " appcast.xml
            
            # Clean up
            rm temp_item.xml

            # Remove all placeholder signatures from existing items
            sed -i '' 's/sparkle:edSignature="YOUR_ED_SIGNATURE_HERE"//g' appcast.xml

            echo "✅ Updated appcast.xml with version $VERSION and removed placeholder signatures"
