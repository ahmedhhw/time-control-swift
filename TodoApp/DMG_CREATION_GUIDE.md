# DMG Creation Guide for TodoApp

This guide explains how to create professional DMG (disk image) files for distributing TodoApp on macOS.

## Table of Contents

- [Quick Start](#quick-start)
- [Understanding DMG Files](#understanding-dmg-files)
- [Build Methods](#build-methods)
- [Advanced Options](#advanced-options)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Quick Start

### Method 1: Using Make (Recommended)

```bash
cd TodoApp
make dmg
```

The DMG will be created at `dist/TodoApp.dmg`.

### Method 2: Using the Script Directly

```bash
cd TodoApp
./scripts/make-dmg.sh
```

## Understanding DMG Files

A DMG (Disk Image) is the standard format for distributing macOS applications. When users open a DMG, they see:

1. Your application (TodoApp.app)
2. A link to the Applications folder
3. A styled Finder window (optional but professional)

Users simply drag the app to the Applications folder to install it.

## Build Methods

### Standard DMG with Styling

Creates a professional DMG with a styled Finder window:

```bash
make dmg
# or
./scripts/make-dmg.sh
```

**Time:** ~30-60 seconds  
**Output:** `dist/TodoApp.dmg`

### Quick DMG (No Styling)

Faster build without Finder window styling:

```bash
make dmg-quick
# or
./scripts/make-dmg.sh --no-style
```

**Time:** ~20-30 seconds  
**Output:** `dist/TodoApp.dmg`

### Versioned DMG

Include version number in the filename:

```bash
make dmg-version VERSION=1.0.0
# or
./scripts/make-dmg.sh --version 1.0.0
```

**Output:** `dist/TodoApp-1.0.0.dmg`

### Skip Build Step

Use an existing .app bundle without rebuilding:

```bash
make dmg-skip-build
# or
./scripts/make-dmg.sh --skip-build
```

Useful when you've already built the app and just want to repackage it.

### Clean Release Build

Start fresh with a clean build:

```bash
make release
```

This runs `make clean` followed by `make dmg`.

## Advanced Options

### All Available Make Targets

```bash
make help           # Show all available commands
make build          # Build release version only
make build-debug    # Build debug version
make run            # Build and run the app
make clean          # Remove all build artifacts
make dmg            # Create styled DMG
make dmg-quick      # Create DMG without styling
make dmg-version    # Create versioned DMG
make dmg-skip-build # Create DMG from existing build
make open-dmg       # Open the generated DMG
make install        # Build DMG and open for installation
make info           # Show project information
make archive        # Create timestamped DMG archive
make release        # Clean build + create DMG
```

### Script Options

```bash
./scripts/make-dmg.sh --help

Options:
  --skip-build    Skip the Xcode build step
  --no-style      Skip Finder window styling
  --version VER   Append version to DMG filename
  --help          Show help message
```

### Combining Options

```bash
# Quick versioned DMG without styling
./scripts/make-dmg.sh --no-style --version 1.0.0

# Use existing build with version
./scripts/make-dmg.sh --skip-build --version 1.0.0
```

## Customization

### Changing Window Layout

Edit `scripts/make-dmg.sh` and modify these variables:

```bash
# Window dimensions
WINDOW_WIDTH=600
WINDOW_HEIGHT=400

# Icon size
ICON_SIZE=100

# Icon positions (x, y coordinates)
APP_ICON_X=150
APP_ICON_Y=180
APPS_LINK_X=450
APPS_LINK_Y=180
```

### Custom Background Image

Replace the background image source:

```bash
# In make-dmg.sh, change:
BG_SOURCE="/path/to/your/custom-background.png"
```

The image will be automatically resized to match the window dimensions.

### Volume Name

The DMG volume name is set to "TodoApp" by default. To change it:

```bash
# In make-dmg.sh, modify:
APP_NAME="YourAppName"
```

## Troubleshooting

### "Application not found" Error

**Problem:** The .app bundle wasn't built successfully.

**Solution:**
```bash
# Try building manually first
make build

# Check if the app exists
ls -la build/Build/Products/Release/TodoApp.app

# If build fails, check Xcode project
xcodebuild -project TodoApp.xcodeproj -list
```

### Finder Styling Doesn't Apply

**Problem:** The Finder window doesn't have the custom layout.

**Cause:** This is usually due to timing issues with Finder or macOS security settings.

**Solution:**
- This is non-critical; the DMG still works
- Try running the script again
- Use `--no-style` to skip styling
- Check System Preferences → Security & Privacy → Automation

### DMG Already Mounted

**Problem:** `/Volumes/TodoApp` is already in use.

**Solution:**
```bash
# Manually unmount
hdiutil detach /Volumes/TodoApp

# Or force unmount
hdiutil detach /Volumes/TodoApp -force
```

### Build Fails with Code Signing Error

**Problem:** Xcode requires code signing.

**Solution:**
The script disables code signing by default. If you need to sign:

```bash
# Edit make-dmg.sh and remove these lines:
CODE_SIGN_IDENTITY="" \
CODE_SIGNING_REQUIRED=NO \
CODE_SIGNING_ALLOWED=NO \
```

### Permission Denied

**Problem:** Script isn't executable.

**Solution:**
```bash
chmod +x scripts/make-dmg.sh
chmod +x scripts/quick-dmg.sh
```

### Insufficient Disk Space

**Problem:** Not enough space in `/tmp`.

**Solution:**
```bash
# Check available space
df -h /tmp

# Clean up old temporary files
rm -rf /tmp/TodoApp*
```

## Best Practices

### For Development

Use quick builds without styling:

```bash
make dmg-quick
```

### For Testing

Build with styling to test the user experience:

```bash
make dmg
```

### For Release

Always do a clean release build:

```bash
make release
```

### Version Numbering

Use semantic versioning in DMG filenames:

```bash
make dmg-version VERSION=1.0.0    # Initial release
make dmg-version VERSION=1.1.0    # Feature update
make dmg-version VERSION=1.0.1    # Bug fix
```

### Archiving Builds

Keep timestamped archives of your builds:

```bash
make archive
```

This creates a copy with a timestamp like `TodoApp-20260211-143022.dmg`.

### Pre-Release Checklist

Before creating a release DMG:

1. ✅ Update version number in Xcode project
2. ✅ Test the app thoroughly
3. ✅ Update README and documentation
4. ✅ Clean build: `make clean`
5. ✅ Create DMG: `make release`
6. ✅ Test the DMG on a clean system
7. ✅ Verify the app launches from the DMG
8. ✅ Check code signing (if applicable)

### Distribution Checklist

Before distributing:

1. ✅ DMG opens correctly
2. ✅ App icon displays properly
3. ✅ Finder window layout looks good
4. ✅ Drag-and-drop to Applications works
5. ✅ App launches after installation
6. ✅ File size is reasonable
7. ✅ DMG verification passes

## File Locations

```
TodoApp/
├── Makefile                    # Build automation
├── scripts/
│   ├── make-dmg.sh            # Main DMG creation script
│   ├── quick-dmg.sh           # Quick DMG wrapper
│   └── README.md              # Scripts documentation
├── build/                     # Build artifacts (temporary)
│   └── Build/Products/Release/
│       └── TodoApp.app        # Compiled application
└── dist/                      # Distribution files (output)
    ├── TodoApp.dmg            # Standard DMG
    └── TodoApp-1.0.0.dmg      # Versioned DMG
```

## Technical Details

### Build Process

1. **Compilation**: Xcode builds the app in Release configuration
2. **Staging**: Creates temporary directory with app and Applications symlink
3. **DMG Creation**: Creates read/write DMG from staged contents
4. **Mounting**: Mounts DMG for styling
5. **Styling**: Applies Finder window layout via AppleScript
6. **Compression**: Converts to compressed read-only format (UDZO)
7. **Verification**: Verifies DMG integrity
8. **Cleanup**: Removes temporary files

### DMG Format

- **Format**: UDZO (compressed, read-only)
- **Compression**: zlib level 9 (maximum)
- **Filesystem**: HFS+
- **Typical Size**: 1-5 MB (depending on app size)

### Build Time

- Clean build + styled DMG: ~60 seconds
- Incremental build + styled DMG: ~30 seconds
- Quick DMG (no styling): ~20 seconds
- DMG only (skip build): ~10 seconds

## Getting Help

### View Script Help

```bash
./scripts/make-dmg.sh --help
```

### View Make Targets

```bash
make help
```

### Check Project Info

```bash
make info
```

### Verbose Build

For debugging, run xcodebuild directly:

```bash
xcodebuild -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -configuration Release \
  clean build
```

## Additional Resources

- [Apple Developer Documentation: Distributing Apps](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [hdiutil man page](https://ss64.com/osx/hdiutil.html)
- [xcodebuild man page](https://ss64.com/osx/xcodebuild.html)

## License

These build scripts are part of the TodoApp project and follow the same license.
