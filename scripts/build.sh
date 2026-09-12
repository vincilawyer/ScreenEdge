#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache build
APP="build/跨屏边缘.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun clang -fobjc-arc -target "${SCREENEDGE_ARCH:-arm64}-apple-macosx13.0" -c Sources/UCBridge.m -o .build/UCBridge.o
xcrun swiftc -import-objc-header Sources/UCBridge.h -swift-version 5 -O -target "${SCREENEDGE_ARCH:-arm64}-apple-macosx13.0" -module-cache-path "$PWD/.build/module-cache" Sources/*.swift .build/UCBridge.o -o "$APP/Contents/MacOS/ScreenEdge" -framework AppKit -framework SwiftUI -framework ServiceManagement
xcrun swift -module-cache-path "$PWD/.build/module-cache" scripts/Icon.swift .build/AppIcon.iconset "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ScreenEdge</string>
<key>CFBundleIdentifier</key><string>local.screenedge.app</string>
<key>CFBundleName</key><string>跨屏边缘</string>
<key>CFBundleDisplayName</key><string>跨屏边缘</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>1.3.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
<key>NSHumanReadableCopyright</key><string>© 2026 ScreenEdge contributors</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s/%s\n' "$PWD" "$APP"
