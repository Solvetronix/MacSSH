# 🛡️ Branch Protection Setup Guide

## Overview

This guide explains how to configure branch protection rules for the automatic deployment system. Proper branch protection ensures that only reviewed and tested code can trigger automatic deployments.

## ⚠️ CRITICAL WARNINGS

### 1. Main Branch Protection
**🚨 ALWAYS protect the main branch!**

The main branch is the production branch that triggers automatic deployments. It must be protected to prevent unauthorized releases.

### 2. Development Workflow
**🚨 ALWAYS work in development branch!**

All development should happen in the `development` branch, with changes merged to `main` only after review.

### 3. Pull Request Requirements
**🚨 ALWAYS require pull requests for main branch!**

Direct pushes to main should be disabled to ensure proper code review.

## 🔧 Branch Setup

### 1. Create Development Branch

#### Step 1: Create and Push Development Branch
```bash
# Create development branch from main
git checkout main
git pull origin main
git checkout -b development

# Push development branch to remote
git push -u origin development
```

#### Step 2: Set Development as Default (Optional)
1. Go to repository **Settings** → **General**
2. Under **Default branch**, select **development**
3. Click **Update**
4. Confirm the change

### 2. Configure Branch Protection

#### Step 1: Access Branch Protection
1. Go to repository **Settings** → **Branches**
2. Click **Add rule** or **Add branch protection rule**

#### Step 2: Configure Main Branch Protection
```
Branch name pattern: main

Protect matching branches:
✅ Require a pull request before merging
✅ Require approvals: 1 (or more as needed)
✅ Dismiss stale PR approvals when new commits are pushed
✅ Require review from code owners
✅ Require status checks to pass before merging
✅ Require branches to be up to date before merging
✅ Require conversation resolution before merging
✅ Require signed commits
✅ Require linear history
✅ Require deployments to succeed before merging

Restrict pushes that create files that are larger than: 100 MB
✅ Allow force pushes
✅ Allow deletions
```

#### Step 3: Configure Development Branch Protection (Optional)
```
Branch name pattern: development

Protect matching branches:
✅ Require a pull request before merging
✅ Require approvals: 1
✅ Require status checks to pass before merging
✅ Require branches to be up to date before merging

✅ Allow force pushes
✅ Allow deletions
```

## 📋 Branch Protection Checklist

### Main Branch Protection
- [ ] Require pull request before merging
- [ ] Require at least 1 approval
- [ ] Dismiss stale approvals on new commits
- [ ] Require review from code owners
- [ ] Require status checks to pass
- [ ] Require branches to be up to date
- [ ] Require conversation resolution
- [ ] Require signed commits
- [ ] Require linear history
- [ ] Require deployments to succeed

### Development Branch Protection
- [ ] Require pull request before merging
- [ ] Require at least 1 approval
- [ ] Require status checks to pass
- [ ] Require branches to be up to date

### General Settings
- [ ] Restrict file size uploads
- [ ] Configure force push permissions
- [ ] Configure deletion permissions

## 🔄 Workflow Configuration

### 1. Development Workflow
```bash
# Start development
git checkout development
git pull origin development

# Make changes
# ... code changes ...

# Commit changes
git add .
git commit -m "feat: Add new feature"

# Push to development
git push origin development
```

### 2. Release Workflow
```bash
# Create pull request from development to main
# OR merge directly (if allowed)

# The system will automatically:
# 1. Trigger deployment workflow
# 2. Increment version
# 3. Build application
# 4. Create GitHub release
# 5. Update appcast.xml
```

### 3. Emergency Hotfix Workflow
```bash
# For critical fixes, create hotfix branch
git checkout main
git checkout -b hotfix/critical-fix

# Make minimal changes
# ... critical fix ...

# Create pull request to main
# This bypasses development branch for urgent fixes
```

## 🚨 Security Considerations

### 1. Code Owner Configuration
Create `.github/CODEOWNERS` file:
```
# Global code owners
* @your-username @team-lead

# Specific file owners
/docs/ @documentation-team
/.github/workflows/ @devops-team
```

### 2. Required Status Checks
Configure required status checks in branch protection:
- `build` - Build verification
- `test` - Test suite execution
- `lint` - Code quality checks
- `security` - Security scanning

### 3. Signed Commits
Enable signed commits for security:
```bash
# Configure GPG signing
git config --global user.signingkey YOUR_GPG_KEY
git config --global commit.gpgsign true
```

## 🔍 Monitoring and Alerts

### 1. Branch Protection Alerts
- Monitor failed status checks
- Track pull request reviews
- Alert on direct pushes to main
- Monitor deployment failures

### 2. Workflow Monitoring
- Track deployment success rates
- Monitor build times
- Alert on failed releases
- Track version increments

### 3. Security Monitoring
- Monitor for unauthorized access
- Track certificate usage
- Alert on security vulnerabilities
- Monitor dependency updates

## 🚨 Troubleshooting

### Common Issues

#### 1. Branch Protection Too Restrictive
```bash
# Temporarily disable protection for emergency
# Go to Settings → Branches → Edit rule
# Uncheck required checks temporarily
# Re-enable after emergency fix
```

#### 2. Status Checks Not Running
- Verify workflow file location
- Check workflow trigger conditions
- Ensure GitHub Actions is enabled
- Verify repository permissions

#### 3. Pull Request Not Merging
- Check approval requirements
- Verify status checks pass
- Ensure branch is up to date
- Check conversation resolution

#### 4. Force Push Blocked
- Use pull request instead
- Request admin override
- Create new branch from main
- Rebase development branch

## 📚 Related Documentation

- [Automatic Deploy Guide](AUTOMATIC_DEPLOY_GUIDE.md) - Main deployment guide
- [GitHub Secrets Setup](GITHUB_SECRETS_SETUP.md) - Secret configuration
- [GitHub Release Guide](GITHUB_RELEASE_GUIDE.md) - Manual release process

## 🎯 Best Practices

1. **Always use pull requests** for main branch changes
2. **Require code reviews** for all changes
3. **Use conventional commits** for automatic release notes
4. **Test in development** before merging to main
5. **Monitor deployment logs** for issues
6. **Keep branches up to date** regularly
7. **Use feature branches** for complex changes
8. **Document emergency procedures** for critical fixes

## 🔄 Emergency Procedures

### Critical Hotfix Process
1. Create hotfix branch from main
2. Make minimal required changes
3. Create pull request to main
4. Request expedited review
5. Merge and deploy
6. Cherry-pick to development

### Rollback Process
1. Revert merge commit
2. Force push to main
3. Delete problematic release
4. Update appcast.xml
5. Notify team of rollback

---

**Note**: Proper branch protection is essential for maintaining code quality and preventing unauthorized deployments. Always test the workflow in a development environment first.
