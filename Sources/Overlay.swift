import AppKit

final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Edge indicators intentionally occupy menu-bar/Dock edges as well.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class EdgeStripView: NSView {
    let manual: Bool
    let vertical: Bool
    init(frame: CGRect, manual: Bool, vertical: Bool) {
        self.manual = manual; self.vertical = vertical
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let radius = min(bounds.width, bounds.height) / 2
        let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.addPath(path); context.clip()
        let colors = PortalPalette.stops(manual: manual).map { CGColor(colorSpace: space, components: $0)! }
        let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
        let start = vertical ? CGPoint(x: bounds.midX, y: bounds.maxY) : CGPoint(x: bounds.minX, y: bounds.midY)
        let end = vertical ? CGPoint(x: bounds.midX, y: bounds.minY) : CGPoint(x: bounds.maxX, y: bounds.midY)
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(0.5); context.strokePath()
    }
}

@MainActor final class OverlayController {
    struct Entry { let window: EdgePanel; let portal: Portal; let frame: CGRect }
    private(set) var entries: [Entry] = []
    private var timer: Timer?
    private var nearOnly = false
    private var previewWindows: [EdgePanel] = []
    private var previewTask: DispatchWorkItem?

    func rebuild(model: AppModel) {
        previewTask?.cancel()
        previewWindows.forEach { $0.close() }; previewWindows.removeAll()
        timer?.invalidate(); timer = nil
        entries.forEach { $0.window.close() }; entries.removeAll()
        guard model.preferences.enabled else { return }
        nearOnly = model.preferences.nearOnly
        for portal in model.portals {
            guard let screen = model.displays.first(where: { $0.id == portal.displayID }) else { continue }
            let rect = portal.rect(on: screen, thickness: model.preferences.thickness).integral
            guard rect.width > 0 && rect.height > 0 else { continue }
            let panel = makePanel(frame: rect, manual: portal.usesWarmPalette, vertical: portal.edge.vertical)
            panel.alphaValue = nearOnly ? 0 : 1.0
            panel.orderFrontRegardless()
            entries.append(Entry(window: panel, portal: portal, frame: rect))
        }
        if nearOnly && !entries.isEmpty {
            updateProximity()
            // Read pointer position only. No event taps, accessibility permission, or input interception.
            timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateProximity() }
            }
            timer?.tolerance = 0.025
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    private func makePanel(frame: CGRect, manual: Bool, vertical: Bool) -> EdgePanel {
        let panel = EdgePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.contentView = EdgeStripView(frame: CGRect(origin: .zero, size: frame.size), manual: manual, vertical: vertical)
        return panel
    }

    private func updateProximity() {
        let mouse = NSEvent.mouseLocation
        for entry in entries {
            // The counterpart line lights too when its edge is adjacent.
            let distance = PortalGeometry.distance(mouse, to: entry.frame)
            let alpha: CGFloat = distance <= 110 ? 1.0 : 0
            if entry.window.alphaValue != alpha { entry.window.alphaValue = alpha }
        }
    }

    func preview(model: AppModel) {
        previewTask?.cancel()
        previewWindows.forEach { $0.close() }; previewWindows.removeAll()
        for screen in model.displays {
            let f = screen.frame
            let portal = Portal(id: "preview", displayID: screen.id, edge: .right,
                                start: f.minY + f.height * 0.25, end: f.minY + f.height * 0.75, label: "预览", manual: false)
            let panel = makePanel(frame: portal.rect(on: screen, thickness: model.preferences.thickness).integral, manual: false, vertical: true)
            panel.orderFrontRegardless()
            previewWindows.append(panel)
        }
        let task = DispatchWorkItem { [weak self] in
            self?.previewWindows.forEach { $0.close() }; self?.previewWindows.removeAll()
        }
        previewTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
    }
}
