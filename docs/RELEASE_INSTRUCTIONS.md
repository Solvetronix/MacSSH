# MacSSH Release Instructions

## 📦 Release Process Overview

This is the **single, global release instruction** for all MacSSH versions. Follow these steps for any release.

### 🔐 Code Signing Policy

**ВСЕ релизы MacSSH теперь ОБЯЗАТЕЛЬНО подписываются Apple Developer ID сертификатом!**

**Причины:**
- ✅ Устранение предупреждений Gatekeeper
- ✅ Профессиональный опыт установки
- ✅ Доверие пользователей
- ✅ Совместимость с автоматическими обновлениями
- ✅ Соответствие стандартам коммерческих приложений

**Требования:**
- Все релизы должны быть подписаны
- DMG должен быть очищен от технических файлов
- Размер DMG должен быть оптимизирован
- Автоматические обновления должны работать

## 🚀 How to Release

### 1. Pre-Release Preparation

#### ⚠️ CRITICAL: Branch Management
**ВСЕГДА делаем релиз из ветки `main`!**

1. **Убедитесь, что все изменения в ветке `dev` готовы**
2. **Создайте Pull Request** из `dev` в `main`
3. **Проведите code review** (если работаете в команде)
4. **Смерджите изменения** в ветку `main`
5. **Переключитесь на ветку `main`**:
   ```bash
   git checkout main
   git pull origin main
   ```

#### Version Update
1. Update version in `MacSSH.xcodeproj/project.pbxproj`:
   ```bash
   # Update MARKETING_VERSION
   sed -i '' 's/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = X.Y.Z;/g' MacSSH.xcodeproj/project.pbxproj
   
   # Update CURRENT_PROJECT_VERSION (increment build number)
   sed -i '' 's/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = BUILD_NUMBER;/g' MacSSH.xcodeproj/project.pbxproj
   ```

2. Update version in `MacSSH/Info.plist` (for consistency):
   ```xml
   <key>CFBundleVersion</key>
   <string>X.Y.Z</string>
   <key>CFBundleShortVersionString</key>
   <string>X.Y.Z</string>
   ```
   
   **Note**: Xcode uses `project.pbxproj` settings, but updating `Info.plist` ensures consistency.

#### Build Configuration
1. Set build configuration to **Release**
2. Ensure all debug symbols are disabled for production
3. Verify Sparkle framework is properly configured

### 2. Create Release Build

#### Build Process
```bash
# Clean previous builds
xcodebuild clean -project MacSSH.xcodeproj -scheme MacSSH

# Build release version
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release build

# Create DMG (use your preferred DMG creation tool)
```

#### ⚠️ IMPORTANT: Code Signing
For production releases, the app should be signed with Apple Developer ID:

```bash
# Sign the app with Developer ID
codesign --force --deep --sign "Developer ID Application: Your Name" /path/to/MacSSH.app

# Verify signature
codesign --verify --deep --strict /path/to/MacSSH.app
```

**Note:** Without code signing, users will see Gatekeeper warnings.

#### DMG Creation Requirements
- **Application**: Main `MacSSH.app`
- **Applications Folder**: Shortcut to `/Applications`
- **Clean Layout**: Professional installer appearance

### 3. 🧹 CRITICAL: DMG Cleanup

#### ⚠️ MANDATORY: Remove Technical Files

**Files to Remove:**
- All `.dSYM` files (debug symbols)
- `Sparkle.framework.dSYM`
- `Updater.app.dSYM`
- `Downloader.xpc.dSYM`
- `Installer.xpc.dSYM`
- Any `.bcsymbolmap` files
- Debug symbol folders

**Folders to Remove:**
- `MacSSH.swiftmodule` (if contains debug info)
- `PackageFrameworks` (if contains debug symbols)
- Any other debug-related folders

**Keep Only:**
- Main `MacSSH.app` application
- `Sparkle.framework` (essential for updates)
- `Applications` folder shortcut

#### Automated Cleanup Script
```bash
# Remove debug symbols from DMG contents
find /path/to/dmg/contents -name "*.dSYM" -delete
find /path/to/dmg/contents -name "*.bcsymbolmap" -delete
find /path/to/dmg/contents -name "*.swiftmodule" -type d -exec rm -rf {} +

# Remove any remaining debug folders
find /path/to/dmg/contents -name "*debug*" -type d -exec rm -rf {} +
```

### 4. GitHub Release

#### Release Creation
1. **Убедитесь, что вы в ветке `main`**:
   ```bash
   git branch
   # Должно показать: * main
   ```

2. Go to GitHub repository
3. Click "Releases" → "Create a new release"
4. Set version tag: `vX.Y.Z`
5. Set release title: `MacSSH X.Y.Z - [Brief Description]`
6. Upload cleaned DMG file
7. Add release notes from `docs/releases/RELEASE_NOTES_X.Y.Z.md`
8. Publish release

#### Release Description Template
```markdown
## What's New in MacSSH X.Y.Z

[Copy content from RELEASE_NOTES_X.Y.Z.md]

## Installation

1. Download the DMG file
2. Open the DMG and drag MacSSH to Applications
3. Launch MacSSH from Applications folder

## Automatic Updates

MacSSH includes automatic updates. The app will notify you when new versions are available.
```

### 5. Update System Configuration

#### Appcast Update
1. Update `appcast.xml` with new version information
2. Ensure download URL points to correct GitHub release
3. Update version number and release notes

#### Push Changes
```bash
# Убедитесь, что вы в ветке main
git branch
# Должно показать: * main

# Commit and push appcast.xml
git add appcast.xml
git commit -m "Update appcast.xml for version X.Y.Z"
git push origin main
```

## 📋 Pre-Release Checklist

- [ ] **Все изменения смерджены в ветку `main`**
- [ ] **Работаем из ветки `main`** (git checkout main)
- [ ] Version updated in `Info.plist`
- [ ] Release build created successfully
- [ ] **✅ Application code signed with Developer ID** (ОБЯЗАТЕЛЬНО!)
- [ ] **✅ DMG file created with clean installation**
- [ ] **✅ Technical files (DSYM, debug symbols) removed from DMG**
- [ ] **✅ Only essential files included in installer**
- [ ] **✅ DMG size optimized** (должен быть меньше 2MB)
- [ ] Release notes written (`docs/releases/RELEASE_NOTES_X.Y.Z.md`)
- [ ] GitHub description prepared
- [ ] All files are in English (no Russian text)
- [ ] Appcast.xml updated
- [ ] **✅ DMG tested on clean system** (без предупреждений Gatekeeper)

## 🧹 DMG Cleanup Checklist

### Before Final DMG Creation
- [ ] Remove all `.dSYM` files
- [ ] Remove debug symbol maps
- [ ] Remove debug module folders
- [ ] Keep only essential files
- [ ] Test DMG on clean system
- [ ] Verify installer works correctly

### Why Cleanup is Critical

**User Experience:**
- Clean, professional installer
- Smaller download size (often 50-80% reduction)
- Faster installation
- No confusing technical files

**Security:**
- No debug information exposed
- Reduced attack surface
- Professional appearance

**Professional Standards:**
- Matches commercial app standards
- Better user perception
- Easier support

## 🎯 Post-Release Actions

1. **Monitor**: Check for user issues
2. **Update**: Documentation if needed
3. **Support**: Help users with installation
4. **Feedback**: Collect user feedback
5. **Verify**: Test automatic update system
6. **Archive**: Move old release files to archive
7. **Return to dev branch**: После релиза вернитесь к разработке:
   ```bash
   git checkout dev
   git pull origin dev
   ```

## 📞 Support Information

### For Users
- Check for updates in app menu
- Download manually from GitHub releases
- Report issues through GitHub issues
- Get help through app's built-in support

### For Developers
- Follow this instruction for all releases
- Use version-specific release notes
- Test thoroughly before release
- Monitor automatic update system

## 🔧 Technical Requirements

### Build Environment
- Xcode 15.0 or newer
- macOS 14.0 or newer
- Sparkle framework properly configured

## 🌿 Git Branch Workflow

### Development Workflow
```
dev branch → разработка новых функций
    ↓
main branch → только релизы
```

### Подробный процесс:

#### 1. Разработка (всегда в `dev`)
```bash
git checkout dev
git pull origin dev
# Делайте изменения, коммиты, пуши
git add .
git commit -m "Add new feature"
git push origin dev
```

#### 2. Подготовка к релизу
```bash
# Убедитесь, что dev готова
git checkout dev
git pull origin dev

# Создайте Pull Request dev → main
# Проведите code review
# Смерджите в main
```

#### 3. Релиз (только из `main`)
```bash
git checkout main
git pull origin main
# Следуйте инструкции по релизу
```

#### 4. После релиза
```bash
git checkout dev
git pull origin dev
# Продолжайте разработку
```

### File Structure
```
MacSSH-X.Y.Z.dmg/
├── MacSSH.app/          # Main application
├── Applications/         # Shortcut to /Applications
└── [No debug files]     # Clean installation
```

### Version Naming
- Use semantic versioning (X.Y.Z)
- Tag releases as `vX.Y.Z`
- Update both CFBundleVersion and CFBundleShortVersionString

---

**This instruction applies to ALL MacSSH releases**  
**Last Updated**: August 22, 2024  
**Version**: Global Release Instruction
