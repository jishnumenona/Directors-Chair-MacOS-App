#!/bin/bash
set -euo pipefail

# ============================================================
# DirectorsChair — Release Build Pipeline
# ============================================================
# Usage: bash scripts/build-release.sh
#
# Prerequisites:
#   1. Apple Developer Account enrolled ($99/year)
#   2. "Developer ID Application" certificate installed
#   3. Notarization credentials stored:
#      xcrun notarytool store-credentials "DirectorsChair-Notarize" \
#        --apple-id "email" --team-id "TEAM" --password "app-specific-pw"
#   4. create-dmg installed: npm install -g create-dmg (optional)
# ============================================================

SCHEME="DirectorsChair-Desktop"
APP_NAME="DirectorsChair"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
NOTARIZE_PROFILE="DirectorsChair-Notarize"

echo ""
echo "=== DirectorsChair Release Build ==="
echo ""

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Step 0: Generate DMG background if not present
if [ ! -f "installer/dmg-background.png" ]; then
    echo "[0/6] Generating DMG background..."
    swift installer/generate-dmg-background.swift
    echo ""
fi

# Step 1: Clean & Archive
echo "[1/6] Archiving ${SCHEME}..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    | tail -5

echo "Archive created: ${ARCHIVE_PATH}"
echo ""

# Step 2: Export App from Archive
echo "[2/6] Exporting app from archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "installer/ExportOptions.plist" \
    | tail -3

echo "App exported: ${APP_PATH}"
echo ""

# Step 3: Verify Code Signature
echo "[3/6] Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  Code signature: OK"

# Check with spctl (may fail without notarization)
if spctl --assess --type exec "$APP_PATH" 2>/dev/null; then
    echo "  Gatekeeper:     OK"
else
    echo "  Gatekeeper:     Will pass after notarization"
fi
echo ""

# Step 4: Create DMG
echo "[4/6] Creating DMG..."
bash installer/create-dmg.sh
echo ""

# Find the created DMG
DMG_FILE=$(ls ${BUILD_DIR}/${APP_NAME}-*.dmg 2>/dev/null | head -1)
if [ -z "$DMG_FILE" ]; then
    echo "Error: DMG file not found"
    exit 1
fi

# Step 5: Notarize DMG
echo "[5/6] Notarizing ${DMG_FILE}..."
if xcrun notarytool submit "$DMG_FILE" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait 2>&1; then
    echo "  Notarization: OK"
else
    echo ""
    echo "  WARNING: Notarization failed or credentials not configured."
    echo "  To set up notarization credentials, run:"
    echo "    xcrun notarytool store-credentials \"${NOTARIZE_PROFILE}\" \\"
    echo "      --apple-id \"your-email@example.com\" \\"
    echo "      --team-id \"XXXXXXXXXX\" \\"
    echo "      --password \"app-specific-password\""
    echo ""
    echo "  The DMG is still usable but may trigger Gatekeeper warnings."
fi
echo ""

# Step 6: Staple notarization ticket
echo "[6/6] Stapling notarization ticket..."
if xcrun stapler staple "$DMG_FILE" 2>/dev/null; then
    echo "  Stapling: OK"
else
    echo "  Stapling: Skipped (notarization may not have completed)"
fi

echo ""
echo "==========================================="
echo "  BUILD COMPLETE"
echo "==========================================="
echo ""
echo "  Output: ${DMG_FILE}"
echo "  Size:   $(du -h "$DMG_FILE" | cut -f1)"
echo ""
echo "  To distribute:"
echo "  1. Upload to your hosting provider"
echo "  2. Update appcast.xml with the new version"
echo "  3. Sign the update with Sparkle's sign_update tool"
echo ""
