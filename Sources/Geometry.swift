import Foundation
import CoreGraphics

struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let frame: CGRect // AppKit coordinates: origin at bottom left
}

enum Edge: String, Codable, CaseIterable, Identifiable {
    case left, right, top, bottom
    var id: String { rawValue }
    var title: String {
        switch self { case .left: return "左侧"; case .right: return "右侧"; case .top: return "上方"; case .bottom: return "下方" }
    }
    var vertical: Bool { self == .left || self == .right }
}

struct ManualMarker: Codable, Identifiable, Equatable {
    var id = UUID()
    var displayID: String
    var label = "另一台 Mac / iPad"
    var edge: Edge = .right
    var start: Double = 0.25 // top to bottom / left to right
    var end: Double = 0.75
    var enabled = true
}

struct Portal: Identifiable, Equatable {
    let id: String
    let displayID: String
    let edge: Edge
    let start: CGFloat // global coordinate along edge
    let end: CGFloat
    let label: String
    let manual: Bool

    /// Each reciprocal automatic portal has the same start/end interval.
    /// Horizontal edges read left-to-right; vertical edges read top-to-bottom.
    func gradientFraction(at point: CGPoint) -> CGFloat {
        let coordinate = edge.vertical ? point.y : point.x
        let fraction = (coordinate - start) / (end - start)
        return max(0, min(1, edge.vertical ? 1 - fraction : fraction))
    }

    func rect(on screen: DisplayInfo, thickness: CGFloat) -> CGRect {
        let f = screen.frame
        let width = max(1, min(thickness, 12))
        switch edge {
        case .left: return CGRect(x: f.minX, y: start, width: width, height: end - start)
        case .right: return CGRect(x: f.maxX - width, y: start, width: width, height: end - start)
        case .top: return CGRect(x: start, y: f.maxY - width, width: end - start, height: width)
        case .bottom: return CGRect(x: start, y: f.minY, width: end - start, height: width)
        }
    }
}

enum PortalGeometry {
    static func automatic(_ displays: [DisplayInfo]) -> [Portal] {
        var portals: [Portal] = []
        let epsilon: CGFloat = 0.5
        for a in displays {
            for b in displays where a.id != b.id {
                // Identical/mirrored rectangles and overlap are not passages.
                let y0 = max(a.frame.minY, b.frame.minY), y1 = min(a.frame.maxY, b.frame.maxY)
                let x0 = max(a.frame.minX, b.frame.minX), x1 = min(a.frame.maxX, b.frame.maxX)
                func add(_ edge: Edge, _ start: CGFloat, _ end: CGFloat) {
                    guard end - start > epsilon else { return }
                    portals.append(Portal(id: "auto-\(a.id)-\(b.id)-\(edge.rawValue)", displayID: a.id,
                                          edge: edge, start: start, end: end, label: b.name, manual: false))
                }
                if abs(a.frame.maxX - b.frame.minX) <= epsilon { add(.right, y0, y1) }
                if abs(a.frame.minX - b.frame.maxX) <= epsilon { add(.left, y0, y1) }
                if abs(a.frame.maxY - b.frame.minY) <= epsilon { add(.top, x0, x1) }
                if abs(a.frame.minY - b.frame.maxY) <= epsilon { add(.bottom, x0, x1) }
            }
        }
        return portals
    }

    static func manual(_ markers: [ManualMarker], displays: [DisplayInfo]) -> [Portal] {
        markers.compactMap { marker in
            guard marker.enabled, marker.start.isFinite, marker.end.isFinite,
                  let screen = displays.first(where: { $0.id == marker.displayID }) else { return nil }
            let low = max(0, min(1, min(marker.start, marker.end)))
            let high = max(0, min(1, max(marker.start, marker.end)))
            guard high > low else { return nil }
            let f = screen.frame
            let start = marker.edge.vertical ? f.maxY - high * f.height : f.minX + low * f.width
            let end = marker.edge.vertical ? f.maxY - low * f.height : f.minX + high * f.width
            return Portal(id: marker.id.uuidString, displayID: screen.id, edge: marker.edge,
                          start: start, end: end, label: marker.label, manual: true)
        }
    }

    static func distance(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}


enum PortalPalette {
    // Same ordered stops on both ends of a passage, independent of screen size or scale.
    static let automatic: [[CGFloat]] = [
        [1.00, 0.38, 0.25, 1], [1.00, 0.76, 0.16, 1], [0.17, 0.85, 0.50, 1],
        [0.12, 0.72, 1.00, 1], [0.45, 0.37, 0.98, 1], [0.94, 0.30, 0.72, 1]
    ]
    static let manual: [[CGFloat]] = [
        [1.00, 0.73, 0.22, 1], [1.00, 0.43, 0.25, 1], [0.96, 0.28, 0.54, 1],
        [0.64, 0.35, 0.94, 1], [0.30, 0.62, 1.00, 1]
    ]
    static func stops(manual: Bool) -> [[CGFloat]] { manual ? self.manual : automatic }
}
