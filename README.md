# CopyPath

A minimal macOS Finder Sync extension that adds a top-level **Copy Path** item to the Finder right-click context menu.

[日本語版 README はこちら](README.ja.md)

## Why

macOS already lets you copy a file's path — but only by holding the Option key while right-clicking. That requires two-handed operation and is not discoverable.

CopyPath adds a single, always-visible **Copy Path** item to the top of the context menu, copyable with one click.

## Features

- Top-level menu item (not buried in a "Quick Actions" submenu)
- Single click — no modifier keys
- Single selection: copies that file's POSIX path
- Multiple selection: joins paths with newlines
- Right-click on empty Finder area: copies the current folder path
- Localized in English and Japanese

## Install

```bash
./install.sh
```

This builds, installs to `~/Applications/CopyPath.app`, registers the extension, enables it, and restarts Finder. After it finishes, right-click any file or folder.

If the menu item does not appear, open `~/Applications/CopyPath.app` and follow the on-screen instructions to enable the extension in System Settings.

## Requirements

- macOS 13.0+
- Xcode 16+
- [xcodegen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`)

## Why not just use an existing app?

There are commercial equivalents (PowerClick, Hookmark) that work fine. CopyPath exists for people who want:

- Source they can read in 30 lines of Swift
- No App Store dependency or paid license
- Freedom to add custom path formats (URL-encoded, quoted, escaped) later

## How it works

A `FIFinderSync` subclass returns a single `NSMenuItem` from `menu(for:)`. On click, it reads `selectedItemURLs()` (or `targetedURL()` for empty-area clicks) and writes joined paths to `NSPasteboard`.

The host app is required by macOS to package the extension — it only serves as a container and shows an instruction window when launched.

## License

MIT — see [LICENSE](LICENSE).
