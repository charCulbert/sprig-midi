import AppKit
import WebKit

private final class PanelWebView: WKWebView {
    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

// borderless: the page draws the title bar and asks us to move, resize, pin and close
final class WebPanel: NSPanel, NSWindowDelegate, WKScriptMessageHandler {
    let kind: PanelKind
    private let controller: Controller
    private let webView: WKWebView
    private var ready = false
    private var drag: (mouse: NSPoint, origin: NSPoint)?

    private static let minSize = NSSize(width: 80, height: 48)

    init(kind: PanelKind, controller: Controller) {
        self.kind = kind
        self.controller = controller

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(AppResourceSchemeHandler(), forURLScheme: AppResourceSchemeHandler.scheme)
        webView = PanelWebView(frame: NSRect(origin: .zero, size: kind.defaultSize), configuration: configuration)

        super.init(
            contentRect: NSRect(origin: .zero, size: kind.defaultSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        delegate = self

        configuration.userContentController.add(self, name: "host")
        webView.setValue(false, forKey: "drawsBackground")
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.autoresizingMask = [.width, .height]
        contentView = webView

        restoreFrame()
        applyPinned(controller.panel(kind).pinned)
        webView.pageZoom = controller.panel(kind).zoom
        controller.observe { [weak self] message in self?.post(message) }

        webView.load(URLRequest(url: URL(string: "\(AppResourceSchemeHandler.scheme)://app/\(kind.page).html?\(kind.rawValue)")!))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func show() {
        controller.updatePanel(kind) { $0.visible = true }
        ensureOnScreen()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        controller.updatePanel(kind) { $0.visible = false }
        orderOut(nil)
    }

    // MARK: - Page messages

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }

        switch body["type"] as? String {
        case "ready":
            ready = true
            controller.publishState()
            invalidateShadow()
        case "drag":
            handleDrag(phase: body["phase"] as? String ?? "")
        case "resize":
            guard
                let width = (body["width"] as? NSNumber)?.doubleValue,
                let height = (body["height"] as? NSNumber)?.doubleValue
            else { return }
            let zoom = webView.pageZoom
            resize(to: NSSize(width: width * zoom, height: height * zoom), keepingRight: body["anchor"] as? String == "right")
        case "zoom":
            let step = (body["step"] as? NSNumber)?.doubleValue ?? 0
            let old = webView.pageZoom
            let zoom = step == 0 ? 1 : min(3, max(0.5, ((old + step * 0.1) * 10).rounded() / 10))
            webView.pageZoom = zoom
            controller.updatePanel(kind) { $0.zoom = zoom }
            resize(to: NSSize(width: frame.width * zoom / old, height: frame.height * zoom / old), keepingRight: false)
            controller.publishState()
        case "columns":
            guard let count = (body["count"] as? NSNumber)?.intValue else { return }
            controller.updatePanel(kind) { $0.columns = count }
        case "pin":
            let pinned = (body["pinned"] as? Bool) ?? false
            controller.updatePanel(kind) { $0.pinned = pinned }
            applyPinned(pinned)
        case "close":
            hide()
        case "context":
            if let id = body["id"] as? String {
                controller.showMenu(forControl: id, in: webView)
            }
        default:
            controller.handle(body)
        }
    }

    private func post(_ message: [String: Any]) {
        guard
            ready,
            let data = try? JSONSerialization.data(withJSONObject: message),
            let json = String(data: data, encoding: .utf8)
        else { return }
        webView.evaluateJavaScript("window.host?.receive(\(json))")
    }

    // MARK: - Geometry

    private func handleDrag(phase: String) {
        switch phase {
        case "start":
            drag = (NSEvent.mouseLocation, frame.origin)
        case "move":
            guard let drag else { return }
            let mouse = NSEvent.mouseLocation
            setFrameOrigin(NSPoint(x: drag.origin.x + mouse.x - drag.mouse.x, y: drag.origin.y + mouse.y - drag.mouse.y))
        default:
            drag = nil
        }
    }

    private func resize(to size: NSSize, keepingRight: Bool) {
        let size = NSSize(width: max(Self.minSize.width, size.width.rounded()), height: max(Self.minSize.height, size.height.rounded()))
        guard size != frame.size else { return }
        var next = frame
        next.origin.y = frame.maxY - size.height
        if keepingRight {
            next.origin.x = frame.maxX - size.width
        }
        next.size = size
        setFrame(next, display: true)
        invalidateShadow()
    }

    private func applyPinned(_ pinned: Bool) {
        level = pinned ? .floating : .normal
    }

    private func restoreFrame() {
        if let saved = controller.panel(kind).frame {
            let frame = NSRectFromString(saved)
            if frame.width >= Self.minSize.width, frame.height >= Self.minSize.height {
                setFrame(frame, display: false)
                ensureOnScreen()
                return
            }
        }
        placeByDefault(size: kind.defaultSize)
    }

    private func ensureOnScreen() {
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
            placeByDefault(size: frame.size)
        }
    }

    private func placeByDefault(size: NSSize) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let y = kind == .keyboard ? screen.minY + 80 : screen.midY
        setFrame(NSRect(x: screen.midX - size.width / 2, y: y, width: size.width, height: size.height), display: false)
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        let frame = NSStringFromRect(frame)
        controller.updatePanel(kind) { $0.frame = frame }
    }
}
