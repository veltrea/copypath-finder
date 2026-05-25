#!/bin/bash
# Double-clickable installer for CopyPath.dmg contents.
set -e

cd "$(dirname "$0")"

echo "→ Installing CopyPath.app to ~/Applications..."
mkdir -p ~/Applications
rm -rf ~/Applications/CopyPath.app
cp -R CopyPath.app ~/Applications/

echo "→ Removing quarantine flag..."
xattr -dr com.apple.quarantine ~/Applications/CopyPath.app 2>/dev/null || true

echo "→ Registering with LaunchServices..."
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$LSREG" -f -R -trusted ~/Applications/CopyPath.app

echo "→ Enabling Finder extension..."
pluginkit -e use -i com.copypath.app.extension

echo "→ Restarting Finder..."
killall Finder 2>/dev/null || true

echo ""
echo "Done. Right-click a file or folder in Finder to see 'Copy Path'."
echo ""
echo "Press Return to close this window."
read -r
