# CopyPath

A minimal macOS utility that adds a **Copy Path** entry to the Finder right-click menu's **Services** submenu.

[日本語版 README はこちら](README.ja.md)

## Why

macOS already lets you copy a file's path — but only by holding the Option key while right-clicking. That requires two-handed operation and is not discoverable.

CopyPath registers a Service so that right-clicking any file in Finder, hovering over **Services**, and clicking **Copy Path** puts the POSIX path on the clipboard. One click, no modifier keys.

## Why Services and not a top-level item?

Earlier versions of this app used a `FIFinderSync` extension to put the item at the top of the right-click menu. That stopped working on macOS Sequoia (15.x) — per Apple's Developer Technical Support, FinderSync was never designed for adding context menu items to arbitrary files, and the right-click integration is unreliable in Sequoia.

The Services API is the supported path on modern macOS. Items appear under the Services submenu, which is the same place commercial alternatives like Hookmark and PathFinder put their integrations.

## Features

- Works on any file or folder via the Services submenu
- Single click — no modifier keys
- Single selection: copies that file's POSIX path
- Multiple selection: joins paths with newlines
- Localized in English and Japanese
- Background-only operation: the app stays running after first launch so the Service responds without launching the UI each time

## Install

```bash
./install.sh
```

This builds, installs to `/Applications/CopyPath.app`, registers the bundle with LaunchServices, restarts Finder, and launches the app once so its Service registers.

Or just drag the `CopyPath.app` from the DMG to `/Applications` and launch it once.

## Usage

1. Right-click a file or folder in Finder
2. Hover over **Services**
3. Click **Copy Path**

To put it on a keyboard shortcut: **System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders → Copy Path**.

## Requirements

- macOS 13.0+
- Xcode 16+
- [xcodegen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`)

## How it works

The main app declares an `NSServices` entry in its `Info.plist` and registers itself as the service provider on launch. The Service handler reads the file URLs from the system pasteboard and writes the joined paths to `NSPasteboard.general`.

The app's setup window auto-hides when a Service invocation is detected during launch, so picking the menu item never opens a window.

## Development

```bash
./scripts/dev-reinstall.sh --build
```

Kills any running CopyPath process (including stale ones from previous builds), wipes install state, rebuilds, reinstalls to `/Applications`, and relaunches. Prints the binary timestamp so you can verify the running window matches the build you just made.

## License

MIT — see [LICENSE](LICENSE).
