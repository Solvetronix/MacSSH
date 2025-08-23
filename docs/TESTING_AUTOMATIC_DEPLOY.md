# 🧪 Testing Automatic Deploy Guide

## Overview

This guide explains how to test the automatic deployment system before using it in production. Proper testing ensures that the deployment process works correctly and safely.

## ⚠️ CRITICAL WARNINGS

### 1. Test Environment
**🚨 ALWAYS test in a separate repository first!**

Create a test repository to validate the deployment process before using it in production.

### 2. Version Management
**🚨 Test version increments carefully!**

Ensure that version increments work correctly and don't conflict with existing releases.

### 3. Backup Strategy
**🚨 Always have a backup plan!**

Keep manual deployment procedures as backup in case automatic deployment fails.

## 🔧 Test Environment Setup

### 1. Create Test Repository

#### Step 1: Fork or Create Test Repository
```bash
# Option 1: Fork the main repository
# Go to GitHub and fork the repository

# Option 2: Create new test repository
# Create a new repository with similar structure
```

#### Step 2: Clone Test Repository
```bash
# Clone the test repository
git clone https://github.com/your-username/MacSSH-test.git
cd MacSSH-test

# Set up remote for original repository
git remote add upstream https://github.com/Solvetronix/MacSSH.git
```

#### Step 3: Copy Configuration
```bash
# Copy workflow files
cp -r ../MacSSH/.github ./

# Copy appcast.xml
cp ../MacSSH/appcast.xml ./

# Copy Xcode project (simplified version)
cp -r ../MacSSH/MacSSH.xcodeproj ./
```

### 2. Configure Test Environment

#### Step 1: Modify Workflow for Testing
Edit `.github/workflows/auto-deploy.yml`:
```yaml
# Add test mode environment variable
env:
  TEST_MODE: true
  XCODE_PROJECT: MacSSH.xcodeproj
  XCODE_SCHEME: MacSSH
  XCODE_CONFIGURATION: Release
```

#### Step 2: Add Test Mode Logic
```yaml
# In the version increment step
- name: 🏷️ Get current version
  id: current-version
  run: |
    if [ "$TEST_MODE" = "true" ]; then
      # Use test versioning
      NEW_VERSION="0.0.1"
      NEW_BUILD="1"
    else
      # Normal version increment
      # ... existing logic ...
    fi
```

#### Step 3: Modify Release Creation
```yaml
# In the release creation step
- name: 🏷️ Create GitHub release
  run: |
    if [ "$TEST_MODE" = "true" ]; then
      echo "🧪 Test mode: Skipping actual release creation"
      echo "Would create release: ${{ steps.current-version.outputs.tag }}"
    else
      # Normal release creation
      # ... existing logic ...
    fi
```

## 📋 Testing Checklist

### Pre-Test Setup
- [ ] Test repository created
- [ ] Workflow files copied
- [ ] Test mode enabled
- [ ] GitHub secrets configured (test values)
- [ ] Branch protection configured
- [ ] Development branch created

### Test Scenarios
- [ ] Version increment logic
- [ ] Build process
- [ ] DMG creation
- [ ] Release notes generation
- [ ] Appcast.xml update
- [ ] Git commit and push
- [ ] Error handling

### Post-Test Verification
- [ ] Version numbers correct
- [ ] Build artifacts created
- [ ] Release notes generated
- [ ] Appcast.xml updated
- [ ] Git history clean
- [ ] No production impact

## 🧪 Test Scenarios

### 1. Basic Deployment Test

#### Step 1: Prepare Test Changes
```bash
# Create test feature
echo "# Test Feature" >> README.md
git add README.md
git commit -m "feat: Add test feature for deployment testing"
git push origin development
```

#### Step 2: Trigger Deployment
```bash
# Merge to main to trigger deployment
git checkout main
git merge development
git push origin main
```

#### Step 3: Monitor Workflow
1. Go to **Actions** tab in GitHub
2. Monitor the workflow execution
3. Check each step for success/failure
4. Verify outputs and artifacts

#### Step 4: Verify Results
```bash
# Check version increment
grep "MARKETING_VERSION" MacSSH.xcodeproj/project.pbxproj

# Check appcast.xml update
grep "Test Feature" appcast.xml

# Check git history
git log --oneline -5
```

### 2. Error Handling Test

#### Step 1: Introduce Build Error
```bash
# Introduce syntax error in Swift file
echo "invalid swift code" >> MacSSH/clonnerApp.swift
git add MacSSH/clonnerApp.swift
git commit -m "test: Introduce build error for testing"
git push origin development
```

#### Step 2: Test Error Handling
```bash
# Merge to main
git checkout main
git merge development
git push origin main

# Monitor workflow failure
# Verify error messages
# Check cleanup procedures
```

#### Step 3: Fix and Retest
```bash
# Fix the error
git checkout development
# Fix the Swift file
git add MacSSH/clonnerApp.swift
git commit -m "fix: Resolve build error"
git push origin development

# Merge again
git checkout main
git merge development
git push origin main
```

### 3. Version Conflict Test

#### Step 1: Simulate Version Conflict
```bash
# Manually set version to future version
sed -i '' 's/MARKETING_VERSION = 0\.0\.1/MARKETING_VERSION = 0.0.5/g' MacSSH.xcodeproj/project.pbxproj
git add MacSSH.xcodeproj/project.pbxproj
git commit -m "test: Set version to 0.0.5 for conflict testing"
git push origin main
```

#### Step 2: Test Version Resolution
```bash
# Make changes and trigger deployment
echo "# Version conflict test" >> README.md
git add README.md
git commit -m "feat: Test version conflict resolution"
git push origin development

# Merge to main
git checkout main
git merge development
git push origin main

# Verify version increment logic handles conflict
```

### 4. Security Test

#### Step 1: Test Certificate Handling
```bash
# Test with invalid certificate
# Modify workflow to use test certificate
# Verify error handling for invalid certificates
```

#### Step 2: Test Sparkle Key Handling
```bash
# Test with invalid Sparkle key
# Verify error handling for invalid keys
# Check fallback to unsigned updates
```

## 🔍 Monitoring and Debugging

### 1. Workflow Logs
```bash
# Access workflow logs
# Go to Actions → Workflow → Run → Job → Step
# Download logs for detailed analysis
```

### 2. Debug Outputs
```yaml
# Add debug outputs to workflow
- name: Debug Information
  run: |
    echo "Current version: ${{ steps.current-version.outputs.current_version }}"
    echo "New version: ${{ steps.current-version.outputs.new_version }}"
    echo "Build path: $BUILD_PATH"
    echo "DMG name: $DMG_NAME"
```

### 3. Artifact Inspection
```bash
# Download workflow artifacts
# Inspect DMG contents
# Verify appcast.xml format
# Check release notes generation
```

## 🚨 Troubleshooting Test Issues

### Common Test Problems

#### 1. Workflow Not Triggering
```bash
# Check branch names
git branch -a

# Verify workflow file location
ls -la .github/workflows/

# Check workflow trigger conditions
cat .github/workflows/auto-deploy.yml | grep -A 5 "on:"
```

#### 2. Version Increment Issues
```bash
# Check current version
grep "MARKETING_VERSION" MacSSH.xcodeproj/project.pbxproj

# Verify increment logic
# Check for version conflicts
# Ensure proper regex matching
```

#### 3. Build Failures
```bash
# Check Xcode project
xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Release clean

# Verify dependencies
# Check signing certificates
# Review build logs
```

#### 4. Release Creation Issues
```bash
# Check GitHub token permissions
# Verify release doesn't exist
# Check asset upload limits
# Review release notes format
```

## 📊 Test Results Documentation

### Test Report Template
```
Test Date: [Date]
Test Environment: [Repository URL]
Test Mode: [Enabled/Disabled]

Test Results:
✅ Version Increment: [Pass/Fail]
✅ Build Process: [Pass/Fail]
✅ DMG Creation: [Pass/Fail]
✅ Release Creation: [Pass/Fail]
✅ Appcast Update: [Pass/Fail]
✅ Error Handling: [Pass/Fail]

Issues Found:
- [Issue description]
- [Resolution]

Recommendations:
- [Recommendation]
- [Action items]
```

## 🔄 Production Migration

### 1. Gradual Rollout
```bash
# Start with non-critical releases
# Monitor deployment success rates
# Gradually increase automation
# Keep manual backup procedures
```

### 2. Monitoring Setup
```bash
# Set up alerts for deployment failures
# Monitor build times and success rates
# Track version increments
# Alert on security issues
```

### 3. Rollback Plan
```bash
# Document manual deployment procedures
# Keep backup of manual scripts
# Test rollback procedures
# Maintain emergency contacts
```

## 📚 Related Documentation

- [Automatic Deploy Guide](AUTOMATIC_DEPLOY_GUIDE.md) - Main deployment guide
- [GitHub Secrets Setup](GITHUB_SECRETS_SETUP.md) - Secret configuration
- [Branch Protection Setup](BRANCH_PROTECTION_SETUP.md) - Branch protection
- [GitHub Release Guide](GITHUB_RELEASE_GUIDE.md) - Manual release process

## 🎯 Best Practices

1. **Test thoroughly** before production use
2. **Use separate test repository** for validation
3. **Monitor all deployments** carefully
4. **Keep manual procedures** as backup
5. **Document all test results** and issues
6. **Gradually increase automation** confidence
7. **Set up proper monitoring** and alerts
8. **Have rollback procedures** ready

---

**Note**: Comprehensive testing is essential for reliable automatic deployment. Never skip testing steps, especially for critical production systems.
