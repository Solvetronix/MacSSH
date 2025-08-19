# MacSSH Permissions Fix Guide

## Problem

If you receive an `SSHConnectionError error 5` when running the installed MacSSH application, it means the application doesn't have the necessary permissions to execute external commands (ssh, ssh-keyscan, sftp, scp).

## Cause

In macOS, signed and installed applications have limited permissions by default. The application cannot execute external commands without explicit user permission.

## Solution

### 1. Add MacSSH to Full Disk Access

1. Open **System Preferences**
2. Go to **Security & Privacy**
3. Select the **Privacy** tab
4. In the left panel, select **Full Disk Access**
5. Click the lock 🔒 at the bottom of the window and enter your administrator password
6. Click the **+** button and add the MacSSH application
7. Make sure the checkbox next to MacSSH is checked

### 2. Add MacSSH to Accessibility

1. In the same **Security & Privacy > Privacy** window
2. In the left panel, select **Accessibility**
3. Click the lock 🔒 and enter your administrator password
4. Click the **+** button and add the MacSSH application
5. Make sure the checkbox next to MacSSH is checked

### 3. Add MacSSH to Automation (if necessary)

1. In the same **Security & Privacy > Privacy** window
2. In the left panel, select **Automation**
3. Click the lock 🔒 and enter your administrator password
4. Click the **+** button and add the MacSSH application
5. Allow access to Terminal.app

### 4. Install Required Tools

#### sshpass (for automatic password transmission)
```bash
brew install sshpass
```

#### sshfs (for mounting remote directories)
```bash
brew install --cask macfuse
brew install sshfs
```

### 5. Restart MacSSH

After making all changes:
1. Completely close MacSSH
2. Launch MacSSH again
3. Try connecting to the server

## Checking Permissions

In the MacSSH application:
1. Open **Tools > Required Tools** menu
2. Click **Check Permissions** button
3. Review the check results

## Alternative Solution

If the problem persists, try:

1. **Run from source** (temporarily):
   ```bash
   cd /path/to/MacSSH
   xcodebuild -project MacSSH.xcodeproj -scheme MacSSH -configuration Debug
   ```

2. **Check system logs**:
   - Open **Console.app**
   - Find entries related to MacSSH
   - Look for access or permission errors

3. **Reset permissions**:
   - Remove MacSSH from all permission lists
   - Restart MacSSH
   - Re-add permissions

## Technical Details

The MacSSH application uses the following external commands:
- `ssh-keyscan` - for checking host availability
- `ssh` - for connecting to server
- `sftp` - for working with files
- `scp` - for copying files
- `sshfs` - for mounting directories (optional)
- `sshpass` - for automatic password transmission (optional)

All these commands require execution permissions in macOS.

## Support

If the problem is not resolved, create an issue in the project repository with a description of:
- macOS version
- MacSSH version
- Exact error text
- Permission check results
