#!/bin/bash
set -e

# DMG creation script for DirectorsChair
# Uses create-dmg (npm) with custom cinematic background

APP_NAME="DirectorsChair"
APP_PATH="build/${APP_NAME}.app"
DMG_DIR="build/dmg"

# Get version from app bundle
VERSION=$(defaults read "$(pwd)/${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_OUTPUT="build/${APP_NAME}-${VERSION}.dmg"

echo "Creating DMG for ${APP_NAME} v${VERSION}..."

# Validate app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: ${APP_PATH} not found. Run build-release.sh first."
    exit 1
fi

# Clean staging area
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Check if dmg background exists
BACKGROUND_ARG=""
if [ -f "installer/dmg-background.png" ]; then
    BACKGROUND_ARG="--background installer/dmg-background.png"
fi

# Remove existing DMG if present
rm -f "$DMG_OUTPUT"

# Create DMG with create-dmg
# Install create-dmg if not available: npm install -g create-dmg
if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 660 460 \
        --icon-size 120 \
        --icon "${APP_NAME}.app" 180 240 \
        --app-drop-link 480 240 \
        --no-internet-enable \
        ${BACKGROUND_ARG} \
        "$DMG_OUTPUT" \
        "$DMG_DIR/"
elif command -v npx &>/dev/null; then
    npx create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 660 460 \
        --icon-size 120 \
        --icon "${APP_NAME}.app" 180 240 \
        --app-drop-link 480 240 \
        --no-internet-enable \
        ${BACKGROUND_ARG} \
        "$DMG_OUTPUT" \
        "$DMG_DIR/"
else
    # Fallback: use hdiutil directly
    echo "create-dmg not found. Using hdiutil fallback..."
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_OUTPUT"
fi

# Clean staging
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
