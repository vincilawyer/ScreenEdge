import AppKit

extension AppDelegate {
    /// Own-process rendering only; no screenshot, user preference writes or accessibility changes.
    func runAppearanceChecks() {
        func image(_ view: NSView) -> NSBitmapImageRep {
            view.layoutSubtreeIfNeeded()
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            return rep
        }
        func rgb(_ rep: NSBitmapImageRep, _ fraction: CGFloat, vertical: Bool) -> NSColor {
            rep.colorAt(x: vertical ? rep.pixelsWide / 2 : Int(CGFloat(rep.pixelsWide) * fraction),
                        y: vertical ? Int(CGFloat(rep.pixelsHigh) * fraction) : rep.pixelsHigh / 2)!.usingColorSpace(.sRGB)!
        }
        func close(_ a: NSColor, _ b: NSColor) -> Bool {
            abs(a.redComponent - b.redComponent) < 0.04 && abs(a.greenComponent - b.greenComponent) < 0.04 && abs(a.blueComponent - b.blueComponent) < 0.04
        }
        for preset in EdgeGradient.allCases {
            let style = EdgeAppearance(material: .gradient, gradient: preset,
                                       gradientStart: .rose, gradientEnd: .mint, opacity: 1)
            for vertical in [true, false] {
                let small = EdgeStripView(frame: CGRect(x: 0, y: 0, width: vertical ? 8 : 400, height: vertical ? 400 : 8), appearance: style, vertical: vertical)
                let large = EdgeStripView(frame: CGRect(x: 0, y: 0, width: vertical ? 8 : 800, height: vertical ? 800 : 8), appearance: style, vertical: vertical)
                let a = image(small), b = image(large)
                for f: CGFloat in [0.05, 0.25, 0.5, 0.75, 0.95] {
                    precondition(close(rgb(a, f, vertical: vertical), rgb(b, f, vertical: vertical)), "preset and custom gradients scale along the passage")
                }
                let first = style.colors.first!
                let expected = NSColor(srgbRed: first.red, green: first.green, blue: first.blue, alpha: 1)
                precondition(close(rgb(a, 0.01, vertical: vertical), expected), "vertical starts at top, horizontal starts at left")
            }
        }
        let view = EdgeStripView(frame: CGRect(x: 0, y: 0, width: 400, height: 8),
                                 appearance: EdgeAppearance(material: .solid, color: .rose, opacity: 1), vertical: false)
        let solid = image(view)
        let expected = NSColor(srgbRed: EdgeColor.rose.red, green: EdgeColor.rose.green, blue: EdgeColor.rose.blue, alpha: 1)
        precondition(close(rgb(solid, 0.05, vertical: false), expected) && close(rgb(solid, 0.95, vertical: false), expected), "solid color reaches both endpoints")
        view.updateAppearance(EdgeAppearance(material: .glass, color: .mint, opacity: 0.45), reduceTransparency: false)
        precondition(view.usesGlass && view.materialView.blendingMode == .behindWindow && view.materialView.state == .active)
        precondition(abs(view.alphaValue - 0.45) < 0.001 && view.hitTest(.zero) == nil, "glass opacity remains independent of pointer visibility and hit testing")
        view.updateAppearance(view.edgeAppearance, reduceTransparency: true)
        precondition(!view.usesGlass && view.alphaValue == 1 && rgb(image(view), 0.5, vertical: false).alphaComponent > 0.99,
                     "reduce-transparency fallback is opaque without changing system settings")
        view.updateAppearance(EdgeAppearance(material: .gradient, gradient: .lavender, opacity: 0.65))
        precondition(!view.usesGlass && abs(view.alphaValue - 0.65) < 0.001, "switching away from glass removes the blur layer and restores opacity")
        guard let screen = model.displays.first, let frame = screen.quartzFrame else { preconditionFailure("no native display snapshot") }
        let original = model.preferences
        defer { model.applyUniversalControlResponse([], error: nil); model.preferences = original }
        model.preferences.automatic = false
        model.preferences.displayMode = .pointerScreen
        model.preferences.markers = []
        model.applyUniversalControlResponse([["id": ["display": screen.id, "device": "synthetic-style-check"],
            "edge": "bottom", "rect": [frame.minX, frame.maxY - 1, frame.width * 0.7, 1]]], error: nil)
        for material in EdgeMaterial.allCases {
            let selected = EdgeAppearance(material: material, gradient: .aurora, color: .rose, opacity: 0.65)
            model.preferences.universalAppearance = selected
            precondition(overlays.entries.count == 1 && overlays.entries[0].portal.universalControl)
            let entry = overlays.entries[0]
            let strip = entry.window.contentView as! EdgeStripView
            precondition(strip.edgeAppearance == selected && entry.window.ignoresMouseEvents && !entry.window.canBecomeKey)
            let local = PointerSnapshot(location: CGPoint(x: screen.frame.midX, y: screen.frame.midY), isVisible: true)
            overlays.updateVisibility(pointer: local)
            let contentOpacity = strip.alphaValue
            precondition(entry.window.alphaValue == 1)
            overlays.updateVisibility(pointer: PointerSnapshot(location: local.location, isVisible: false))
            precondition(entry.window.alphaValue == 0 && strip.alphaValue == contentOpacity, "pointer departure does not overwrite the style opacity")
            overlays.updateVisibility(pointer: local)
            precondition(entry.window.alphaValue == 1 && strip.alphaValue == contentOpacity)
        }
        print("PASS: all gradient presets and custom endpoints at two lengths/orientations; solid pixels; native glass, opacity, click-through, reduced-transparency fallback and material switching")
        print("PASS: synthetic UC overlays use each configured material and preserve opacity across pointer departure/return; not a live UC connection test")
    }
}
