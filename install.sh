#!/bin/bash
# Build and install CopyPath to /Applications.
#
# CopyPath provides a "Copy Path" item under the Finder right-click menu's
# Services submenu. The app must be launched at least once so macOS registers
# the Service; after that it stays running in the background.
set -e

cd "$(dirname "$0")"

echo "→ Building..."
xcodegen generate > /dev/null
xcodebuild -project CopyPath.xcodeproj -scheme CopyPath -configuration Release -derivedDataPath build clean build > /dev/null

DEST="/Applications/CopyPath.app"

echo "→ Installing to ${DEST}..."
rm -rf "${DEST}"
cp -R build/Build/Products/Release/CopyPath.app "${DEST}"

echo "→ Removing quarantine flag..."
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

echo "→ Registering with LaunchServices..."
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$LSREG" -f -R -trusted "${DEST}"

echo "→ Restarting pbs + Finder so the Services menu refreshes..."
killall pbs 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "→ Launching CopyPath..."
open "${DEST}"

echo ""
echo "Done. Right-click a file in Finder → Services → Copy Path."
