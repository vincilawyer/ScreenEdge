import AppKit

final class EdgeStripView: NSView {
    let manual: Bool
    let vertical: Bool
    private(set) var edgeAppearance: EdgeAppearance
    let materialView = NSVisualEffectView()
    private let paint = EdgePaintView()
    private var accessibilityObserver: NSObjectProtocol?
    var usesGlass: Bool { !materialView.isHidden }

    init(frame: CGRect, appearance: EdgeAppearance, manual: Bool = false, vertical: Bool,
         blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.edgeAppearance = appearance; self.manual = manual; self.vertical = vertical
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        materialView.frame = bounds
        materialView.autoresizingMask = [.width, .height]
        materialView.material = .underWindowBackground
        materialView.blendingMode = blendingMode
        materialView.state = .active
        addSubview(materialView)
        paint.frame = bounds
        paint.autoresizingMask = [.width, .height]
        paint.vertical = vertical
        addSubview(paint)
        updateAppearance(appearance)
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.updateAppearance(self.edgeAppearance)
            }
    }
    convenience init(frame: CGRect, manual: Bool, vertical: Bool) {
        self.init(frame: frame, appearance: manual ? .legacyUniversal : .legacyExtended, manual: manual, vertical: vertical)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) } }
    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
    func updateAppearance(_ appearance: EdgeAppearance, reduceTransparency override: Bool? = nil) {
        self.edgeAppearance = appearance
        let reduceTransparency = override ?? NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        materialView.isHidden = appearance.material != .glass || reduceTransparency
        alphaValue = appearance.material == .glass && reduceTransparency ? 1 : appearance.effectiveOpacity
        paint.edgeAppearance = appearance
        paint.opaqueGlass = reduceTransparency
        paint.needsDisplay = true
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

private final class EdgePaintView: NSView {
    var edgeAppearance: EdgeAppearance = .legacyExtended
    var vertical = false
    var opaqueGlass = false
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let radius = min(bounds.width, bounds.height) / 2
        let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.addPath(path); context.clip()
        switch edgeAppearance.material {
        case .gradient, .solid:
            let colors = edgeAppearance.colors.map { CGColor(colorSpace: space, components: $0.components)! }
            let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
            let start = vertical ? CGPoint(x: bounds.midX, y: bounds.maxY) : CGPoint(x: bounds.minX, y: bounds.midY)
            let end = vertical ? CGPoint(x: bounds.midX, y: bounds.minY) : CGPoint(x: bounds.maxX, y: bounds.midY)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .glass:
            if opaqueGlass {
                context.setFillColor(NSColor.windowBackgroundColor.cgColor)
                context.fill(bounds)
            }
            let c = edgeAppearance.color
            context.setFillColor(NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 0.22).cgColor)
            context.fill(bounds)
        }
        context.restoreGState()
        context.addPath(path)
        let glass = edgeAppearance.material == .glass
        context.setStrokeColor((glass ? NSColor.white.withAlphaComponent(0.5) : NSColor.black.withAlphaComponent(0.10)).cgColor)
        context.setLineWidth(glass ? 0.65 : 0.35)
        context.strokePath()
    }
}
