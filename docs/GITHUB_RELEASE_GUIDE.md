# 🚀 GitHub Release Guide with GitHub CLI

## Overview

This guide explains how to create GitHub releases using GitHub CLI that are compatible with the MacSSH automatic update system powered by Sparkle Framework.

## ⚠️ CRITICAL WARNINGS

### 1. Version Management
**ALWAYS update version in `project.pbxproj`, NOT in `Info.plist`!**

This is the most common mistake that causes version display issues. Xcode uses `project.pbxproj` settings to override `Info.plist`. If you only update `Info.plist`, the app will still show the old version.

**See also**: [Quick Version Fix](QUICK_VERSION_FIX.md) for troubleshooting version problems.

### 2. Git Push Requirement
**🚨 ALWAYS push all changes to the main branch BEFORE creating a release!**

This is critical because:
- The appcast.xml file must be available on GitHub for Sparkle to work
- Any code changes must be in the main branch for the release to be complete
- Users will download the version that matches the code in the main branch

**❌ Common Mistake**: Creating a release without pushing changes first
**✅ Correct Way**: Push all changes, then create the release

### 3. Local Installation for Testing
**🚨 DO NOT install the new version locally after creating a release!**

This is critical for testing the automatic update system:
- Keep the previous version (e.g., 1.8.4) installed in `/Applications`
- After creating release 1.8.5, test the automatic update from 1.8.4 → 1.8.5
- This verifies that Sparkle can find and install the new version automatically

**❌ Common Mistake**: Installing the new version locally immediately after release
**✅ Correct Way**: Test automatic update from the previous installed version

### 4. Appcast.xml Update (CRITICAL!)
**🚨 ALWAYS push appcast.xml to GitHub AFTER creating the release!**

This is the most critical step that is often forgotten:
- Without updating appcast.xml on GitHub, Sparkle won't know about the new release
- Users will never see the update notification
- The entire release process becomes useless

**❌ Common Mistake**: Creating the release but forgetting to push appcast.xml
**✅ Correct Way**: Always push appcast.xml after creating the release

## 🔧 Prerequisites

### 1. Install GitHub CLI
```bash
# Install via Homebrew
brew install gh

# Or download from https://cli.github.com/
```

### 2. Authenticate with GitHub
```bash
gh auth login
# Follow the interactive prompts to authenticate
```

### 3. Verify Authentication
```bash
gh auth status
```

## 📋 Release Process

### Step 1: Prepare Release Files

#### 1.1 Build the Application
```bash
# Clean previous builds
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean

# Build the application
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build

# Verify the build location
ls -la ~/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/
```

#### 1.2 Create DMG Package
```bash
# Create DMG using create-dmg (install via: brew install create-dmg)
create-dmg \
  --volname "MacSSH Installer" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacSSH.app" 200 190 \
  --hide-extension "MacSSH.app" \
  --app-drop-link 600 185 \
  "MacSSH-1.8.4.dmg" \
  "~/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/"

# Verify DMG was created
ls -la MacSSH-*.dmg
```

#### 1.3 Update Version Information

**⚠️ CRITICAL**: Update version in `project.pbxproj` (NOT in Info.plist)!

**Why this is important**: Xcode uses `project.pbxproj` settings to override `Info.plist`. If you only update `Info.plist`, the app will still show the old version from `project.pbxproj`.

```bash
# Update MARKETING_VERSION (user-facing version)
sed -i '' 's/MARKETING_VERSION = 1\.8\.3;/MARKETING_VERSION = 1.8.4;/g' MacSSH.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION (build number)
sed -i '' 's/CURRENT_PROJECT_VERSION = 183;/CURRENT_PROJECT_VERSION = 184;/g' MacSSH.xcodeproj/project.pbxproj

# Verify changes
grep -r "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" MacSSH.xcodeproj/
```

**❌ Common Mistake**: Only updating `Info.plist` - this will NOT work!
**✅ Correct Way**: Update `project.pbxproj` - this is what Xcode actually uses.

#### 1.4 Prepare Release Notes
```bash
# Create release notes file
cat > RELEASE_NOTES.md << 'EOF'
# MacSSH 1.8.4 Release Notes

## What's New
- Feature A
- Feature B
- Bug fix C

## Technical Improvements
- Performance improvements
- Code optimizations

## System Requirements
- macOS 14.0 or later
EOF
```

### Step 2: Push Changes to GitHub

#### 2.1 Commit and Push All Changes
```bash
# Add all changes to git
git add .

# Commit changes with descriptive message
git commit -m "Prepare release v1.8.4 - Update version and appcast.xml"

# Push to main branch
git push origin main

# Verify changes are on GitHub
gh repo view --web
```

**⚠️ CRITICAL**: This step is mandatory! The appcast.xml and all code changes must be available on GitHub before creating the release.

### Step 3: Create GitHub Release

#### 3.1 Create Release with GitHub CLI
```bash
# Create release with DMG asset
gh release create v1.8.4 \
  --title "MacSSH 1.8.4 - New Features" \
  --notes-file RELEASE_NOTES.md \
  --draft \
  MacSSH-1.8.4.dmg
```

#### 3.2 Publish the Release
```bash
# Publish the draft release
gh release edit v1.8.4 --draft=false
```

### Step 4: Update and Push appcast.xml (CRITICAL STEP!)

**🚨 CRITICAL: This step is MANDATORY and must NEVER be skipped!**

After creating the GitHub release, you MUST update and push the appcast.xml file:

```bash
# 1. Verify appcast.xml has the new version
grep -A 3 -B 3 "sparkle:version" appcast.xml

# 2. Push appcast.xml to GitHub
git add appcast.xml
git commit -m "Update appcast.xml with version 1.8.4 for new release"
git push origin main

# 3. Verify the update is live
curl -s "https://raw.githubusercontent.com/Solvetronix/MacSSH/main/appcast.xml" | grep -A 3 -B 3 "1.8.4"
```

**Why this is critical:**
- Without updating appcast.xml, Sparkle won't know about the new release
- Users will never see the update notification
- The entire release process becomes useless
- This is the most common mistake that breaks automatic updates

**❌ Common Mistake**: Creating the release but forgetting to push appcast.xml
**✅ Correct Way**: Always push appcast.xml after creating the release

### Step 4: Update Appcast for Sparkle

#### 4.1 Generate Ed25519 Signature
```bash
# Generate signature for the DMG file
# Note: You need the private key for signing
sparkle_sign_update MacSSH-1.8.4.dmg /path/to/private_key.pem
```

#### 4.2 Update appcast.xml
```xml
<!-- Add new release entry to docs/appcast.xml -->
<item>
    <title>MacSSH 1.8.4</title>
    <description><![CDATA[
        <h2>What's New in MacSSH 1.8.4</h2>
        <ul>
            <li>Feature A</li>
            <li>Feature B</li>
            <li>Bug fix C</li>
        </ul>
    ]]></description>
    <pubDate>Mon, 22 Aug 2025 12:00:00 +0000</pubDate>
    <enclosure url="https://github.com/Solvetronix/MacSSH/releases/download/v1.8.4/MacSSH-1.8.4.dmg"
               sparkle:version="1.8.4"
               sparkle:os="macos"
               length="1153000"
               type="application/octet-stream"
               sparkle:edSignature="GENERATED_SIGNATURE_HERE"/>
</item>
```

## 🔄 Automatic Update System Integration

### How Sparkle Works with GitHub Releases

1. **Feed URL**: `https://github.com/Solvetronix/MacSSH/releases.atom`
   - This is configured in `Info.plist` as `SUFeedURL`
   - Sparkle reads this RSS feed to check for updates

2. **Version Comparison**:
   - Sparkle compares `sparkle:version` in appcast with current app version
   - Current version is read from `CFBundleShortVersionString` in Info.plist

3. **Download Process**:
   - Sparkle downloads the DMG from the `url` in the enclosure
   - Verifies the `sparkle:edSignature` for security
   - Installs the update automatically

### Release Requirements for Sparkle

#### ✅ Required Elements
- **Tag format**: `v1.8.4` (must match version in appcast)
- **DMG asset**: Must be attached to the release
- **Appcast entry**: Must be added to `docs/appcast.xml`
- **Digital signature**: Must be generated and included
- **Version consistency**: All version numbers must match
- **Project version**: Must be updated in `project.pbxproj` (NOT Info.plist)

#### ❌ Common Mistakes
- Missing DMG asset in release
- Incorrect version numbers
- Missing appcast entry
- Invalid digital signature
- Wrong tag format
- **Updating version only in Info.plist** (must update project.pbxproj)
- **Forgetting to clean build** after version change

## 🚀 Complete Release Script

```bash
#!/bin/bash
# Complete release script for MacSSH

set -e  # Exit on any error

VERSION="1.8.4"
TAG="v$VERSION"
DMG_NAME="MacSSH-$VERSION.dmg"

echo "🚀 Starting MacSSH $VERSION release process..."

# Step 1: Update version in project.pbxproj (CRITICAL!)
echo "📝 Updating version to $VERSION in project.pbxproj..."
sed -i '' "s/MARKETING_VERSION = 1\.8\.3;/MARKETING_VERSION = $VERSION;/g" MacSSH.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = 183;/CURRENT_PROJECT_VERSION = 184;/g" MacSSH.xcodeproj/project.pbxproj
echo "✅ Version updated in project.pbxproj (NOT Info.plist!)"

# Step 2: Build application
echo "🔨 Building application..."
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build

# Step 3: Create DMG
echo "📦 Creating DMG package..."
create-dmg \
  --volname "MacSSH Installer" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "MacSSH.app" 200 190 \
  --hide-extension "MacSSH.app" \
  --app-drop-link 600 185 \
  "$DMG_NAME" \
  "~/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/"

# Step 4: Push changes to GitHub
echo "📤 Pushing changes to GitHub..."
git add .
git commit -m "Prepare release $VERSION - Update version and appcast.xml"
git push origin main

# Step 5: Create GitHub release
echo "🏷️ Creating GitHub release..."
gh release create "$TAG" \
  --title "MacSSH $VERSION - New Features" \
  --notes-file "docs/releases/RELEASE_NOTES_$VERSION.md" \
  --draft \
  "$DMG_NAME"

# Step 6: Publish release
echo "📤 Publishing release..."
gh release edit "$TAG" --draft=false

echo "✅ Release $VERSION completed successfully!"
echo "🔗 Release URL: https://github.com/Solvetronix/MacSSH/releases/tag/$TAG"
echo "📝 Don't forget to update docs/appcast.xml with the new release entry!"
```

## 📋 Release Checklist

### Pre-Release
- [ ] Version updated in `project.pbxproj` (NOT Info.plist!)
- [ ] Clean build performed after version change
- [ ] Application builds successfully
- [ ] Version verified in built app
- [ ] DMG package created and tested
- [ ] Release notes prepared
- [ ] GitHub CLI authenticated
- [ ] **All changes committed and pushed to main branch** ⚠️ CRITICAL

### Release Creation
- [ ] GitHub release created with correct tag
- [ ] DMG asset uploaded to release
- [ ] Release notes included
- [ ] Release published (not draft)

### Post-Release
- [ ] Appcast entry added to `docs/appcast.xml`
- [ ] Digital signature generated and added
- [ ] **DO NOT install new version locally** ⚠️ CRITICAL
- [ ] Test automatic update from previous installed version
- [ ] Verify Sparkle finds and installs the new version
- [ ] Documentation updated

## 🔍 Troubleshooting

### Common Issues

#### 1. Version Mismatch
```bash
# Check current version in built app
defaults read ~/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/MacSSH.app/Contents/Info.plist CFBundleShortVersionString

# If version is wrong, check project.pbxproj
grep -r "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" MacSSH.xcodeproj/

# Remember: Update project.pbxproj, NOT Info.plist!
```

#### 2. DMG Not Found
```bash
# Verify DMG exists and is accessible
ls -la MacSSH-*.dmg
file MacSSH-*.dmg
```

#### 3. GitHub CLI Authentication
```bash
# Re-authenticate if needed
gh auth logout
gh auth login
```

#### 4. Release Already Exists
```bash
# Delete existing release if needed
gh release delete v1.8.4 --yes
```

## 📚 Related Documentation

- [Version Management Guide](VERSION_MANAGEMENT_GUIDE.md) - Managing app versions
- [Quick Version Fix](QUICK_VERSION_FIX.md) - Quick fix for version problems
- [Sparkle Setup Guide](SPARKLE_SETUP.md) - Sparkle configuration
- [Automatic Update Guide](AUTOMATIC_UPDATE_GUIDE.md) - Update system overview

## 🎯 Best Practices

1. **Always test releases** before publishing
2. **Use semantic versioning** (1.8.4, not 1.8.4.1)
3. **Include detailed release notes**
4. **Test automatic updates** after release
5. **Keep appcast.xml updated**
6. **Use consistent naming** for all files
7. **Verify digital signatures** are correct
8. **DO NOT install new version locally** - test automatic update instead
9. **Keep previous version installed** for testing update process

---

**Note**: This guide ensures releases are compatible with the Sparkle automatic update system. Always test the update process after creating a release.
