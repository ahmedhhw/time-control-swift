# TimeControl App Icon

This folder contains the source design assets for the TimeControl app icon.

## App Icon Design

The TimeControl icon combines three key visual elements:

1. **Clock Face** - Represents time tracking functionality
2. **Checkmark** - Represents todo completion
3. **Progress Arc** - Represents the time tracking progress indicator

### Color Scheme

- **Gradient Background**: Deep blue (#0066FF) to vibrant purple (#7C3AED)
- **Accent**: Cyan/light blue for the progress arc
- **Primary Elements**: White for clock face and checkmark

### Files

- `app-icon-source.png` - 1024x1024 source file used to generate all icon sizes

### Icon Sizes

The app icon is automatically generated for all required macOS sizes:
- 16x16 (@1x and @2x)
- 32x32 (@1x and @2x)
- 128x128 (@1x and @2x)
- 256x256 (@1x and @2x)
- 512x512 (@1x and @2x)

All generated icons are located in:
`TimeControl/TimeControl/Assets.xcassets/AppIcon.appiconset/`

### Regenerating Icons

If you need to update the app icon:

1. Replace or modify `app-icon-source.png`
2. Run the following commands from the project root:

```bash
cd TimeControl/TimeControl/Assets.xcassets/AppIcon.appiconset

# Generate all sizes
sips -z 16 16 ../../../../design/app-icon-source.png --out icon_16x16.png
sips -z 32 32 ../../../../design/app-icon-source.png --out icon_16x16@2x.png
sips -z 32 32 ../../../../design/app-icon-source.png --out icon_32x32.png
sips -z 64 64 ../../../../design/app-icon-source.png --out icon_32x32@2x.png
sips -z 128 128 ../../../../design/app-icon-source.png --out icon_128x128.png
sips -z 256 256 ../../../../design/app-icon-source.png --out icon_128x128@2x.png
sips -z 256 256 ../../../../design/app-icon-source.png --out icon_256x256.png
sips -z 512 512 ../../../../design/app-icon-source.png --out icon_256x256@2x.png
sips -z 512 512 ../../../../design/app-icon-source.png --out icon_512x512.png
sips -z 1024 1024 ../../../../design/app-icon-source.png --out icon_512x512@2x.png
```

3. Rebuild the app in Xcode

The build process will automatically compile all PNG files into a single `AppIcon.icns` file.
