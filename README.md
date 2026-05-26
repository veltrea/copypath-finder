# CopyPath

A minimal macOS utility that adds a **Copy Path** entry under the Finder right-click menu's **Services** submenu.

[日本語版 README はこちら](README.ja.md)

## Why

macOS already lets you copy a file's path — but only by holding the Option key while right-clicking. That requires two-handed operation and is not discoverable.

CopyPath registers a Service so that right-clicking any file in Finder, hovering over **Services**, and clicking **Copy Path** puts the POSIX path on the clipboard. One click, no modifier keys.

## Why Services and not a top-level item?

The initial version of this app used a `FIFinderSync` extension to add the item at the top of the right-click menu. That turned out to be the wrong tool for the job: per Apple's Developer Technical Support, `FIFinderSync` was designed for cloud-sync providers and was [never intended](https://developer.apple.com/forums/thread/766680) to add context menu items to arbitrary files. It happened to fire for some folders in older macOS versions, but on Sequoia it stops firing for general user files. Successful third-party "Copy Path" type apps (Hookmark, PathFinder) all use Services for this reason.

The Services API is the supported path on modern macOS. The trade-off is that the menu item lives under the **Services** submenu instead of at the top level — Apple does not allow third-party apps to inject top-level context menu items.

## Features

- Works on any file or folder via the Services submenu
- Single click — no modifier keys
- Single selection: copies that file's POSIX path
- Multiple selection: joins paths with newlines
- Localized in English and Japanese (`Copy Path` / `パスをコピー`)
- After first launch the app stays resident so Service invocations don't keep relaunching it (and don't keep re-opening the setup window)

## Install

```bash
./install.sh
```

Builds the app, installs it to `/Applications/CopyPath.app`, registers the bundle with LaunchServices, restarts `pbs` and Finder so the Services menu picks up the new entry (Finder restart alone is not enough — `pbs` caches the menu), and launches the app once so its bootstrap completes.

Alternatively, drag `CopyPath.app` from the DMG to `/Applications` and launch it once.

## Usage

1. Right-click a file or folder in Finder
2. Hover over **サービス** / **Services**
3. Click **パスをコピー** / **Copy Path**

To put it on a keyboard shortcut: **System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders → Copy Path**. The window's button opens this pane directly.

## Requirements

- macOS 13.0+
- Xcode 16+
- [xcodegen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`)

## How it works

- **Service declaration.** `Info.plist` contains an `NSServices` entry with the `copyPath:` message and the `public.file-url` / `NSFilenamesPboardType` send types. Localized titles live in `Base.lproj/ServicesMenu.strings` and `ja.lproj/ServicesMenu.strings`.
- **Service handler.** On launch the app registers itself as the services provider (`NSApp.servicesProvider = self`). The handler reads URLs from the incoming pasteboard and writes the joined paths to `NSPasteboard.general`.
- **Explicit main().** AppDelegate defines a `static func main()` that creates the delegate and calls `NSApp.run()`. Without this, `@main` alone synthesizes a `main()` that calls `NSApplicationMain` but never installs an `NSApplicationDelegate` instance (there's no XIB to do it). The result is `applicationDidFinishLaunching` never fires and nothing works.
- **First-launch bootstrap.** Runs `lsregister -f -R -trusted <bundle>` to register the app, `NSUpdateDynamicServices()` to refresh the registry, then `killall pbs && killall Finder` so the Services menu is rebuilt with the freshly registered (and localized) entry. Guarded by a `UserDefaults` flag so it only runs once.
- **Stays running.** `applicationShouldTerminateAfterLastWindowClosed` returns `false`, so closing the setup window doesn't quit the app. The Service stays available without macOS having to relaunch the app each time.
- **No popup on Service invocation.** The setup window is shown via a deferred (~400 ms) `DispatchWorkItem`. If `copyPath(_:userData:error:)` runs first — which is exactly what happens when macOS cold-starts the app to handle a Service call — it cancels the pending work item, so the window never appears.

## Development

```bash
./scripts/dev-reinstall.sh --build
```

Force-kills any running CopyPath process (including stale ones from previous builds), scrubs leftover state (including any legacy FinderSync extension registration), rebuilds, reinstalls to `/Applications`, restarts `pbs` and Finder, and relaunches the app. Prints the built / installed binary timestamps and SHA so you can confirm the running window-title build stamp matches the artifact you just built.

## License

MIT — see [LICENSE](LICENSE).
