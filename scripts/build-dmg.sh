#!/bin/bash
# Build CopyPath.app and package it into a DMG for distribution.
set -e

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
DMG_NAME="CopyPath-${VERSION}.dmg"
STAGING="build/dmg-staging"

echo "→ Building app..."
xcodegen generate > /dev/null
xcodebuild -project CopyPath.xcodeproj -scheme CopyPath -configuration Release -derivedDataPath build clean build > /dev/null

echo "→ Staging DMG contents..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R build/Build/Products/Release/CopyPath.app "$STAGING/"
cp scripts/install.command "$STAGING/install.command"
chmod +x "$STAGING/install.command"

cat > "$STAGING/README.txt" <<'EOF'
CopyPath - "Copy Path" item for Finder right-click menu

How to install:
  Double-click "install.command".
  (If macOS warns about an unsigned developer, allow it in System
  Settings > Privacy & Security, then double-click again.)

After it finishes, right-click any file or folder in Finder
to see "Copy Path" at the top level of the menu.

How to uninstall:
  rm -rf ~/Applications/CopyPath.app
  pluginkit -r ~/Applications/CopyPath.app/Contents/PlugIns/CopyPathExtension.appex 2>/dev/null || true

----------------------------------------------------------------

CopyPath - Finder の右クリックメニューに「パスをコピー」を追加

インストール手順:
  「install.command」をダブルクリック。
  （macOS が「開発元が未確認」と警告した場合は、システム設定 >
  プライバシーとセキュリティ で許可してから再度ダブルクリック）

完了後、Finder でファイルやフォルダを右クリックすると、メニュー
上部に「パスをコピー」が表示されます。

アンインストール:
  rm -rf ~/Applications/CopyPath.app
  pluginkit -r ~/Applications/CopyPath.app/Contents/PlugIns/CopyPathExtension.appex 2>/dev/null || true
EOF

echo "→ Creating $DMG_NAME..."
rm -f "build/$DMG_NAME"
hdiutil create -volname "CopyPath ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "build/$DMG_NAME" > /dev/null

echo ""
echo "✓ build/$DMG_NAME ($(du -h "build/$DMG_NAME" | cut -f1))"
