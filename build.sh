#!/bin/bash
# Build VocalCue as a proper macOS .app bundle
set -e

echo "🔨 Building VocalCue..."
swift build -c release 2>&1

echo "📦 Creating app bundle..."
APP_NAME="VocalCue"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Clean previous build
rm -rf build
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy executable
cp .build/release/VocalCue "${MACOS}/VocalCue"

# Copy Info.plist
cp VocalCue/Info.plist "${CONTENTS}/Info.plist"

# Copy resources bundle if exists
BUNDLE_PATH=$(find .build/release -name "VocalCue_VocalCue.bundle" -type d 2>/dev/null | head -1)
if [ -n "$BUNDLE_PATH" ]; then
    cp -R "$BUNDLE_PATH" "${RESOURCES}/"
    echo "  ✅ Resources bundle copied"
fi

# Copy entitlements (for signing reference)
cp VocalCue/VocalCue.entitlements "${CONTENTS}/"

# Ad-hoc sign with entitlements
codesign --force --deep --sign - --entitlements VocalCue/VocalCue.entitlements "${APP_DIR}" 2>/dev/null || true

echo ""
echo "✅ Build complete!"
echo "📍 App location: $(pwd)/${APP_DIR}"
echo ""
echo "🚀 To run: open \"${APP_DIR}\""
echo "   or: \"${MACOS}/VocalCue\""
