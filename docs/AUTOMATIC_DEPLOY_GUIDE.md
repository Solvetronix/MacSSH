# 🚀 Automatic Deploy Guide with GitHub Actions

## Overview

This guide explains how to set up automatic deployment for MacSSH using GitHub Actions. The system automatically builds, releases, and updates the appcast.xml when changes are merged from `development` to `main` branch.

## ⚠️ CRITICAL WARNINGS

### 1. Version Management
**The system automatically updates version in `project.pbxproj`, NOT in `Info.plist`!**

This follows the critical requirement from the manual release guide. Xcode uses `project.pbxproj` settings to override `Info.plist`.

### 2. Branch Protection
**🚨 ALWAYS merge from `development` to `main` to trigger automatic deployment!**

The GitHub Actions workflow is configured to trigger only on pushes to the `main` branch. This ensures:
- All changes are properly reviewed before deployment
- Automatic version increment happens only for production releases
- The appcast.xml is updated automatically

### 3. Release Notes Requirement
**🚨 ALWAYS provide release notes when merging to main!**

The system requires release notes to be provided in the merge commit message or pull request description. This ensures:
- Proper documentation of changes
- Automatic generation of release descriptions
- Professional release notes for users

## 🔧 Prerequisites

### 1. GitHub Repository Setup
- Repository must have `development` and `main` branches
- GitHub Actions must be enabled
- Repository secrets must be configured

### 2. Required GitHub Secrets
```bash
# For code signing (if required)
SIGNING_CERTIFICATE_BASE64
SIGNING_CERTIFICATE_PASSWORD

# For Sparkle signing (if required)
SPARKLE_PRIVATE_KEY_BASE64

# For GitHub API access
GITHUB_TOKEN (automatically provided)
```

### 3. Branch Protection Rules
Configure branch protection for `main` branch:
- Require pull request reviews
- Require status checks to pass
- Require branches to be up to date
- Restrict pushes to matching branches

## 📋 Automatic Deployment Process

### Trigger Conditions
The automatic deployment is triggered when:
1. Code is pushed directly to `main` branch, OR
2. Pull request from `development` to `main` is merged

### Automatic Steps

#### 1. Version Increment
- Automatically increments `MARKETING_VERSION` in `project.pbxproj`
- Increments `CURRENT_PROJECT_VERSION` in `project.pbxproj`
- Uses semantic versioning (e.g., 1.8.8 → 1.8.9)

#### 2. Build Process
- Cleans previous builds
- Builds application in Release configuration
- Creates DMG package using `create-dmg`
- Signs the application (if certificates provided)

#### 3. GitHub Release
- Creates new GitHub release with incremented version
- Uploads DMG as release asset
- Generates release notes from commit messages
- Publishes release immediately

#### 4. Appcast Update
- Automatically updates `appcast.xml` with new release
- Generates Ed25519 signature (if private key provided)
- Commits and pushes updated appcast.xml

#### 5. Sparkle Integration
- Ensures compatibility with Sparkle framework
- Maintains proper version format for automatic updates
- Updates all required metadata

## 🔄 Workflow Configuration

### GitHub Actions Workflow File
The workflow is defined in `.github/workflows/auto-deploy.yml` and includes:

1. **Trigger Configuration**
   - Triggers on push to `main` branch
   - Triggers on pull request merge to `main`

2. **Environment Setup**
   - macOS runner with Xcode
   - Required tools installation
   - Certificate and key setup

3. **Build Process**
   - Xcode build with Release configuration
   - DMG creation with proper metadata
   - Code signing (if configured)

4. **Release Process**
   - GitHub release creation
   - Asset upload
   - Release notes generation

5. **Appcast Update**
   - XML parsing and modification
   - Digital signature generation
   - Git commit and push

## 📝 Release Notes Generation

### Automatic Generation
The system automatically generates release notes from:
1. **Commit Messages**: From the merge commit or last commits
2. **Pull Request Description**: If merging from PR
3. **Conventional Commits**: Parses commit types and descriptions

### Manual Override
You can provide custom release notes by:
1. **Commit Message**: Include release notes in merge commit
2. **Pull Request Description**: Add release notes to PR description
3. **Release Notes File**: Create `RELEASE_NOTES.md` in root

### Format Examples
```markdown
# Automatic from commit messages
feat: Add new SSH connection feature
fix: Resolve terminal display issue
docs: Update user documentation

# Manual override in PR description
## Release Notes
- Added new SSH connection feature
- Fixed terminal display issue
- Updated user documentation
```

## 🔐 Security and Signing

### Code Signing
If you have Apple Developer certificates:
1. Encode certificate as base64
2. Add to GitHub secrets as `SIGNING_CERTIFICATE_BASE64`
3. Add certificate password as `SIGNING_CERTIFICATE_PASSWORD`

### Sparkle Signing
For Ed25519 signatures in appcast.xml:
1. Generate Ed25519 key pair
2. Encode private key as base64
3. Add to GitHub secrets as `SPARKLE_PRIVATE_KEY_BASE64`

### Security Best Practices
- Never commit certificates or private keys
- Use GitHub secrets for sensitive data
- Rotate keys regularly
- Monitor for security alerts

## 🚀 Usage Instructions

### For Developers

#### 1. Development Workflow
```bash
# Work on development branch
git checkout development
git pull origin development

# Make your changes
# ... code changes ...

# Commit and push to development
git add .
git commit -m "feat: Add new feature"
git push origin development
```

#### 2. Release Process
```bash
# Create pull request from development to main
# OR merge directly to main

# The system will automatically:
# 1. Increment version
# 2. Build application
# 3. Create GitHub release
# 4. Update appcast.xml
```

#### 3. Manual Trigger (if needed)
```bash
# Push to main to trigger deployment
git checkout main
git merge development
git push origin main
```

### For Administrators

#### 1. Monitor Deployments
- Check GitHub Actions tab for build status
- Monitor release creation
- Verify appcast.xml updates

#### 2. Troubleshoot Issues
- Review workflow logs
- Check version increments
- Verify release assets

#### 3. Rollback (if needed)
- Delete GitHub release
- Revert appcast.xml changes
- Revert version in project.pbxproj

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] All changes tested in development branch
- [ ] Release notes prepared
- [ ] GitHub secrets configured
- [ ] Branch protection rules set

### During Deployment
- [ ] Workflow triggers successfully
- [ ] Version increments correctly
- [ ] Build completes without errors
- [ ] DMG package created
- [ ] GitHub release published
- [ ] Appcast.xml updated

### Post-Deployment
- [ ] Release assets available
- [ ] Appcast.xml accessible
- [ ] Automatic updates working
- [ ] Documentation updated

## 🔍 Troubleshooting

### Common Issues

#### 1. Workflow Not Triggering
```bash
# Check branch name
git branch -a

# Ensure pushing to main
git push origin main

# Check workflow file location
ls -la .github/workflows/
```

#### 2. Version Not Incrementing
```bash
# Check project.pbxproj
grep -r "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" MacSSH.xcodeproj/

# Verify workflow permissions
# Check GitHub Actions settings
```

#### 3. Build Failures
```bash
# Check Xcode project
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean

# Verify dependencies
# Check signing certificates
```

#### 4. Release Creation Failed
```bash
# Check GitHub token permissions
# Verify release doesn't already exist
# Check asset upload limits
```

#### 5. Appcast Update Failed
```bash
# Check XML format
# Verify signature generation
# Check git permissions
```

## 📚 Related Documentation

- [GitHub Release Guide](GITHUB_RELEASE_GUIDE.md) - Manual release process
- [Version Management Guide](VERSION_MANAGEMENT_GUIDE.md) - Version management
- [Sparkle Setup Guide](SPARKLE_SETUP.md) - Sparkle configuration
- [Automatic Update Guide](AUTOMATIC_UPDATE_GUIDE.md) - Update system overview

## 🎯 Best Practices

1. **Always test in development branch** before merging to main
2. **Provide meaningful commit messages** for automatic release notes
3. **Monitor deployment logs** for any issues
4. **Keep GitHub secrets secure** and rotate regularly
5. **Use semantic versioning** consistently
6. **Test automatic updates** after each deployment
7. **Document breaking changes** in release notes
8. **Monitor for failed deployments** and fix quickly

---

**Note**: This automatic deployment system ensures consistent, reliable releases while maintaining compatibility with the Sparkle automatic update system. Always test the deployment process in a development environment first.
