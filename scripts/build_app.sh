#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "==> Building OneDisplay (Release configuration)..."
swift build -c release --package-path "${ROOT_DIR}"

APP_NAME="OneDisplay"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Constructing ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 1. Copy Executable
cp "${ROOT_DIR}/.build/release/OneDisplayApp" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 2. Copy CLI tool into Resources
cp "${ROOT_DIR}/.build/release/onedisplay" "${RESOURCES_DIR}/onedisplay"
chmod +x "${RESOURCES_DIR}/onedisplay"

# 3. Copy Icon
if [ -f "${ROOT_DIR}/scripts/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/scripts/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# 4. Write PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 5. Write Info.plist
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OneDisplay</string>
    <key>CFBundleIdentifier</key>
    <string>com.onedisplay.app</string>
    <key>CFBundleName</key>
    <string>OneDisplay</string>
    <key>CFBundleDisplayName</key>
    <string>OneDisplay</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 OneDisplay Contributors. Open source under MIT License.</string>
</dict>
</plist>
EOF

echo "==> Signing ${APP_NAME}.app (Ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

echo "==> Creating distributable DMG disk image..."
DMG_PATH="${DIST_DIR}/${APP_NAME}-v1.0.0.dmg"
rm -f "${DMG_PATH}"

DMG_TMP="${DIST_DIR}/dmg_staging"
rm -rf "${DMG_TMP}"
mkdir -p "${DMG_TMP}"

cp -R "${APP_BUNDLE}" "${DMG_TMP}/"
ln -s /Applications "${DMG_TMP}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TMP}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_TMP}"

echo "==> Done!"
echo "    App bundle: ${APP_BUNDLE}"
echo "    DMG image:  ${DMG_PATH}"
