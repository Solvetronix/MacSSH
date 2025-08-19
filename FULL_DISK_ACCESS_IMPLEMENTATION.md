# Full Disk Access Implementation

## Overview

Added full support for checking and requesting Full Disk Access permission for the MacSSH application.

## What was added

### 1. New PermissionsService.swift service

Created a new `PermissionsService` with the following capabilities:

- **checkFullDiskAccess()** - checks for Full Disk Access permission
- **requestFullDiskAccess()** - requests permission through dialog
- **openSystemPreferences()** - opens System Settings on Privacy & Security page
- **checkAllPermissions()** - checks all system permissions
- **canExecuteExternalCommands()** - checks ability to execute external commands

### 2. Updated SSHService

- Added Full Disk Access check in `connectToServer()` and `openTerminal()` methods
- Updated `checkAllPermissions()` method to include system permission checks
- Added recommendations for granting Full Disk Access

### 3. Updated PermissionsManagerView

- Added "Request Full Disk Access" button for requesting permission
- Added "Show Instructions" button for showing detailed instructions
- Automatic Full Disk Access check when opening the window
- Clickable rows for requesting permissions
- Automatic status update after requesting permissions

### 4. Updated ProfileViewModel

- Added Full Disk Access check on application startup
- Updated permission warning display logic

### 5. Updated instructions

- Updated instructions for new macOS versions (System Settings instead of System Preferences)
- Added emphasis on the importance of Full Disk Access
- Improved step descriptions

## How it works

### Full Disk Access Check

1. **System directory access check** - checks access to `/System/Library/CoreServices`, `/usr/bin`, `/usr/sbin`
2. **Check via ls command** - executes `ls /System/Library/CoreServices` to check real access
3. **Fallback checks** - if commands don't execute, it's considered that permission is not granted

### Permission Request

1. **Show dialog** - user is shown a dialog explaining the need for permission
2. **Open System Settings** - clicking "Open System Settings" opens the appropriate page
3. **Old version support** - automatic fallback to System Preferences for old macOS versions

### UI Integration

1. **Automatic check** - status is automatically checked when opening PermissionsManagerView
2. **Clickable elements** - permission warning rows can be clicked to request
3. **Dynamic update** - status updates after requesting permissions
4. **Visual feedback** - buttons are disabled when permissions are already granted

## Usage

### For users

1. On first application launch, a warning about required permissions will appear
2. In SSH Tools Manager, you can see the Full Disk Access status
3. You can click on the warning or "Request Full Disk Access" button to request
4. System Settings will open automatically on the correct page
5. After granting permission, status will update automatically

### For developers

```swift
// Check Full Disk Access
let hasAccess = PermissionsService.checkFullDiskAccess()

// Request permission
PermissionsService.requestFullDiskAccess()

// Check all permissions
let permissions = PermissionsService.checkAllPermissions()
```

## Compatibility

- Supports macOS 13.0+ (System Settings)
- Automatic fallback for old versions (System Preferences)
- Works with various architectures (Intel/Apple Silicon)

## Security

- Checks are performed safely without violating sandbox
- Permission requests happen through standard macOS APIs
- No direct access to system files without permission
