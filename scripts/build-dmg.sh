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
ln -s /Applications "$STAGING/Applications"

cat > "$STAGING/README.txt" <<'EOF'
CopyPath - "Copy Path" item in the Finder right-click Services submenu

Install:
  1. Drag "CopyPath" onto the "Applications" folder shortcut.
  2. Open CopyPath from Applications once.
     If macOS warns about an unidentified developer, open
     System Settings > Privacy & Security and click "Open Anyway",
     then launch CopyPath again.
     You can close the window after it appears - CopyPath keeps
     running in the background so the Service stays available.

Usage:
  Right-click any file in Finder -> Services -> Copy Path.
  The POSIX path is copied to your clipboard.

  To put it on a keyboard shortcut:
    System Settings > Keyboard > Keyboard Shortcuts > Services
    > Files and Folders > Copy Path

Uninstall:
  Quit CopyPath from the Dock, then:
    rm -rf /Applications/CopyPath.app

----------------------------------------------------------------

CopyPath - Finder 右クリック「サービス」サブメニューに「パスをコピー」を追加

インストール手順:
  1. 「CopyPath」を「Applications」フォルダのショートカットに
     ドラッグ&ドロップします。
  2. Applications から CopyPath を 1 回開きます。
     macOS が「開発元が未確認」と警告した場合は、システム設定 >
     プライバシーとセキュリティ で「このまま開く」をクリックして
     から、もう一度 CopyPath を起動してください。
     ウィンドウは閉じて構いません。CopyPath はバックグラウンドで
     動き続けるのでサービスは引き続き使えます。

使い方:
  Finder でファイルを右クリック →「サービス」→「パスをコピー」。
  POSIX パスがクリップボードに入ります。

  キーボードショートカットを割り当てる場合:
    システム設定 > キーボード > キーボードショートカット >
    サービス > ファイルとフォルダ > パスをコピー

アンインストール:
  Dock から CopyPath を終了した後:
    rm -rf /Applications/CopyPath.app
EOF

echo "→ Creating $DMG_NAME..."
rm -f "build/$DMG_NAME"
hdiutil create -volname "CopyPath ${VERSION}" -srcfolder "$STAGING" -ov -format UDZO "build/$DMG_NAME" > /dev/null

echo ""
echo "✓ build/$DMG_NAME ($(du -h "build/$DMG_NAME" | cut -f1))"
