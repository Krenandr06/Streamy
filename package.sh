#!/bin/bash
set -e

echo "🔨 Building Streamy release..."
swift build -c release

APP_NAME="Streamy"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating ${APP_DIR} bundle structure..."
rm -rf "${APP_DIR}" "${APP_NAME}-macOS.zip"

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy compiled executable
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/"

# Copy bundle Info.plist metadata
if [ -f "Info.plist" ]; then
    cp "Info.plist" "${CONTENTS_DIR}/"
fi

# Copy App icons and resources
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/"
fi
if [ -f "icon.png" ]; then
    cp "icon.png" "${RESOURCES_DIR}/"
fi

# Copy SPM Resource bundle if created during build
if [ -d ".build/release/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R ".build/release/${APP_NAME}_${APP_NAME}.bundle" "${RESOURCES_DIR}/"
fi

echo "🤐 Creating ${APP_NAME}-macOS.zip..."
zip -r "${APP_NAME}-macOS.zip" "${APP_DIR}"

echo "✅ Success! Package created: ${APP_DIR} & ${APP_NAME}-macOS.zip"
