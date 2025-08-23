# Version Synchronization Guide

## Overview

The MacSSH application uses multiple files to store version information. All these files must be synchronized to ensure consistent versioning across the application.

## Files That Contain Version Information

### 1. `MacSSH.xcodeproj/project.pbxproj`
- **Purpose**: Primary source of version information for Xcode builds
- **Keys**: 
  - `MARKETING_VERSION` - User-facing version (e.g., 1.8.11)
  - `CURRENT_PROJECT_VERSION` - Build number (e.g., 191)
- **Usage**: Xcode uses these values during build process

### 2. `MacSSH/Info.plist`
- **Purpose**: Bundle information for the compiled application
- **Keys**:
  - `CFBundleShortVersionString` - User-facing version (e.g., 1.8.11)
  - `CFBundleVersion` - Build version (e.g., 1.8.11)
- **Usage**: macOS reads these values to display version in Finder and About dialog

### 3. `appcast.xml`
- **Purpose**: Sparkle update feed
- **Keys**:
  - `sparkle:shortVersionString` - User-facing version (e.g., 1.8.9)
  - `sparkle:version` - Numeric version for comparison (e.g., 189)
- **Usage**: Sparkle framework uses this to check for updates

## Automatic Version Synchronization

The GitHub Actions workflow automatically synchronizes versions across all files:

### Workflow Steps

1. **Read Current Version**: Extracts version from `project.pbxproj`
2. **Calculate New Version**: Increments patch version (e.g., 1.8.11 → 1.8.12)
3. **Update project.pbxproj**: 
   - `MARKETING_VERSION = 1.8.12`
   - `CURRENT_PROJECT_VERSION = 192`
4. **Update Info.plist**:
   - `CFBundleShortVersionString = 1.8.12`
   - `CFBundleVersion = 1.8.12`
5. **Update appcast.xml**: Adds new entry with version 1.8.12

### Version Increment Logic

```bash
# Current version: 1.8.11
MAJOR=1
MINOR=8
PATCH=11

# New version: 1.8.12
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
```

## Manual Version Updates

If you need to update versions manually, use these commands:

### Update project.pbxproj
```bash
# Update MARKETING_VERSION
sed -i '' 's/MARKETING_VERSION = 1\.8\.11;/MARKETING_VERSION = 1.8.12;/g' MacSSH.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION
sed -i '' 's/CURRENT_PROJECT_VERSION = 191;/CURRENT_PROJECT_VERSION = 192;/g' MacSSH.xcodeproj/project.pbxproj
```

### Update Info.plist
```bash
# Update both CFBundleShortVersionString and CFBundleVersion
sed -i '' 's/<string>1\.8\.11<\/string>/<string>1.8.12<\/string>/g' MacSSH/Info.plist
```

### Update appcast.xml
```bash
# Use the update script
./update_appcast.sh "1.8.12" "192" "MacSSH-1.8.12.dmg"
```

## Version Consistency Check

To verify that all files have the same version:

```bash
# Check project.pbxproj
grep 'MARKETING_VERSION = ' MacSSH.xcodeproj/project.pbxproj | head -1

# Check Info.plist
grep 'CFBundleShortVersionString' MacSSH/Info.plist

# Check appcast.xml (latest entry)
grep -A 1 '<title>MacSSH' appcast.xml | head -2
```

## Common Issues

### 1. Version Mismatch
- **Problem**: Different versions in different files
- **Solution**: Use automatic workflow or manual synchronization commands

### 2. Build Number Mismatch
- **Problem**: `CURRENT_PROJECT_VERSION` doesn't match `sparkle:version`
- **Solution**: Ensure build numbers are synchronized

### 3. Sparkle Update Issues
- **Problem**: Updates not detected due to version format
- **Solution**: Use numeric `sparkle:version` (e.g., 192 for 1.8.12)

## Best Practices

1. **Always use automatic workflow** for version updates
2. **Never manually edit versions** without updating all files
3. **Test version consistency** after any manual changes
4. **Use semantic versioning** (MAJOR.MINOR.PATCH)
5. **Keep build numbers synchronized** across all files

## Troubleshooting

### Version Not Updating in App
1. Check `project.pbxproj` - Xcode reads from here
2. Check `Info.plist` - macOS reads from here
3. Clean and rebuild the project

### Sparkle Updates Not Working
1. Check `appcast.xml` format
2. Verify `sparkle:version` is numeric
3. Ensure `sparkle:shortVersionString` matches app version

### Build Errors
1. Verify all version files are synchronized
2. Check for syntax errors in `sed` commands
3. Ensure proper escaping of special characters
