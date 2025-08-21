# Xcode Project Version Management Guide

## Problem: Application Version Not Updating

### Problem Description
The application shows an incorrect version (e.g., 1.0) even though the correct version (e.g., 1.8.3) is specified in `Info.plist`. This happens because Xcode uses version settings from `project.pbxproj`, not from `Info.plist`.

### Root Cause
Xcode automatically generates `Info.plist` based on project settings:
- `MARKETING_VERSION` - user-facing version (e.g., 1.8.3)
- `CURRENT_PROJECT_VERSION` - build number (e.g., 183)

### Solution

#### 1. Through Xcode (Recommended Method)
1. Open the project in Xcode
2. Select the project target
3. Go to **General** → **Identity**
4. Update:
   - **Version** (MARKETING_VERSION)
   - **Build** (CURRENT_PROJECT_VERSION)

#### 2. Through Command Line
```bash
# Update MARKETING_VERSION
sed -i '' 's/MARKETING_VERSION = 1\.0;/MARKETING_VERSION = 1.8.3;/g' MacSSH.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION
sed -i '' 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = 183;/g' MacSSH.xcodeproj/project.pbxproj
```

#### 3. Verify Changes
```bash
# Check version settings in project
grep -r "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" MacSSH.xcodeproj/

# Check version in built application
defaults read /path/to/app.app/Contents/Info.plist CFBundleShortVersionString
```

### Complete Action Sequence

1. **Clean Project:**
   ```bash
   xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean
   ```

2. **Update Version in project.pbxproj:**
   ```bash
   sed -i '' 's/MARKETING_VERSION = 1\.0;/MARKETING_VERSION = 1.8.3;/g' MacSSH.xcodeproj/project.pbxproj
   sed -i '' 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = 183;/g' MacSSH.xcodeproj/project.pbxproj
   ```

3. **Rebuild Project:**
   ```bash
   xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build
   ```

4. **Verify Version:**
   ```bash
   defaults read /Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/MacSSH.app/Contents/Info.plist CFBundleShortVersionString
   ```

### Important Points

- **Always update version in project.pbxproj**, not just in `Info.plist`
- **Clean project** before rebuilding (`xcodebuild clean`)
- **Check version** in the built application, not in the source `Info.plist`
- **Use semantic versioning** (e.g., 1.8.3)

### Connection to Update System

Correct version is critical for:
- **Sparkle Framework** - for comparison with GitHub releases
- **GitHub Releases** - for determining available updates
- **User Interface** - for displaying current version

### Problem Diagnosis

If version is still incorrect:

1. **Check Xcode Cache:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/MacSSH-*
   ```

2. **Check Project Settings:**
   ```bash
   grep -r "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" MacSSH.xcodeproj/
   ```

3. **Check Info.plist in Built Application:**
   ```bash
   cat /path/to/app.app/Contents/Info.plist | grep CFBundleShortVersionString
   ```

### Version Examples

| Version | MARKETING_VERSION | CURRENT_PROJECT_VERSION |
|---------|------------------|------------------------|
| 1.8.3   | 1.8.3           | 183                    |
| 2.0.0   | 2.0.0           | 200                    |
| 1.9.1   | 1.9.1           | 191                    |

---

**Note:** This guide solves the problem we encountered when setting up automatic updates through Sparkle Framework.
