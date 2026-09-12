import Foundation
import CoreGraphics

enum EdgeDisplayMode: String, Codable, CaseIterable, Identifiable {
    case always, nearEdges, pointerScreen
    var id: String { rawValue }
    var title: String {
        switch self {
        case .always: return "始终显示全部通道"
        case .nearEdges: return "靠近边缘时显示全部通道"
        case .pointerScreen: return "仅鼠标所在屏幕显示"
        }
    }
}

struct PointerSnapshot {
    let location: CGPoint // AppKit coordinates, the same space as DisplayInfo.frame.
    let isVisible: Bool? // nil means that the system visibility API is unavailable.
}

enum OverlayVisibility {
    static func visibleDisplayIDs(mode: EdgeDisplayMode, displays: [DisplayInfo], pointer: PointerSnapshot,
                                  screenLocked: Bool, alwaysShowWhenLocked: Bool) -> Set<String> {
        // Lock-screen "always visible" overrides proximity, never the selected screen.
        if mode == .always || (mode == .nearEdges && screenLocked && alwaysShowWhenLocked) {
            return Set(displays.map(\.id))
        }
        let point = pointer.location
        guard point.x.isFinite, point.y.isFinite else { return [] }
        if mode == .pointerScreen {
            // Universal Control can leave an old local coordinate behind. Never treat that
            // position, recent movement, or inactivity alone as proof of a local pointer.
            guard pointer.isVisible == true else { return [] }
            // Use Quartz-style ownership after AppKit's y flip: left/top inclusive,
            // right/bottom exclusive. This includes the very top row of the desktop.
            guard let screen = displays.first(where: {
                point.x >= $0.frame.minX && point.x < $0.frame.maxX &&
                point.y > $0.frame.minY && point.y <= $0.frame.maxY
            }) else { return [] }
            return [screen.id]
        }
        let nearEdge = displays.contains { display in
            let f = display.frame
            let edges = [CGRect(x: f.minX, y: f.minY, width: f.width, height: 0),
                         CGRect(x: f.minX, y: f.maxY, width: f.width, height: 0),
                         CGRect(x: f.minX, y: f.minY, width: 0, height: f.height),
                         CGRect(x: f.maxX, y: f.minY, width: 0, height: f.height)]
            return edges.contains { PortalGeometry.distance(point, to: $0) <= 110 }
        }
        return nearEdge ? Set(displays.map(\.id)) : []
    }
}
