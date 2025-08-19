# Quick Fix for MacSSH Permissions Issue

## Problem
`SSHConnectionError error 5` when running the installed application.

## Quick Solution (5 minutes)

### 1. Open Security Settings
- **System Preferences** → **Security & Privacy** → **Privacy**

### 2. Add MacSSH to Full Disk Access
- Select **Full Disk Access** in the left panel
- Click the lock 🔒 and enter your password
- Click **+** and add MacSSH
- ✅ Check the box

### 3. Add MacSSH to Accessibility
- Select **Accessibility** in the left panel
- Click the lock 🔒 and enter your password
- Click **+** and add MacSSH
- ✅ Check the box

### 4. Restart MacSSH
- Completely close the application
- Launch it again

## Done! 🎉

The application should now work correctly.

## If it didn't help

See detailed instructions: [PERMISSIONS_FIX.md](PERMISSIONS_FIX.md)
