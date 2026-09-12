import Foundation
import CoreGraphics

/// A diagram-only destination. The basic UC API does not expose remote screen geometry.
/// These frames must never enter DisplayInfo or the real overlay controller.
struct RemoteDisplayHint: Identifiable {
    let id: String
    let frame: CGRect
    let source: CGPoint
    let destination: CGPoint
}

enum DisplayMapGeometry {
    static func remoteHints(displays: [DisplayInfo], portals: [Portal]) -> [RemoteDisplayHint] {
        var hints: [RemoteDisplayHint] = []
        for portal in portals where portal.universalControl {
            guard let screen = displays.first(where: { $0.id == portal.displayID }) else { continue }
            let f = screen.frame
            let gap = min(f.width, f.height) * 0.22
            let width = f.width * 0.78, height = f.height * 0.65
            let mid = (portal.start + portal.end) / 2
            let source: CGPoint
            var rect: CGRect
            switch portal.edge {
            case .top:
                source = CGPoint(x: mid, y: f.maxY)
                rect = CGRect(x: mid - width / 2, y: f.maxY + gap, width: width, height: height)
            case .bottom:
                source = CGPoint(x: mid, y: f.minY)
                rect = CGRect(x: mid - width / 2, y: f.minY - gap - height, width: width, height: height)
            case .left:
                source = CGPoint(x: f.minX, y: mid)
                rect = CGRect(x: f.minX - gap - width, y: mid - height / 2, width: width, height: height)
            case .right:
                source = CGPoint(x: f.maxX, y: mid)
                rect = CGRect(x: f.maxX + gap, y: mid - height / 2, width: width, height: height)
            }
            // Keep each hint outside actual screens and earlier destination hints.
            let occupied = displays.map(\.frame) + hints.map(\.frame)
            for _ in 0...occupied.count {
                guard let collision = occupied.first(where: { $0.insetBy(dx: -gap / 3, dy: -gap / 3).intersects(rect) }) else { break }
                switch portal.edge {
                case .top: rect.origin.y = collision.maxY + gap
                case .bottom: rect.origin.y = collision.minY - gap - height
                case .left: rect.origin.x = collision.minX - gap - width
                case .right: rect.origin.x = collision.maxX + gap
                }
            }
            let destination: CGPoint
            switch portal.edge {
            case .top: destination = CGPoint(x: rect.midX, y: rect.minY)
            case .bottom: destination = CGPoint(x: rect.midX, y: rect.maxY)
            case .left: destination = CGPoint(x: rect.maxX, y: rect.midY)
            case .right: destination = CGPoint(x: rect.minX, y: rect.midY)
            }
            hints.append(RemoteDisplayHint(id: portal.id, frame: rect, source: source, destination: destination))
        }
        return hints
    }
}
