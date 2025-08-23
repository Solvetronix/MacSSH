# 🔐 GitHub Secrets Setup Guide

## Overview

This guide explains how to configure GitHub Secrets for the automatic deployment system. These secrets are required for code signing and Sparkle signature generation.

## ⚠️ CRITICAL WARNINGS

### 1. Security
**🚨 NEVER commit certificates or private keys to the repository!**

All sensitive data must be stored as GitHub Secrets and accessed only during the CI/CD process.

### 2. Secret Rotation
**🚨 Rotate secrets regularly for security!**

Update certificates and keys periodically to maintain security.

### 3. Access Control
**🚨 Limit access to repository secrets!**

Only repository administrators should have access to secrets.

## 🔧 Required Secrets

### 1. Code Signing Certificate (Optional)

#### Purpose
Signs the DMG file with your Apple Developer certificate for distribution outside the App Store.

#### Setup Instructions

##### Step 1: Export Certificate
```bash
# Open Keychain Access
# Find your "Developer ID Application" certificate
# Right-click → Export
# Choose .p12 format
# Set a password for the certificate
```

##### Step 2: Encode Certificate
```bash
# Encode certificate as base64
base64 -i "path/to/your/certificate.p12" | pbcopy
```

##### Step 3: Add to GitHub Secrets
1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SIGNING_CERTIFICATE_BASE64`
5. Value: Paste the base64 encoded certificate
6. Click **Add secret**

##### Step 4: Add Certificate Password
1. Click **New repository secret**
2. Name: `SIGNING_CERTIFICATE_PASSWORD`
3. Value: The password you set when exporting the certificate
4. Click **Add secret**

### 2. Sparkle Private Key (Optional)

#### Purpose
Generates Ed25519 signatures for the appcast.xml file, ensuring update security.

#### Setup Instructions

##### Step 1: Generate Ed25519 Key Pair
```bash
# Install Sparkle command line tools
brew install sparkle

# Generate key pair
sparkle_sign_update --generate-keys

# This creates:
# - sparkle_private_key.pem (private key)
# - sparkle_public_key.pem (public key)
```

##### Step 2: Encode Private Key
```bash
# Encode private key as base64
base64 -i "sparkle_private_key.pem" | pbcopy
```

##### Step 3: Add to GitHub Secrets
1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SPARKLE_PRIVATE_KEY_BASE64`
5. Value: Paste the base64 encoded private key
6. Click **Add secret**

##### Step 4: Add Public Key to Repository
```bash
# Copy public key to repository
cp sparkle_public_key.pem MacSSH/

# Commit and push
git add MacSSH/sparkle_public_key.pem
git commit -m "Add Sparkle public key for update verification"
git push origin main
```

### 3. GitHub Token (Automatic)

#### Purpose
Automatically provided by GitHub Actions for API access.

#### Note
The `GITHUB_TOKEN` secret is automatically provided by GitHub Actions and doesn't need manual configuration.

## 📋 Secret Configuration Checklist

### Required Secrets
- [ ] `SIGNING_CERTIFICATE_BASE64` (optional)
- [ ] `SIGNING_CERTIFICATE_PASSWORD` (optional)
- [ ] `SPARKLE_PRIVATE_KEY_BASE64` (optional)

### Verification Steps
- [ ] All secrets are properly encoded as base64
- [ ] Certificate password matches the exported certificate
- [ ] Private key is in correct PEM format
- [ ] Public key is committed to repository
- [ ] Secrets are accessible to GitHub Actions

## 🔍 Testing Secrets

### Test Code Signing
```bash
# Test certificate decoding
echo "$SIGNING_CERTIFICATE_BASE64" | base64 -d > test_cert.p12

# Test certificate import
security import test_cert.p12 -k login.keychain -P "$SIGNING_CERTIFICATE_PASSWORD"

# Clean up
rm test_cert.p12
```

### Test Sparkle Key
```bash
# Test private key decoding
echo "$SPARKLE_PRIVATE_KEY_BASE64" | base64 -d > test_key.pem

# Test signature generation
sparkle_sign_update test_file.dmg test_key.pem

# Clean up
rm test_key.pem
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Certificate Import Failed
```bash
# Check certificate format
file certificate.p12

# Verify certificate password
security find-certificate -c "Developer ID Application" login.keychain
```

#### 2. Sparkle Key Invalid
```bash
# Check key format
openssl rsa -in sparkle_private_key.pem -check

# Verify key pair
sparkle_sign_update --verify-keys sparkle_private_key.pem sparkle_public_key.pem
```

#### 3. Base64 Encoding Issues
```bash
# Re-encode certificate
base64 -i certificate.p12 | tr -d '\n' | pbcopy

# Re-encode private key
base64 -i sparkle_private_key.pem | tr -d '\n' | pbcopy
```

#### 4. GitHub Actions Access Denied
- Check repository permissions
- Verify secret names match workflow
- Ensure secrets are not expired

## 🔄 Secret Rotation

### When to Rotate
- Certificate expires
- Key compromise suspected
- Regular security maintenance
- Apple Developer account changes

### Rotation Process
1. Generate new certificate/key
2. Update GitHub secrets
3. Test deployment
4. Remove old secrets
5. Update documentation

### Backup Strategy
- Store certificates securely
- Document rotation procedures
- Maintain key recovery process

## 📚 Related Documentation

- [Automatic Deploy Guide](AUTOMATIC_DEPLOY_GUIDE.md) - Main deployment guide
- [GitHub Release Guide](GITHUB_RELEASE_GUIDE.md) - Manual release process
- [Sparkle Setup Guide](SPARKLE_SETUP.md) - Sparkle configuration

## 🎯 Best Practices

1. **Use strong passwords** for certificates
2. **Store backups securely** of all keys
3. **Rotate secrets regularly** for security
4. **Test secrets** before deployment
5. **Document all procedures** for team access
6. **Monitor for security alerts** from Apple/Sparkle
7. **Limit access** to repository secrets
8. **Use environment-specific** secrets if needed

---

**Note**: Proper secret configuration is critical for secure automatic deployments. Always test the configuration before relying on it for production releases.
