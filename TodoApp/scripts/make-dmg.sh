#!/usr/bin/env bash
#
# make-dmg.sh - Create a distributable DMG for TodoApp
#
# Usage:
#   ./make-dmg.sh [options]
#
# Options:
#   --skip-build    Skip the Xcode build step (use existing .app)
#   --no-style      Skip Finder window styling (faster)
#   --version VER   Append version to DMG filename (e.g., TodoApp-1.0.0.dmg)
#   --help          Show this help message
#
# Example:
#   ./make-dmg.sh --version 1.0.0
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TodoApp"
XCODE_PROJECT="${ROOT_DIR}/${APP_NAME}.xcodeproj"
SCHEME="${APP_NAME}"
CONFIGURATION="Release"

# Temporary directories
BUILD_DIR="${ROOT_DIR}/build"
STAGE_DIR="/tmp/${APP_NAME}DMG-$$"
RW_DMG="/tmp/${APP_NAME}-rw-$$.dmg"
MOUNT_DIR="/Volumes/${APP_NAME}"

# Output
DIST_DIR="${ROOT_DIR}/dist"

# App location after build
APP_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

# DMG styling
WINDOW_WIDTH=600
WINDOW_HEIGHT=400
ICON_SIZE=100
APP_ICON_X=150
APP_ICON_Y=180
APPS_LINK_X=450
APPS_LINK_Y=180

# Background image (optional)
BG_SOURCE="/System/Library/Desktop Pictures/Solid Colors/Space Gray.png"

# ============================================================================
# Parse command line arguments
# ============================================================================

SKIP_BUILD=false
NO_STYLE=false
VERSION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --no-style)
      NO_STYLE=true
      shift
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# ============================================================================
# Helper functions
# ============================================================================

log() {
  echo "$(date '+%H:%M:%S') [INFO] $*"
}

error() {
  echo "$(date '+%H:%M:%S') [ERROR] $*" >&2
  exit 1
}

cleanup_mount() {
  if mount | grep -q "${MOUNT_DIR}"; then
    log "Unmounting ${MOUNT_DIR}..."
    for i in {1..5}; do
      if hdiutil detach "${MOUNT_DIR}" >/dev/null 2>&1; then
        return 0
      fi
      log "Retrying unmount (attempt $i/5)..."
      sleep 1
    done
    log "Force unmounting..."
    hdiutil detach "${MOUNT_DIR}" -force >/dev/null 2>&1 || true
  fi
}

cleanup_temp() {
  cleanup_mount
  rm -rf "${STAGE_DIR}" "${RW_DMG}"
}

trap cleanup_temp EXIT

# ============================================================================
# Main script
# ============================================================================

log "Starting DMG creation for ${APP_NAME}"
log "Root directory: ${ROOT_DIR}"

# Create dist directory
mkdir -p "${DIST_DIR}"

# Determine final DMG name
if [[ -n "${VERSION}" ]]; then
  FINAL_DMG="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
else
  FINAL_DMG="${DIST_DIR}/${APP_NAME}.dmg"
fi

# Remove existing DMG
if [[ -f "${FINAL_DMG}" ]]; then
  log "Removing existing DMG: ${FINAL_DMG}"
  rm -f "${FINAL_DMG}"
fi

# ============================================================================
# Build the application
# ============================================================================

if [[ "${SKIP_BUILD}" == "false" ]]; then
  log "Building ${APP_NAME} (${CONFIGURATION})..."
  
  if [[ ! -f "${XCODE_PROJECT}/project.pbxproj" ]]; then
    error "Xcode project not found at ${XCODE_PROJECT}"
  fi
  
  xcodebuild \
    -project "${XCODE_PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}" \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E '(error|warning|Building|Succeeded|Failed)' || true
  
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    error "Build failed"
  fi
  
  log "Build completed successfully"
else
  log "Skipping build (--skip-build specified)"
fi

# ============================================================================
# Verify app exists
# ============================================================================

if [[ ! -d "${APP_PATH}" ]]; then
  error "Application not found at ${APP_PATH}"
fi

# Get app version from Info.plist
APP_VERSION=$(defaults read "${APP_PATH}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
APP_BUNDLE_VERSION=$(defaults read "${APP_PATH}/Contents/Info" CFBundleVersion 2>/dev/null || echo "unknown")
log "App version: ${APP_VERSION} (build ${APP_BUNDLE_VERSION})"

# ============================================================================
# Stage DMG contents
# ============================================================================

log "Staging DMG contents..."
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"

# Copy the app
log "Copying ${APP_NAME}.app..."
cp -R "${APP_PATH}" "${STAGE_DIR}/"

# Create Applications symlink
log "Creating Applications symlink..."
ln -s /Applications "${STAGE_DIR}/Applications"

# Add background image if available
if [[ -f "${BG_SOURCE}" ]] && [[ "${NO_STYLE}" == "false" ]]; then
  log "Adding background image..."
  mkdir -p "${STAGE_DIR}/.background"
  sips -z ${WINDOW_HEIGHT} ${WINDOW_WIDTH} "${BG_SOURCE}" \
    --out "${STAGE_DIR}/.background/background.png" >/dev/null 2>&1 || true
fi

# ============================================================================
# Create read/write DMG
# ============================================================================

log "Creating temporary read/write DMG..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "${RW_DMG}" >/dev/null

# ============================================================================
# Mount and style the DMG
# ============================================================================

log "Mounting DMG for styling..."
hdiutil attach "${RW_DMG}" \
  -mountpoint "${MOUNT_DIR}" \
  -nobrowse \
  -noverify \
  -noautoopen >/dev/null

if [[ "${NO_STYLE}" == "false" ]]; then
  log "Applying Finder window styling..."
  
  # Give Finder time to register the mount
  sleep 2
  
  osascript <<EOF || log "Warning: Finder styling failed (non-critical)"
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, $((100 + WINDOW_WIDTH)), $((100 + WINDOW_HEIGHT))}
    
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to ${ICON_SIZE}
    set text size of viewOptions to 12
    
    -- Set background if available
    try
      set background picture of viewOptions to file ".background:background.png"
    end try
    
    -- Position icons
    set position of item "${APP_NAME}.app" of container window to {${APP_ICON_X}, ${APP_ICON_Y}}
    set position of item "Applications" of container window to {${APPS_LINK_X}, ${APPS_LINK_Y}}
    
    -- Update and close
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF
  
  log "Finder styling applied"
else
  log "Skipping Finder styling (--no-style specified)"
fi

# Ensure all writes are flushed
sync
sleep 1

# ============================================================================
# Unmount and compress
# ============================================================================

log "Unmounting DMG..."
cleanup_mount

log "Compressing to final DMG..."
hdiutil convert "${RW_DMG}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${FINAL_DMG}" >/dev/null

# ============================================================================
# Cleanup and finish
# ============================================================================

log "Cleaning up temporary files..."
rm -f "${RW_DMG}"
rm -rf "${STAGE_DIR}"

# Get final DMG size
DMG_SIZE=$(du -h "${FINAL_DMG}" | cut -f1)

log "✅ DMG created successfully!"
log "   Location: ${FINAL_DMG}"
log "   Size: ${DMG_SIZE}"
log "   App version: ${APP_VERSION}"

# Verify DMG
log "Verifying DMG..."
if hdiutil verify "${FINAL_DMG}" >/dev/null 2>&1; then
  log "✅ DMG verification passed"
else
  log "⚠️  DMG verification failed (non-critical)"
fi

exit 0
