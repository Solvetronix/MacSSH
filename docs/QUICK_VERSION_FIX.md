# 🚀 Quick Fix for Application Version Problem

## Problem
The application shows version 1.0 instead of the correct version (e.g., 1.8.3).

## Quick Solution

### 1. Update Version in project.pbxproj
```bash
# Update MARKETING_VERSION
sed -i '' 's/MARKETING_VERSION = 1\.0;/MARKETING_VERSION = 1.8.3;/g' MacSSH.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION
sed -i '' 's/CURRENT_PROJECT_VERSION = 1;/CURRENT_PROJECT_VERSION = 183;/g' MacSSH.xcodeproj/project.pbxproj
```

### 2. Rebuild Project
```bash
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean build
```

### 3. Verify Result
```bash
defaults read /Users/dmitry/Library/Developer/Xcode/DerivedData/MacSSH-*/Build/Products/Release/MacSSH.app/Contents/Info.plist CFBundleShortVersionString
```

## Result
The application should now show the correct version 1.8.3.

---

**Detailed Guide:** `docs/VERSION_MANAGEMENT_GUIDE.md`
