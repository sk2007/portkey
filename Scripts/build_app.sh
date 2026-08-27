#!/usr/bin/env bash
set -e

APP_NAME="Portkey"
CONFIGURATION="${1:-release}"
BUILD_DIR=".build/${CONFIGURATION}"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building ${APP_NAME} in ${CONFIGURATION} mode..."
swift build -c "${CONFIGURATION}"

echo "📦 Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp "Packaging/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Write PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "✅ Successfully created ${APP_BUNDLE}!"
echo "👉 You can run it with: open ${APP_BUNDLE}"
