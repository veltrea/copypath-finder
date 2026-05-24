import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 520, height: 360)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("app.windowTitle", comment: "")
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
        let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
        NSWorkspace.shared.open(url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
