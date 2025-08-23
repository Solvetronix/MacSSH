# ⚡ Quick Start - Automatic Deploy

## 🚀 Setup in 5 Minutes

### Step 1: Create Development Branch
```bash
git checkout main
git checkout -b development
git push -u origin development
```

### Step 2: Configure Branch Protection
1. Go to **Settings** → **Branches**
2. Add rule for `main` branch
3. Enable: "Require pull request before merging"
4. Enable: "Require approvals: 1"

### Step 3: Setup GitHub Secrets (Optional)
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add `SIGNING_CERTIFICATE_BASE64` (if you have Apple certificate)
3. Add `SIGNING_CERTIFICATE_PASSWORD` (certificate password)
4. Add `SPARKLE_PRIVATE_KEY_BASE64` (if you have Sparkle key)

### Step 4: Test the System
```bash
# Make a change in development branch
echo "# Test" >> README.md
git add README.md
git commit -m "feat: Test automatic deployment"
git push origin development

# Create pull request from development to main
# OR merge directly to main
```

## ✅ What Happens Automatically

1. **Version Increment**: 1.8.8 → 1.8.9
2. **Build**: Xcode builds the app
3. **DMG Creation**: Creates installer package
4. **GitHub Release**: Creates v1.8.9 release
5. **Appcast Update**: Updates appcast.xml
6. **Sparkle Integration**: Automatic updates work

## 🔧 Configuration Files

- **`.github/workflows/auto-deploy.yml`** - Main workflow
- **`.github/CODEOWNERS`** - Code ownership rules
- **`appcast.xml`** - Sparkle update feed

## 📚 Detailed Guides

- [Complete Setup Guide](AUTOMATIC_DEPLOY_GUIDE.md)
- [GitHub Secrets Setup](GITHUB_SECRETS_SETUP.md)
- [Branch Protection Setup](BRANCH_PROTECTION_SETUP.md)
- [Testing Guide](TESTING_AUTOMATIC_DEPLOY.md)

## 🚨 Critical Notes

- **Always work in `development` branch**
- **Merge to `main` triggers deployment**
- **Version updates in `project.pbxproj` (NOT Info.plist)**
- **Appcast.xml updates automatically**

---

**Ready to deploy!** 🎉
