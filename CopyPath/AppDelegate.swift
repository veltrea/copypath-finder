import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    /// Flag tracking whether we've already done the one-shot install bootstrap
    /// (LaunchServices registration + Services registry refresh). Kept under
    /// the legacy "...Extension" key so users upgrading from an earlier build
    /// don't unnecessarily re-run the bootstrap.
    private let didAutoEnableKey = "CopyPath.didAutoEnableExtension"

    /// Set true if the Services entry was invoked while we were starting
    /// up — in that case the user wanted the path copied, not the setup
    /// window opened, so we suppress the auto-shown window.
    private var serviceInvokedDuringLaunch = false
    private var windowShowWorkItem: DispatchWorkItem?

    // Explicit entry point. Without this, `@main` synthesizes a main() that
    // calls NSApplicationMain but never instantiates this class as the
    // app delegate (because there's no XIB/NIB to do it for us). As a result
    // none of the NSApplicationDelegate methods fire — no menu, no window,
    // no auto-enable. Setting the delegate manually here is required.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    private let logPath = "/tmp/copypath-bootstrap.log"

    private func diag(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
        NSLog("CopyPath[bootstrap]: %@", msg)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always reset the log on launch so the latest run is easy to find.
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)
        diag("applicationDidFinishLaunching START")

        installMainMenu()

        // Register as the provider for the "Copy Path" Service. macOS calls
        // copyPath(_:userData:error:) below whenever the user picks the
        // service from the Finder right-click menu (Services submenu).
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        diag("registered as services provider")

        // First-launch bootstrap: tell LaunchServices about this bundle so
        // the Service we just declared in Info.plist appears in the menu
        // immediately, then refresh the system service registry.
        let alreadyDone = UserDefaults.standard.bool(forKey: didAutoEnableKey)
        diag("didAutoEnable already set? \(alreadyDone)")
        if !alreadyDone {
            registerAndEnableExtension()
            UserDefaults.standard.set(true, forKey: didAutoEnableKey)
            UserDefaults.standard.synchronize()
        }

        // Defer showing the setup window briefly. If macOS launched us to
        // handle a Service invocation, the copyPath(_:userData:error:)
        // selector below will run within a few milliseconds of launch and
        // mark serviceInvokedDuringLaunch=true. In that case we skip the
        // window entirely — the user wanted a path on their clipboard,
        // not a setup dialog.
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.serviceInvokedDuringLaunch {
                self.diag("suppressing window (service was invoked during launch)")
            } else {
                self.showMainWindow()
                self.diag("showMainWindow DONE")
            }
        }
        windowShowWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay running after the setup window is closed so the Service we
        // registered remains live without macOS having to relaunch us each
        // time the user picks it from the right-click menu (which is what
        // caused the window to keep popping up).
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // User clicked our Dock icon and we have no window open — re-show
        // the setup window. Returning true is the standard convention.
        if !flag {
            showMainWindow()
        }
        return true
    }

    /// Services entry point. Wired up via the `NSMessage` key in Info.plist.
    /// Signature is fixed by AppKit: it must be `@objc` with this exact
    /// selector so macOS can invoke it.
    @objc func copyPath(_ pboard: NSPasteboard,
                        userData: String?,
                        error errorPtr: AutoreleasingUnsafeMutablePointer<NSString>) {
        diag("copyPath service invoked")

        // Mark the launch as a service invocation so the deferred window
        // show in applicationDidFinishLaunching skips itself. Also cancel
        // the pending work item directly in case its fire time hasn't
        // arrived yet.
        serviceInvokedDuringLaunch = true
        windowShowWorkItem?.cancel()

        var paths: [String] = []

        // Prefer file URLs (modern API).
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            paths = urls.map { $0.path }
        }
        // Fall back to the legacy filenames pasteboard type.
        if paths.isEmpty,
           let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            paths = filenames
        }

        guard !paths.isEmpty else {
            errorPtr.pointee = "No file selected" as NSString
            NSSound.beep()
            return
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(paths.joined(separator: "\n"), forType: .string)
        diag("copied \(paths.count) path(s) to clipboard")
    }

    private func installMainMenu() {
        let appName = ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()

        // Application menu (the first menu item is always the app menu on macOS).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            withTitle: String(format: NSLocalizedString("menu.about", comment: ""), appName),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(
            withTitle: String(format: NSLocalizedString("menu.hide", comment: ""), appName),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        let hideOthers = appMenu.addItem(
            withTitle: NSLocalizedString("menu.hideOthers", comment: ""),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        appMenu.addItem(
            withTitle: NSLocalizedString("menu.showAll", comment: ""),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(
            withTitle: String(format: NSLocalizedString("menu.quit", comment: ""), appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Window menu so Cmd-W close / minimize behave normally.
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: NSLocalizedString("menu.window", comment: ""))
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            withTitle: NSLocalizedString("menu.minimize", comment: ""),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: NSLocalizedString("menu.close", comment: ""),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func registerAndEnableExtension() {
        // Now that we provide the Finder right-click integration through
        // NSServices (declared in Info.plist) instead of a FinderSync
        // extension, the bootstrap only needs to:
        //   1. Tell LaunchServices about this bundle so its NSServices
        //      declaration is picked up.
        //   2. Ask the system to refresh the dynamic Services registry so
        //      "Copy Path" appears in the Services submenu immediately.
        //   3. Restart Finder so the Services menu it has cached is rebuilt.
        let bundlePath = Bundle.main.bundleURL.path
        diag("registering bundle: \(bundlePath)")

        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        let r1 = runProcess(lsregister, ["-f", "-R", "-trusted", bundlePath])
        diag("lsregister exit=\(r1)")

        NSUpdateDynamicServices()
        diag("NSUpdateDynamicServices called")

        // pbs (pasteboard server) caches the Services menu. Without
        // restarting it, freshly registered localized strings (e.g.
        // ServicesMenu.strings for ja) don't appear in the Finder menu —
        // the default English text keeps showing instead. pbs respawns
        // automatically when next needed.
        let r2 = runProcess("/usr/bin/killall", ["pbs"])
        diag("killall pbs exit=\(r2)")

        let r3 = runProcess("/usr/bin/killall", ["Finder"])
        diag("killall Finder exit=\(r3)")
    }

    @discardableResult
    private func runProcess(_ launchPath: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            NSLog("CopyPath[bootstrap]: failed to run %@: %@", launchPath, "\(error)")
            return -1
        }
    }

    /// Returns the modification time of the running binary as a short string,
    /// so we can prove "is the version I'm looking at really the latest build?"
    /// just by glancing at the window's title bar.
    private func buildStamp() -> String {
        guard let path = Bundle.main.executablePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date else {
            return "unknown"
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func showMainWindow() {
        let rect = NSRect(x: 0, y: 0, width: 520, height: 360)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(NSLocalizedString("app.windowTitle", comment: "")) — build \(buildStamp())"
        window.center()

        let view = NSView(frame: rect)

        let titleLabel = NSTextField(labelWithString: "CopyPath")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 300, width: 480, height: 36)
        view.addSubview(titleLabel)

        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("app.instructions", comment: ""))
        label.frame = NSRect(x: 20, y: 90, width: 480, height: 200)
        label.font = .systemFont(ofSize: 13)
        view.addSubview(label)

        let button = NSButton(
            title: NSLocalizedString("app.openSettings", comment: ""),
            target: self,
            action: #selector(openSettings)
        )
        button.frame = NSRect(x: 180, y: 30, width: 160, height: 32)
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        view.addSubview(button)

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        // Open the keyboard shortcuts pane so the user can assign a hotkey
        // to the Copy Path service. (The old FinderSync flow used to open
        // Extensions preferences, which is no longer relevant.)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")!
        NSWorkspace.shared.open(url)
    }
}
