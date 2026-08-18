#!/bin/bash
set -e

echo "🔨 Building Streamy release..."
swift build -c release

APP_NAME="Streamy"
PROJECT_DIR="$(pwd)"

# Built outside the project on purpose: this project lives under ~/Documents, and macOS
# tracks where an .app bundle was first registered from. An .app born inside Documents
# (even briefly, before being dragged to /Applications) carries that as its provenance,
# which is what triggers the one-time "would like to access files in your Documents
# folder" prompt on first launch — unrelated to anything the app itself does at runtime.
# Staging the bundle in /tmp instead means it never has that folder in its history.
BUILD_ROOT="$(mktemp -d /tmp/streamy-package.XXXXXX)"
APP_DIR="${BUILD_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating ${APP_NAME}.app bundle structure in ${BUILD_ROOT}..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy compiled executable
cp "${PROJECT_DIR}/.build/release/${APP_NAME}" "${MACOS_DIR}/"

# Copy bundle Info.plist metadata
if [ -f "${PROJECT_DIR}/Info.plist" ]; then
    cp "${PROJECT_DIR}/Info.plist" "${CONTENTS_DIR}/"
fi

# Copy App icons and resources
if [ -f "${PROJECT_DIR}/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/AppIcon.icns" "${RESOURCES_DIR}/"
fi
if [ -f "${PROJECT_DIR}/icon.png" ]; then
    cp "${PROJECT_DIR}/icon.png" "${RESOURCES_DIR}/"
fi

# Copy SPM's generated resource bundle to the .app's TOP LEVEL, not Contents/Resources.
# SwiftPM's auto-generated Bundle.module accessor looks for it at
# Bundle.main.bundleURL/Streamy_Streamy.bundle — and for an .app, bundleURL is the .app's
# own root, not Contents/Resources. Putting it in Resources (the Xcode convention) means
# that lookup always misses, silently falling back to an absolute path baked in at compile
# time pointing at this machine's .build folder — which breaks the moment the project
# moves, gets rebuilt elsewhere, or the .app is shared with anyone else.
if [ -d "${PROJECT_DIR}/.build/release/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${PROJECT_DIR}/.build/release/${APP_NAME}_${APP_NAME}.bundle" "${APP_DIR}/"
fi

echo "🤐 Creating ${APP_NAME}-macOS.zip..."
rm -f "${PROJECT_DIR}/${APP_NAME}-macOS.zip"
(cd "${BUILD_ROOT}" && zip -r "${PROJECT_DIR}/${APP_NAME}-macOS.zip" "${APP_NAME}.app")

echo "✅ Success!"
echo "   App bundle: ${APP_DIR}"
echo "   Zip:        ${PROJECT_DIR}/${APP_NAME}-macOS.zip"
echo ""
echo "👉 Drag ${APP_DIR} straight into /Applications (from ${BUILD_ROOT}, not from this project folder) to keep it free of Documents-folder provenance."
