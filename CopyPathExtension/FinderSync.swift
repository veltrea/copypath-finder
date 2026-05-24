import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")

        let item = NSMenuItem(
            title: NSLocalizedString("menu.copyPath", bundle: Bundle(for: type(of: self)), comment: ""),
            action: #selector(copyPath(_:)),
            keyEquivalent: ""
        )
        item.target = self
        if let base = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
            let colored = base.withSymbolConfiguration(config) ?? base
            colored.isTemplate = false
            item.image = colored
        }
        menu.addItem(item)

        return menu
    }

    @objc func copyPath(_ sender: AnyObject?) {
        let controller = FIFinderSyncController.default()
        var paths: [String] = []

        if let urls = controller.selectedItemURLs(), !urls.isEmpty {
            paths = urls.map { $0.path }
        } else if let target = controller.targetedURL() {
            paths = [target.path]
        }

        guard !paths.isEmpty else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }
}
