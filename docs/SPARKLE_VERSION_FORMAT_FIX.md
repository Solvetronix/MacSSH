# Sparkle Version Format Fix

## Problem Description

The application was showing "You're up to date!" even when a newer version was available in the appcast.xml. Sparkle was finding the newer version (1.8.6) but not offering the update button.

**Symptoms:**
- Sparkle logs showed: `Found item: Optional("MacSSH 1.8.6") version 1.8.6`
- But the update dialog still showed: "You're up to date! MacSSH Terminal 1.8.6 is currently the newest version available."
- No "Update" button was displayed

## Root Cause

The issue was with the **incorrect format of `sparkle:version` in appcast.xml**. Sparkle uses `CFBundleVersion` (numeric) for version comparison, not `CFBundleShortVersionString` (string).

**Wrong format (old):**
```xml
<enclosure url="..." sparkle:version="1.8.6" .../>
```

**Also wrong (string version):**
```xml
<item>
    <title>MacSSH 1.8.6</title>
    <sparkle:version>1.8.6</sparkle:version>
    <description>...</description>
    <enclosure url="..." .../>
</item>
```

**Correct format (new):**
```xml
<item>
    <title>MacSSH 1.8.6</title>
    <sparkle:version>186</sparkle:version>
    <sparkle:shortVersionString>1.8.6</sparkle:shortVersionString>
    <description>...</description>
    <enclosure url="..." .../>
</item>
```

## Solution

According to the [official Sparkle documentation](https://sparkle-project.org/documentation/publishing/):

> **Note on `sparkle:version`**: Our previous documentation used to recommend specifying `sparkle:version` (and `sparkle:shortVersionString`) as part of the `enclosure` item. While this works fine, for overall consistency we now recommend specifying them as **top level items instead** as shown here.

### Changes Made

1. **Moved `sparkle:version` from `enclosure` attributes to top-level `item` elements**
2. **Updated all versions in appcast.xml** (1.8.6, 1.8.5, 1.8.4, 1.8.2, 1.8.1, 1.8.0)
3. **Pushed changes to GitHub** to update the live appcast

### Before Fix
```xml
<item>
    <title>MacSSH 1.8.6</title>
    <description>...</description>
    <enclosure url="..." sparkle:version="1.8.6" .../>
</item>
```

### After Fix
```xml
<item>
    <title>MacSSH 1.8.6</title>
    <sparkle:version>186</sparkle:version>
    <sparkle:shortVersionString>1.8.6</sparkle:shortVersionString>
    <description>...</description>
    <enclosure url="..." .../>
</item>
```

## Testing

After applying this fix:

1. **Clear Sparkle cache:**
   ```bash
   defaults delete org.sparkle-project.Sparkle
   defaults delete solvetronix.macssh
   ```

2. **Test update check** in the application
3. **Verify** that Sparkle now properly detects newer versions and shows the update button

## Prevention

When creating new releases:

1. **Always use numeric `sparkle:version`** that matches `CFBundleVersion` (e.g., 186 for version 1.8.5)
2. **Use `sparkle:shortVersionString`** for human-readable version (e.g., 1.8.5)
3. **Follow the official Sparkle documentation** for appcast.xml structure
4. **Test update detection** after publishing new versions

### Version Mapping
- Version 1.8.5 → `sparkle:version` = 185, `sparkle:shortVersionString` = 1.8.5
- Version 1.8.6 → `sparkle:version` = 186, `sparkle:shortVersionString` = 1.8.6

## Related Files

- `appcast.xml` - Main appcast feed file
- `docs/SPARKLE_UPDATE_BUTTON_FIX.md` - Related update button issues
- `docs/GITHUB_RELEASE_INSTRUCTIONS.md` - Release creation instructions

## References

- [Sparkle Publishing Documentation](https://sparkle-project.org/documentation/publishing/)
- [Sparkle Issue #1411](https://github.com/sparkle-project/Sparkle/issues/1411) - Related discussion about version comparison issues
