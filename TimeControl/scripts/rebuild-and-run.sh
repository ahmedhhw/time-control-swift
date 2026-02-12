#!/bin/bash
# rebuild-and-run.sh
# Ensures a clean build with updated assets/icons

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="TimeControl"

echo "🔨 Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*

echo "🏗️  Building ${APP_NAME}..."
cd "$PROJECT_DIR"
xcodebuild -project ${APP_NAME}.xcodeproj \
    -scheme ${APP_NAME} \
    -configuration Debug \
    build 2>&1 | grep -E "(BUILD|error|warning)" | tail -5

echo "🚀 Killing existing app..."
killall ${APP_NAME} 2>/dev/null || true

echo "✨ Launching ${APP_NAME}..."
open ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*/Build/Products/Debug/${APP_NAME}.app

echo "✅ Done!"
