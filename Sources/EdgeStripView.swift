import AppKit

final class EdgeStripView: NSView {
    let manual: Bool
    let vertical: Bool
    private(set) var edgeAppearance: EdgeAppearance
    private let paint = EdgePaintView()

    init(frame: CGRect, appearance: EdgeAppearance, manual: Bool = false, vertical: Bool) {
        self.edgeAppearance = appearance; self.manual = manual; self.vertical = vertical
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        paint.frame = bounds
        paint.autoresizingMask = [.width, .height]
        paint.vertical = vertical
        addSubview(paint)
        updateAppearance(appearance)

    }
    convenience init(frame: CGRect, manual: Bool, vertical: Bool) {
        self.init(frame: frame, appearance: manual ? .legacyUniversal : .legacyExtended, manual: manual, vertical: vertical)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
    func updateAppearance(_ appearance: EdgeAppearance) {
        self.edgeAppearance = appearance
        alphaValue = appearance.effectiveOpacity
        paint.edgeAppearance = appearance
        paint.needsDisplay = true
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

private final class EdgePaintView: NSView {
    var edgeAppearance: EdgeAppearance = .legacyExtended
    var vertical = false
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let radius = min(bounds.width, bounds.height) / 2
        let path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.addPath(path); context.clip()
        let colors = edgeAppearance.colors.map { CGColor(colorSpace: space, components: $0.components)! }
        let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
        let start = vertical ? CGPoint(x: bounds.midX, y: bounds.maxY) : CGPoint(x: bounds.minX, y: bounds.midY)
        let end = vertical ? CGPoint(x: bounds.midX, y: bounds.minY) : CGPoint(x: bounds.maxX, y: bounds.midY)
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.10).cgColor)
        context.setLineWidth(0.35)
        context.strokePath()
    }
}
