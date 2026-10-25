#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
: "${OFFICE_ENGINE_APP:?Set OFFICE_ENGINE_APP to the absolute path of a complete LibreOffice.app}"
[[ -x "$OFFICE_ENGINE_APP/Contents/MacOS/soffice" ]] || { print -u2 'LibreOffice executable not found'; exit 1; }
APP='dist/FormatFlow.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
swiftc -module-cache-path "${TMPDIR:-/tmp}/formatflow-module-cache" -target arm64-apple-macosx13.0 main.swift -o "$APP/Contents/MacOS/FormatFlow" -framework Cocoa -framework PDFKit -framework ImageIO -framework AVFoundation -O
ditto "$OFFICE_ENGINE_APP" "$APP/Contents/Resources/OfficeEngine.app"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
[[ -e dist/Applications ]] || ln -s /Applications dist/Applications
cp 使用说明.md dist/使用说明.md
hdiutil create -volname 'FormatFlow 格式工坊 1.1' -srcfolder dist -ov -format UDZO FormatFlow-1.1.dmg
