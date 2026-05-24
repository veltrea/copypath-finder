#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "→ Building..."
xcodegen generate > /dev/null
xcodebuild -project CopyPath.xcodeproj -scheme CopyPath -configuration Release -derivedDataPath build clean build > /dev/null

echo "→ Installing to ~/Applications..."
mkdir -p ~/Applications
rm -rf ~/Applications/CopyPath.app
cp -R build/Build/Products/Release/CopyPath.app ~/Applications/

echo "→ Registering with LaunchServices..."
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$LSREG" -f -R -trusted ~/Applications/CopyPath.app

echo "→ Enabling extension..."
pluginkit -e use -i com.copypath.app.extension

echo "→ Restarting Finder..."
killall Finder 2>/dev/null || true

echo ""
echo "Done. Right-click a file or folder in Finder to see 'Copy Path'."
