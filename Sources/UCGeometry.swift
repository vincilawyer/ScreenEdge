import Foundation
import CoreGraphics

struct UCEdgeValue: Equatable {
    let displayID: String
    let edge: Edge
    let rect: CGRect // CoreGraphics global desktop coordinates, y increases downward

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? [String: Any],
              let display = id["display"] as? String, !display.isEmpty,
              let name = dictionary["edge"] as? String, let edge = Edge(rawValue: name),
              let coordinates = dictionary["rect"] as? [NSNumber], coordinates.count == 4,
              coordinates.allSatisfy({ $0.doubleValue.isFinite }),
              coordinates[2].doubleValue > 0, coordinates[3].doubleValue > 0 else { return nil }
        let rect = CGRect(x: coordinates[0].doubleValue, y: coordinates[1].doubleValue,
                          width: coordinates[2].doubleValue, height: coordinates[3].doubleValue)
        self.displayID = display
        self.edge = edge
        self.rect = rect
    }

    init(displayID: String, edge: Edge, rect: CGRect) {
        self.displayID = displayID; self.edge = edge; self.rect = rect
    }

    func portal(displays: [DisplayInfo]) -> Portal? {
        guard let screen = displays.first(where: { $0.id.caseInsensitiveCompare(displayID) == .orderedSame }) else { return nil }
        let f = screen.frame
        guard let quartz = screen.quartzFrame,
              abs(quartz.width - f.width) < 1.5, abs(quartz.height - f.height) < 1.5 else { return nil }
        // UC returns global Quartz coordinates, including negative origins for screens above.
        let rect = self.rect.offsetBy(dx: -quartz.minX, dy: -quartz.minY)
        // Reject incompatible coordinates instead of drawing on the wrong edge.
        let edgeMatches: Bool
        switch edge {
        case .left: edgeMatches = abs(rect.minX) <= 1.5 && rect.width <= 2
        case .right: edgeMatches = abs(rect.maxX - f.width) <= 1.5 && rect.width <= 2
        case .top: edgeMatches = abs(rect.minY) <= 1.5 && rect.height <= 2
        case .bottom: edgeMatches = abs(rect.maxY - f.height) <= 1.5 && rect.height <= 2
        }
        guard edgeMatches else { return nil }
        let low = max(0, edge.vertical ? rect.minY : rect.minX)
        let high = min(edge.vertical ? f.height : f.width, edge.vertical ? rect.maxY : rect.maxX)
        guard high > low else { return nil }
        let start = edge.vertical ? f.maxY - high : f.minX + low
        let end = edge.vertical ? f.maxY - low : f.minX + high
        return Portal(id: "uc-\(screen.id)-\(edge.rawValue)-\(low)-\(high)", displayID: screen.id,
                      edge: edge, start: start, end: end, label: "通用控制", manual: false, universalControl: true)
    }
}
