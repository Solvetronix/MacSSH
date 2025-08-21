# Sparkle Framework Setup Instructions

## Step-by-Step Guide to Add Sparkle to Your Xcode Project

### 1. Add Sparkle Package Dependency

1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies...**
3. In the search field, paste: `https://github.com/sparkle-project/Sparkle`
4. Click **Add Package**
5. Select your target (MacSSH) and click **Add Package**

### 2. Configure Info.plist

Add these keys to your `Info.plist` file:

```xml
<key>SUFeedURL</key>
<string>https://github.com/Solvetronix/MacSSH/releases.atom</string>

<key>SUEnableAutomaticChecks</key>
<true/>

<key>SUEnableAutomaticDownloads</key>
<true/>

<key>SUCheckInterval</key>
<integer>86400</integer>

<key>SUEnableSystemProfiling</key>
<false/>

<key>SUEnableLogging</key>
<true/>
```

### 3. Add Sparkle to Your Target

1. Select your project in Xcode
2. Select your target (MacSSH)
3. Go to **General** tab
4. In **Frameworks, Libraries, and Embedded Content**, click **+**
5. Add **Sparkle.framework**

### 4. Update Build Settings

1. Select your target
2. Go to **Build Settings**
3. Search for "Other Linker Flags"
4. Add: `-framework Sparkle`

### 5. Add Sparkle to Your App Delegate

In your `clonnerApp.swift`, add:

```swift
import Sparkle

// In your app initialization
UpdateService.initializeUpdater()
```

### 6. Add Menu Item (Optional)

Add a "Check for Updates" menu item:

1. Open `Main.storyboard` or your menu file
2. Add a menu item to the app menu
3. Set the action to: `checkForUpdates:`
4. Set the target to your app delegate

### 7. Code Signing Setup

For automatic updates to work, you need to code sign your app:

1. In Xcode, select your target
2. Go to **Signing & Capabilities**
3. Check **Automatically manage signing**
4. Select your Team
5. Set a unique Bundle Identifier

### 8. Test the Setup

1. Build and run your app
2. Check the console for Sparkle initialization messages
3. Test the "Check for Updates" functionality
4. Verify that the update dialog appears

## Troubleshooting

### Common Issues

1. **"Sparkle framework not found"**
   - Make sure you added the package dependency correctly
   - Check that Sparkle is in your target's frameworks

2. **"Update check fails"**
   - Verify your Info.plist configuration
   - Check that the feed URL is accessible
   - Ensure your GitHub releases are properly tagged

3. **"Installation fails"**
   - Check code signing settings
   - Verify app permissions
   - Ensure the app is not running from Xcode

### Debug Information

To enable debug logging, add to your Info.plist:

```xml
<key>SUEnableLogging</key>
<true/>
```

Then check the Console app for Sparkle-related messages.

## Next Steps

1. **Create GitHub releases** with proper version tags
2. **Host your appcast.xml** file (can be on GitHub Pages)
3. **Test the update process** thoroughly
4. **Sign your DMG files** with Ed25519 for security

## Security Considerations

- Always sign your DMG files
- Use HTTPS for all downloads
- Verify digital signatures
- Test the update process on different macOS versions

## Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [GitHub Releases API](https://docs.github.com/en/rest/releases)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
