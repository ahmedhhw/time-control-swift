# TimeControl Build Scripts

This directory contains scripts for building and packaging the TimeControl macOS application.

## Scripts

### `make-dmg.sh`

Creates a distributable DMG (disk image) file for TimeControl with a styled Finder window.

#### Usage

```bash
cd TimeControl
./scripts/make-dmg.sh [options]
```

#### Options

- `--skip-build` - Skip the Xcode build step and use an existing .app bundle
- `--no-style` - Skip Finder window styling (faster, but less polished)
- `--version VER` - Append version to DMG filename (e.g., `TimeControl-1.0.0.dmg`)
- `--help` - Show help message

#### Examples

**Basic usage (build and create DMG):**
```bash
./scripts/make-dmg.sh
```

**Create versioned DMG:**
```bash
./scripts/make-dmg.sh --version 1.0.0
```

**Quick DMG without styling:**
```bash
./scripts/make-dmg.sh --no-style
```

**Use existing build:**
```bash
./scripts/make-dmg.sh --skip-build
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

#### Requirements

- macOS with Xcode Command Line Tools
- Xcode project must be buildable
- Sufficient disk space in `/tmp` for temporary files

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

## How It Works

1. **Build Phase**: Compiles the app using `xcodebuild` in Release configuration
2. **Staging Phase**: Creates a temporary directory with the app and Applications symlink
3. **DMG Creation**: Creates a read/write DMG from the staged contents
4. **Styling Phase**: Mounts the DMG and applies Finder window styling via AppleScript
5. **Compression Phase**: Converts to compressed read-only DMG format
6. **Verification**: Verifies the DMG integrity

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
- Code signing is disabled by default (add signing in the build phase if needed)
