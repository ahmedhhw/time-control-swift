# TodoApp - Quick Reference

## 🚀 Quick Start

```bash
cd TodoApp
make dmg          # Create distributable DMG
open dist/TodoApp.dmg  # Open the DMG
```

## 📦 Common Commands

### Building

```bash
make build        # Build release version
make build-debug  # Build debug version
make run          # Build and run the app
make clean        # Clean all build artifacts
```

### Creating DMG Files

```bash
make dmg                        # Standard DMG with styling
make dmg-quick                  # Fast DMG without styling
make dmg-version VERSION=1.0.0  # Versioned DMG
make release                    # Clean build + DMG
```

### Utilities

```bash
make help         # Show all commands
make info         # Show project info
make open-dmg     # Open the generated DMG
make install      # Build and open DMG
make archive      # Create timestamped archive
```

## 🛠️ Script Usage

### Basic

```bash
./scripts/make-dmg.sh
```

### With Options

```bash
./scripts/make-dmg.sh --version 1.0.0    # Add version
./scripts/make-dmg.sh --no-style         # Skip styling
./scripts/make-dmg.sh --skip-build       # Use existing build
./scripts/make-dmg.sh --help             # Show help
```

### Quick Build

```bash
./scripts/quick-dmg.sh
```

## 📁 File Locations

- **Source**: `TodoApp/TodoApp/`
- **Xcode Project**: `TodoApp/TodoApp.xcodeproj`
- **Build Output**: `TodoApp/build/`
- **DMG Output**: `TodoApp/dist/`
- **Scripts**: `TodoApp/scripts/`

## 🎯 Common Workflows

### Development Build

```bash
make run
```

### Test Distribution

```bash
make dmg-quick
open dist/TodoApp.dmg
```

### Release Build

```bash
make clean
make dmg-version VERSION=1.0.0
```

### Quick Iteration

```bash
make build              # Build once
make dmg-skip-build     # Package multiple times
```

## 🐛 Troubleshooting

### Build Issues

```bash
make clean              # Clean everything
make build              # Try building again
```

### DMG Issues

```bash
# Unmount stuck DMG
hdiutil detach /Volumes/TodoApp -force

# Check disk space
df -h /tmp

# Clean temporary files
rm -rf /tmp/TodoApp*
```

### Permission Issues

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

## 📚 Documentation

- **Full Guide**: `DMG_CREATION_GUIDE.md`
- **Scripts**: `scripts/README.md`
- **Main README**: `../README.md`

## ⚡ Pro Tips

1. Use `make dmg-quick` during development
2. Use `make release` for final builds
3. Use `make archive` to keep build history
4. Check `make info` to see current state
5. Run `make help` when in doubt

## 🔗 Quick Links

```bash
# Edit main app
open TodoApp/ContentView.swift

# Edit build script
open scripts/make-dmg.sh

# View Xcode project
open TodoApp.xcodeproj

# Open build directory
open build/

# Open distribution directory
open dist/
```

## 📋 Pre-Release Checklist

- [ ] Update version in Xcode
- [ ] Test app functionality
- [ ] Run `make clean`
- [ ] Run `make release`
- [ ] Test DMG on clean system
- [ ] Verify app launches correctly
- [ ] Check file size is reasonable

## 🎨 Customization

Edit `scripts/make-dmg.sh` to customize:
- Window size and layout
- Icon positions
- Background image
- Volume name

See `DMG_CREATION_GUIDE.md` for details.
