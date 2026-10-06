import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = Controller()
    private var statusItem: NSStatusItem!
    private var panels: [PanelKind: WebPanel] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.start()

        for kind in PanelKind.allCases {
            panels[kind] = WebPanel(kind: kind, controller: controller)
        }
        for (kind, panel) in panels where controller.panel(kind).visible {
            panel.orderFront(nil)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(named: "MenuIcon")
        statusItem.button?.image?.accessibilityDescription = "Sprig"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.allNotesOff()
        controller.save()
    }

    // MARK: - Menu bar

    func menuWillOpen(_ menu: NSMenu) {
        for panel in panels.values where panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for kind in PanelKind.allCases {
            let item = addItem(to: menu, kind.rawValue.capitalized, #selector(togglePanel(_:)), object: kind.rawValue)
            item.state = panels[kind]?.isVisible == true ? .on : .off
        }
        menu.addItem(.separator())

        let state = controller.state
        let outputs = NSMenu()
        addItem(to: outputs, "None", #selector(selectOutput(_:)), object: "").state = state.outputID.isEmpty ? .on : .off
        outputs.addItem(.separator())
        for port in controller.midi.outputs {
            addItem(to: outputs, port.name, #selector(selectOutput(_:)), object: port.id).state = port.id == state.outputID ? .on : .off
        }
        menu.addItem(withTitle: "MIDI Output", action: nil, keyEquivalent: "").submenu = outputs
        let channels = NSMenu()
        for channel in 1...16 {
            let item = addItem(to: channels, "Channel \(channel)", #selector(selectChannel(_:)), object: channel)
            item.state = channel == state.channel ? .on : .off
        }
        menu.addItem(withTitle: "MIDI Channel", action: nil, keyEquivalent: "").submenu = channels
        menu.addItem(.separator())

        let themes = NSMenu()
        for (title, theme) in [("System", "system"), ("Dark", "dark"), ("Light", "light")] {
            let item = addItem(to: themes, title, #selector(selectTheme(_:)), object: theme)
            item.state = theme == state.theme ? .on : .off
        }
        menu.addItem(withTitle: "Theme", action: nil, keyEquivalent: "").submenu = themes
        addItem(to: menu, "All Notes Off", #selector(allNotesOff), object: nil)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Sprig", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, object: Any?) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = object
        return item
    }

    @objc private func togglePanel(_ sender: NSMenuItem) {
        let panel = panels[PanelKind(rawValue: sender.representedObject as! String)!]!
        if panel.isVisible {
            panel.hide()
        } else {
            panel.show()
        }
    }

    @objc private func selectOutput(_ sender: NSMenuItem) {
        controller.selectOutput(sender.representedObject as! String)
    }

    @objc private func selectChannel(_ sender: NSMenuItem) {
        controller.selectChannel(sender.representedObject as! Int)
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        controller.setTheme(sender.representedObject as! String)
    }

    @objc private func allNotesOff() {
        controller.allNotesOff()
    }
}
