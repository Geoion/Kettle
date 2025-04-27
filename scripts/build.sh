#!/bin/bash

# Exit on error
set -e

# Configuration
APP_NAME="Kettle"
SCHEME_NAME="Kettle"
CONFIGURATION="Release"
BUILD_DIR="./build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

# Create build directory if it doesn't exist
mkdir -p "${BUILD_DIR}"

echo "🚀 Building ${APP_NAME}"

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf "${APP_PATH}" "${DMG_PATH}"

# Build app
echo "📦 Building app..."
xcodebuild \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Move app to build directory
mv "${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app" "${APP_PATH}"

# Create DMG
echo "💿 Creating DMG..."
create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    "${DMG_PATH}" \
    "${APP_PATH}"

echo "✅ Build complete! DMG file is at: ${DMG_PATH}" 