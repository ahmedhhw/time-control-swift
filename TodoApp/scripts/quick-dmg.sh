#!/usr/bin/env bash
#
# quick-dmg.sh - Quick DMG creation without styling (faster)
#
# This is a simplified wrapper around make-dmg.sh for quick iterations.
# Use this during development when you need a DMG quickly without the
# Finder styling overhead.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Creating quick DMG (no styling)..."
"${SCRIPT_DIR}/make-dmg.sh" --no-style "$@"
