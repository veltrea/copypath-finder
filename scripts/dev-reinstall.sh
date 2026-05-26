#!/bin/bash
# Fully reset CopyPath state and reinstall the current local build for testing.
#
# Usage:
#   ./scripts/dev-reinstall.sh         # Reuse existing build/, install, launch
#   ./scripts/dev-reinstall.sh --build # Rebuild from source first
#   ./scripts/dev-reinstall.sh --no-launch  # Install but don't open the app
#
# Solves: "I dragged a new build to /Applications but it still acts like the old
# binary." The Finder Sync extension runs as its own process and outlives the
# main app, so a plain copy-and-relaunch keeps the old code in memory. This
# script force-kills every CopyPath-related process, wipes state, copies the
# fresh build, and relaunches.

set -e
cd "$(dirname "$0")/.."

BUNDLE_ID="com.copypath.app"
APP_NAME="CopyPath.app"
BUILT_APP="build/Build/Products/Release/${APP_NAME}"
INSTALL_DEST="/Applications/${APP_NAME}"
# Legacy extension bundle id from before we switched to NSServices. Kept here
# so the cleanup step can scrub leftover state from older installs.
LEGACY_EXT_ID="com.copypath.app.extension"

BUILD=0
LAUNCH=1
for arg in "$@"; do
    case "$arg" in
        --build)     BUILD=1 ;;
        --no-launch) LAUNCH=0 ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown arg: $arg" >&2
            exit 1
            ;;
    esac
done

if [ ! -d "$BUILT_APP" ]; then
    echo "→ No build found, building..."
    BUILD=1
fi

if [ "$BUILD" = "1" ]; then
    echo "→ Building (Release)..."
    xcodegen generate > /dev/null
    xcodebuild -project CopyPath.xcodeproj -scheme CopyPath \
               -configuration Release -derivedDataPath build clean build > /dev/null
fi

echo "→ Killing every CopyPath process..."
pkill -9 -f "/CopyPath\.app/" 2>/dev/null || true
pkill -9 -x "CopyPath" 2>/dev/null || true
pkill -9 -x "CopyPathExtension" 2>/dev/null || true
sleep 1

echo "→ Scrubbing any leftover FinderSync extension registration (legacy)..."
pluginkit -e ignore -i "$LEGACY_EXT_ID" 2>/dev/null || true
for appex in \
    "/Applications/${APP_NAME}/Contents/PlugIns/CopyPathExtension.appex" \
    "${HOME}/Applications/${APP_NAME}/Contents/PlugIns/CopyPathExtension.appex"; do
    [ -d "$appex" ] && pluginkit -r "$appex" 2>/dev/null || true
done

echo "→ Removing existing install..."
rm -rf "/Applications/${APP_NAME}" "${HOME}/Applications/${APP_NAME}"

echo "→ Clearing UserDefaults (so first-launch bootstrap runs again)..."
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo "→ Restarting pbs + Finder so the Services menu rebuilds..."
killall pbs 2>/dev/null || true
killall Finder 2>/dev/null || true
sleep 1

echo "→ Copying fresh build to ${INSTALL_DEST}..."
cp -R "$BUILT_APP" "$INSTALL_DEST"
# Belt-and-suspenders: drop any quarantine bit that might be on the copied tree
xattr -dr com.apple.quarantine "$INSTALL_DEST" 2>/dev/null || true

if [ "$LAUNCH" = "1" ]; then
    echo "→ Launching..."
    open "$INSTALL_DEST"
    sleep 2
fi

echo ""
echo "=== After ==="
echo "Processes:"
pgrep -fl CopyPath || echo "  (none)"
echo ""
# Print the build stamps so the user can match them against what the running
# app shows in its window title bar. If these match, the app on screen is
# actually the binary we just built.
BUILT_STAMP=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${BUILT_APP}/Contents/MacOS/CopyPath" 2>/dev/null || echo "?")
INSTALLED_STAMP=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${INSTALL_DEST}/Contents/MacOS/CopyPath" 2>/dev/null || echo "?")
BUILT_HASH=$(shasum "${BUILT_APP}/Contents/MacOS/CopyPath" 2>/dev/null | awk '{print substr($1,1,12)}')
INSTALLED_HASH=$(shasum "${INSTALL_DEST}/Contents/MacOS/CopyPath" 2>/dev/null | awk '{print substr($1,1,12)}')
echo "Build verification:"
echo "  built     : ${BUILT_STAMP}   sha=${BUILT_HASH}"
echo "  installed : ${INSTALLED_STAMP}   sha=${INSTALLED_HASH}"
if [ "$BUILT_HASH" = "$INSTALLED_HASH" ] && [ -n "$BUILT_HASH" ]; then
    echo "  → hashes match. The window title should say 'build ${INSTALLED_STAMP}'."
else
    echo "  → MISMATCH. The installed binary is not the one we just built."
fi
