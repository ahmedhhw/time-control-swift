#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TodoApp"

BUILD_DIR="/tmp/${APP_NAME}Build"
STAGE_DIR="/tmp/${APP_NAME}DMG"
RW_DMG="/tmp/${APP_NAME}-rw.dmg"
MOUNT_DIR="/Volumes/${APP_NAME}"
DIST_DIR="${ROOT_DIR}/dist"
FINAL_DMG="${DIST_DIR}/${APP_NAME}.dmg"

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
BG_SOURCE="/System/Library/Desktop Pictures/Solid Colors/Space Gray.png"

mkdir -p "${DIST_DIR}"
rm -rf "${BUILD_DIR}" "${STAGE_DIR}" "${RW_DMG}" "${FINAL_DMG}"

echo "Building ${APP_NAME}..."
xcodebuild -project "${ROOT_DIR}/${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -derivedDataPath "${BUILD_DIR}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at ${APP_PATH}"
  exit 1
fi

echo "Staging DMG contents..."
mkdir -p "${STAGE_DIR}/.background"
cp -R "${APP_PATH}" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

if [[ -f "${BG_SOURCE}" ]]; then
  sips -z 480 720 "${BG_SOURCE}" --out "${STAGE_DIR}/.background/background.png" >/dev/null
fi

echo "Creating read/write DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE_DIR}" -ov -format UDRW "${RW_DMG}" >/dev/null
hdiutil attach "${RW_DMG}" -mountpoint "${MOUNT_DIR}" >/dev/null

echo "Setting Finder window layout..."
osascript <<EOF
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 620, 420}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 120
    try
      set background picture of viewOptions to file ".background:background.png"
    end try
    set position of item "${APP_NAME}.app" of container window to {140, 200}
    set position of item "Applications" of container window to {420, 200}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "${MOUNT_DIR}" >/dev/null

echo "Compressing DMG..."
hdiutil convert "${RW_DMG}" -format UDZO -o "${FINAL_DMG}" >/dev/null
rm -f "${RW_DMG}"

echo "DMG created at ${FINAL_DMG}"
