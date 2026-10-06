import AppKit

enum PanelKind: String, CaseIterable {
    case keyboard
    case knobs
    case sliders

    var page: String {
        self == .knobs || self == .sliders ? "controls" : rawValue
    }

    var defaultSize: NSSize {
        self == .keyboard ? NSSize(width: 362, height: 120) : NSSize(width: 600, height: 260)
    }
}

struct ControlSpec: Codable {
    var label: String
    var cc: Int
}

struct PanelState: Codable {
    var visible = false
    var pinned = false
    var frame: String?
    var columns = 8
    var zoom = 1.0
}

struct AppState: Codable {
    static let maxColumns = 16

    var outputID = ""
    var channel = 1
    var theme = "system"
    var keyboardRoot = 36
    var keyboardCount = 25
    var knobs = (0..<maxColumns).map { ControlSpec(label: "K\($0 + 1)", cc: 21 + $0) }
    var sliders = (0..<maxColumns).map { ControlSpec(label: "S\($0 + 1)", cc: 41 + $0) }
    var values: [String: Int] = [:]
    var panels = [PanelKind.keyboard.rawValue: PanelState(visible: true)]
}

final class Controller: NSObject {
    private static let stateKey = "state"
    private static let noteVelocity: UInt8 = 100

    private(set) var state: AppState
    let midi = MIDIManager()
    private var observers: [([String: Any]) -> Void] = []
    private var pendingSave: DispatchWorkItem?

    override init() {
        state = Self.load() ?? AppState()
        super.init()
    }

    private static func load() -> AppState? {
        guard
            let data = UserDefaults.standard.data(forKey: stateKey),
            let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let defaults = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(AppState())) as? [String: Any],
            let merged = try? JSONSerialization.data(withJSONObject: defaults.merging(saved) { $1 })
        else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: merged)
    }

    func start() {
        midi.onDevicesChanged = { [weak self] in self?.devicesChanged() }
        midi.start()
        devicesChanged()
    }

    func observe(_ observer: @escaping ([String: Any]) -> Void) {
        observers.append(observer)
    }

    // MARK: - Pages

    func handle(_ body: [String: Any]) {
        switch body["type"] as? String {
        case "note":
            guard let note = (body["note"] as? NSNumber)?.intValue, (0...127).contains(note) else { return }
            let on = (body["on"] as? Bool) ?? false
            send([(on ? 0x90 : 0x80) | channelNibble, UInt8(note), on ? Self.noteVelocity : 0])
        case "cc":
            guard
                let id = body["id"] as? String,
                let spec = spec(for: id),
                let value = (body["value"] as? NSNumber)?.intValue
            else { return }
            let clamped = min(127, max(0, value))
            send([0xB0 | channelNibble, UInt8(spec.cc), UInt8(clamped)])
            state.values[id] = clamped
            scheduleSave()
        case "keyboardRange":
            guard
                let root = (body["root"] as? NSNumber)?.intValue,
                let count = (body["count"] as? NSNumber)?.intValue
            else { return }
            state.keyboardRoot = root
            state.keyboardCount = count
            scheduleSave()
        default:
            break
        }
    }

    func panel(_ kind: PanelKind) -> PanelState {
        state.panels[kind.rawValue] ?? PanelState()
    }

    func updatePanel(_ kind: PanelKind, _ change: (inout PanelState) -> Void) {
        change(&state.panels[kind.rawValue, default: PanelState()])
        scheduleSave()
    }

    // MARK: - Menu bar

    func selectOutput(_ id: String) {
        allNotesOff()
        state.outputID = id
        save()
        publishState()
    }

    func selectChannel(_ channel: Int) {
        allNotesOff()
        state.channel = channel
        save()
        publishState()
    }

    func setTheme(_ theme: String) {
        state.theme = theme
        save()
        publishState()
    }

    func allNotesOff() {
        for channel in 0..<16 {
            send([0xB0 | UInt8(channel), 123, 0])
        }
    }

    // MARK: - Control context menu

    func showMenu(forControl id: String, in view: NSView) {
        guard let spec = spec(for: id) else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false
        let kind = id.hasPrefix("k") ? "Knob" : "Slider"
        let title = menu.addItem(withTitle: "\(kind) \(spec.label) · CC \(spec.cc)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(.separator())

        let ccItem = menu.addItem(withTitle: "CC", action: nil, keyEquivalent: "")
        let ccMenu = NSMenu()
        for cc in 0...127 {
            let item = ccMenu.addItem(withTitle: "CC \(cc)", action: #selector(chooseCC(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.tag = cc
            item.state = cc == spec.cc ? .on : .off
        }
        ccItem.submenu = ccMenu

        let rename = menu.addItem(withTitle: "Rename…", action: #selector(rename(_:)), keyEquivalent: "")
        rename.target = self
        rename.representedObject = id

        let point = view.convert(view.window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        menu.popUp(positioning: nil, at: point, in: view)
    }

    @objc private func chooseCC(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        updateSpec(id) { $0.cc = sender.tag }
    }

    @objc private func rename(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let spec = spec(for: id) else { return }

        let alert = NSAlert()
        alert.messageText = "Rename \(spec.label)"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: spec.label)
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let label = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        updateSpec(id) { $0.label = label }
    }

    // MARK: - State

    private var channelNibble: UInt8 { UInt8(state.channel - 1) }

    private func specPath(_ id: String) -> WritableKeyPath<AppState, ControlSpec>? {
        guard let index = Int(id.dropFirst()), (0..<AppState.maxColumns).contains(index) else { return nil }
        switch id.first {
        case "k": return \.knobs[index]
        case "s": return \.sliders[index]
        default: return nil
        }
    }

    private func spec(for id: String) -> ControlSpec? {
        specPath(id).map { state[keyPath: $0] }
    }

    private func updateSpec(_ id: String, _ change: (inout ControlSpec) -> Void) {
        guard let path = specPath(id) else { return }
        change(&state[keyPath: path])
        save()
        publishState()
    }

    func publishState() {
        let outputName = midi.outputs.first { $0.id == state.outputID }?.name ?? "no output"
        let controls: (String, [ControlSpec]) -> [[String: Any]] = { prefix, specs in
            specs.indices.map { index in
                let id = "\(prefix)\(index)"
                return [
                    "id": id,
                    "label": specs[index].label,
                    "cc": specs[index].cc,
                    "value": self.state.values[id] ?? 0,
                ]
            }
        }
        broadcast([
            "type": "state",
            "theme": state.theme,
            "channel": state.channel,
            "outputName": outputName,
            "panels": Dictionary(uniqueKeysWithValues: PanelKind.allCases.map { kind in
                let panel = panel(kind)
                return (kind.rawValue, ["pinned": panel.pinned, "columns": panel.columns, "zoom": panel.zoom])
            }),
            "keyboard": ["root": state.keyboardRoot, "count": state.keyboardCount],
            "knobs": controls("k", state.knobs),
            "sliders": controls("s", state.sliders),
        ])
    }

    private func broadcast(_ message: [String: Any]) {
        observers.forEach { $0(message) }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func save() {
        pendingSave?.cancel()
        pendingSave = nil
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
    }

    // MARK: - MIDI

    private func send(_ bytes: [UInt8]) {
        midi.send(bytes, to: state.outputID)
    }

    private func devicesChanged() {
        if state.outputID.isEmpty, let first = midi.outputs.first {
            state.outputID = first.id
            save()
        }
        publishState()
    }
}
