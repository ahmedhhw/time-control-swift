# TimeControl Build Scripts

This directory contains scripts for building and packaging the TimeControl macOS application.

## Scripts

### `make-dmg.sh`

Creates a distributable DMG (disk image) file for TimeControl with a styled Finder window. Supports code signing and notarization for macOS Gatekeeper compliance.

#### Usage

```bash
cd TimeControl
./scripts/make-dmg.sh [options]
```

#### Options

**Build Control:**
- `--skip-build` - Skip the Xcode build step and use an existing .app bundle
- `--no-style` - Skip Finder window styling (faster, but less polished)
- `--version VER` - Append version to DMG filename (e.g., `TimeControl-1.0.0.dmg`)

**Code Signing & Notarization:**
- `--sign` - Enable code signing with Developer ID certificate
- `--notarize` - Enable notarization (implies `--sign`, requires credentials)
- `--team-id ID` - Apple Team ID (or set `APPLE_TEAM_ID` env var)
- `--apple-id EMAIL` - Apple ID email (or set `APPLE_ID` env var)
- `--password PASS` - App-specific password (or set `APPLE_APP_PASSWORD` env var)

**Other:**
- `--help` - Show help message

#### Environment Variables

Instead of passing credentials via command-line, you can set environment variables (recommended for security):

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"           # From developer.apple.com
export APPLE_ID="your.email@example.com"      # Your Apple ID
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password
export SIGN_IDENTITY="Developer ID Application"   # Optional, this is default
```

#### Examples

**Development (Unsigned):**
```bash
# Basic usage (build and create unsigned DMG)
./scripts/make-dmg.sh

# Versioned unsigned DMG
./scripts/make-dmg.sh --version 1.0.0

# Quick DMG without styling
./scripts/make-dmg.sh --no-style --version 1.0.0-dev
```

**Distribution (Signed + Notarized):**
```bash
# Full signed and notarized DMG (requires Apple Developer account)
./scripts/make-dmg.sh --sign --notarize --version 1.0.0

# Signed only (no notarization)
./scripts/make-dmg.sh --sign --version 1.0.0

# With explicit credentials
./scripts/make-dmg.sh \
  --sign --notarize \
  --version 1.0.0 \
  --team-id "TEAM123456" \
  --apple-id "you@example.com" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Using Existing Build:**
```bash
# Notarize previously built app
./scripts/make-dmg.sh --skip-build --sign --notarize --version 1.0.0
```

#### Output

The script creates a DMG file in the `dist/` directory:
- Default: `dist/TimeControl.dmg`
- With version: `dist/TimeControl-1.0.0.dmg`

#### Features

The DMG includes:
- ✅ The TimeControl.app bundle
- ✅ Applications folder symlink for easy installation
- ✅ Styled Finder window with custom layout
- ✅ Background image
- ✅ Proper icon positioning
- ✅ Compressed format for smaller file size
- ✅ Automatic verification
- ✅ **Optional:** Code signing with Developer ID certificate
- ✅ **Optional:** Apple notarization for Gatekeeper compliance

#### Build Modes

**1. Unsigned (Development)**
- No code signing
- Works locally but fails when downloaded from internet
- Fast (30 seconds)
- Free
- **Use for:** Local testing, development

**2. Signed (Beta Testing)**
- Code signed with Developer ID
- Users need to right-click and select "Open"
- Medium speed (45 seconds)
- Requires Apple Developer account ($99/year)
- **Use for:** Beta testers, limited distribution

**3. Signed + Notarized (Production)**
- Code signed and notarized by Apple
- Opens normally without warnings
- Slow (6-12 minutes due to Apple notarization)
- Requires Apple Developer account ($99/year)
- **Use for:** Public releases, GitHub downloads

#### Requirements

**For Unsigned Builds:**
- macOS with Xcode Command Line Tools
- Xcode project must be buildable
- Sufficient disk space in `/tmp` for temporary files

**For Signed/Notarized Builds (Additional):**
- Apple Developer account ($99/year)
- Developer ID Application certificate installed in Keychain
- App-specific password from appleid.apple.com
- Team ID from developer.apple.com
- Internet connection for notarization

**Setup Guide:** See `CODE_SIGNING_GUIDE.md` in project root for complete setup instructions.

#### Troubleshooting

**"Application not found" error:**
- Make sure the Xcode project builds successfully
- Try running without `--skip-build`

**Finder styling doesn't apply:**
- This is usually non-critical and won't affect functionality
- Try running the script again
- Use `--no-style` to skip styling

**DMG already mounted:**
- Manually unmount: `hdiutil detach /Volumes/TimeControl`
- The script will attempt to unmount automatically

**Build fails:**
- Check that Xcode is installed: `xcode-select --install`
- Verify the project builds in Xcode
- Check for code signing issues

**"Developer ID certificate not found":**
- Install Developer ID Application certificate from developer.apple.com
- Verify: `security find-identity -v -p codesigning`

**"Invalid credentials" for notarization:**
- Verify `APPLE_TEAM_ID`, `APPLE_ID`, and `APPLE_APP_PASSWORD`
- Generate new app-specific password at appleid.apple.com
- Check environment variables: `echo $APPLE_TEAM_ID`

**"Notarization failed":**
- Verify internet connection
- Wait 15 minutes (Apple's servers can be slow)
- Check Apple Developer system status
- See detailed log in script output

**Downloaded DMG shows "app is damaged":**
- This means the DMG is not signed or notarized
- Rebuild with `--sign --notarize` options
- Or provide users with workaround instructions (see CODE_SIGNING_GUIDE.md)

## How It Works

### Unsigned Build Flow

1. **Build Phase**: Compiles the app using `xcodebuild` in Release configuration (code signing disabled)
2. **Staging Phase**: Creates a temporary directory with the app and Applications symlink
3. **DMG Creation**: Creates a read/write DMG from the staged contents
4. **Styling Phase**: Mounts the DMG and applies Finder window styling via AppleScript
5. **Compression Phase**: Converts to compressed read-only DMG format
6. **Verification**: Verifies the DMG integrity

### Signed + Notarized Build Flow

1. **Build Phase**: Compiles with Developer ID code signing enabled
2. **Signature Verification**: Verifies code signature is valid
3. **Staging Phase**: Creates temporary directory with signed app
4. **DMG Creation**: Creates read/write DMG
5. **Styling Phase**: Applies Finder styling
6. **Compression Phase**: Converts to final compressed DMG
7. **Notarization Submission**: Uploads DMG to Apple's notarization service
8. **Wait for Apple**: Apple scans the DMG (5-10 minutes)
9. **Stapling**: Attaches notarization ticket to DMG
10. **Verification**: Verifies signature and notarization

### Verification Commands

```bash
# Check code signature
codesign --verify --deep --strict TimeControl.app

# Check notarization
spctl -a -vv -t install TimeControl.app

# Should show:
# accepted
# source=Notarized Developer ID
```

## Directory Structure

```
TimeControl/
├── scripts/
│   ├── make-dmg.sh          # Main DMG creation script
│   └── README.md            # This file
├── dist/                    # Output directory (created by script)
│   └── TimeControl.dmg          # Final DMG file
└── build/                   # Build artifacts (created by script)
    └── Build/Products/Release/
        └── TimeControl.app      # Compiled application
```

## Advanced Usage

### Custom Background Image

Edit the `BG_SOURCE` variable in `make-dmg.sh`:

```bash
BG_SOURCE="/path/to/your/background.png"
```

### Custom Window Layout

Edit these variables in `make-dmg.sh`:

```bash
WINDOW_WIDTH=600
WINDOW_HEIGHT=400
ICON_SIZE=100
APP_ICON_X=150
APP_ICON_Y=180
APPS_LINK_X=450
APPS_LINK_Y=180
```

### Integration with CI/CD

The script is designed to work in automated environments:

```bash
# In your CI/CD pipeline
cd TimeControl
./scripts/make-dmg.sh --version "${CI_BUILD_VERSION}" --no-style
```

## Notes

- The script uses temporary directories in `/tmp` to avoid cluttering the workspace
- All temporary files are cleaned up automatically, even if the script fails
- The DMG is verified after creation to ensure integrity
- **Code signing is now optional** - use `--sign` flag to enable
- **Notarization requires signing** - `--notarize` implies `--sign`
- Notarization takes 5-10 minutes on average, but can be longer during peak times
- Environment variables are recommended over command-line args for security
- See `../CODE_SIGNING_GUIDE.md` for complete setup and troubleshooting

## Additional Documentation

- **CODE_SIGNING_GUIDE.md** - Complete guide to setting up signing and notarization
- **CODE_SIGNING_QUICKREF.md** - Quick reference for common commands
- **CODE_SIGNING_CHECKLIST.md** - Interactive setup checklist
- **DISTRIBUTION.md** - Guide for distributing via GitHub releases
- **README.md** - Main project README with signing section
