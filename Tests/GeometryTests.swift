import Foundation
import CoreGraphics

@main struct GeometryTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: Bool, _ name: String) {
            guard condition else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            checks += 1
        }
        func display(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> DisplayInfo {
            DisplayInfo(id: id, name: id, frame: CGRect(x: x, y: y, width: w, height: h))
        }
        let main = display("main", 0, 0, 1440, 900)
        let right = display("right", 1440, 200, 1920, 1080)
        let pair = PortalGeometry.automatic([main, right])
        expect(pair.count == 2, "one passage produces two edge strips")
        expect(pair[0].edge == .right && pair[0].start == 200 && pair[0].end == 900, "only the shared vertical segment is marked")
        expect(pair[1].edge == .left && pair[1].start == 200, "reciprocal segment matches")
        expect(pair[0].rect(on: main, thickness: 4) == CGRect(x: 1436, y: 200, width: 4, height: 700), "line stays within owning display")
        let below = display("below", -100, -800, 1000, 800)
        let vertical = PortalGeometry.automatic([main, below])
        expect(vertical.count == 2 && vertical[0].edge == .bottom, "vertical arrangement with negative origin")
        expect(vertical[0].start == 0 && vertical[0].end == 900, "horizontal overlap clipped")
        let above = display("above", 200, 900, 900, 700)
        expect(PortalGeometry.automatic([main, above]).first?.edge == .top, "top edge")
        let left = display("left", -800, 50, 800, 600)
        expect(PortalGeometry.automatic([main, left]).first?.edge == .left, "left edge")
        expect(PortalGeometry.automatic([main]).isEmpty, "single screen has no automatic passage")
        expect(PortalGeometry.automatic([main, display("mirror", 0, 0, 1440, 900)]).isEmpty, "mirrors")
        expect(PortalGeometry.automatic([main, display("corner", 1440, 900, 1000, 700)]).isEmpty, "corner touching is not passage")
        expect(PortalGeometry.automatic([main, display("gap", 1460, 0, 1000, 900)]).isEmpty, "gap is not a real passage")
        expect(PortalGeometry.automatic([main, display("overlap", 1400, 0, 1000, 900)]).isEmpty, "overlapping displays are excluded")
        let triple = PortalGeometry.automatic([main, display("r1", 1440, 0, 500, 400), display("r2", 1440, 400, 500, 500)])
        expect(triple.filter { $0.displayID == "main" }.count == 2, "split adjacency to two different targets")
        var marker = ManualMarker(displayID: main.id, label: "test", edge: .right, start: 0.1, end: 0.6)
        var manual = PortalGeometry.manual([marker], displays: [main])
        expect(manual.count == 1 && manual[0].start == 360 && manual[0].end == 810, "manual percentages run top to bottom")
        marker.edge = .top
        manual = PortalGeometry.manual([marker], displays: [main])
        expect(manual[0].start == 144 && manual[0].end == 864, "horizontal percentages run left to right")
        marker.start = -3; marker.end = 4
        manual = PortalGeometry.manual([marker], displays: [main])
        expect(manual[0].start == 0 && manual[0].end == 1440, "clamp invalid range")
        marker.start = 0.9; marker.end = 0.2
        expect(PortalGeometry.manual([marker], displays: [main]).count == 1, "normalize reversed endpoints")
        marker.start = 0.5; marker.end = 0.5
        expect(PortalGeometry.manual([marker], displays: [main]).isEmpty, "zero length marker omitted")
        marker.start = .nan
        expect(PortalGeometry.manual([marker], displays: [main]).isEmpty, "invalid numeric data omitted")
        marker.start = 0.1; marker.end = 0.9; marker.enabled = false
        expect(PortalGeometry.manual([marker], displays: [main]).isEmpty, "disabled marker omitted")
        marker.enabled = true
        expect(PortalGeometry.manual([marker], displays: [right]).isEmpty, "unplugged display marker does not move to another display")
        for portals in [pair, vertical] {
            for fraction: CGFloat in [0.02, 0.2, 0.5, 0.75, 0.98] {
                let a = portals[0], b = portals[1]
                let coordinate = a.start + (a.end - a.start) * fraction
                let point = a.edge.vertical ? CGPoint(x: 0, y: coordinate) : CGPoint(x: coordinate, y: 0)
                expect(abs(a.gradientFraction(at: point) - b.gradientFraction(at: point)) < 0.00001,
                       "reciprocal gradient colors match at actual crossing coordinates")
            }
        }
        expect(pair[0].gradientFraction(at: CGPoint(x: 1440, y: 900)) == 0, "vertical gradient starts at top")
        expect(vertical[0].gradientFraction(at: CGPoint(x: 0, y: 0)) == 0, "horizontal gradient starts at left")
        expect(PortalPalette.automatic.count >= 5 && PortalPalette.manual.count >= 5, "distinct color landmarks along each gradient")
        let data = try JSONEncoder().encode(marker)
        expect(try JSONDecoder().decode(ManualMarker.self, from: data) == marker, "marker roundtrip preserves identity and range")
        let f = CGRect(x: 10, y: 20, width: 4, height: 500)
        expect(PortalGeometry.distance(CGPoint(x: 14, y: 100), to: f) == 0, "on edge distance")
        expect(PortalGeometry.distance(CGPoint(x: 114, y: 100), to: f) == 100, "proximity perpendicular distance")
        expect(PortalGeometry.distance(CGPoint(x: 14, y: 620), to: f) == 100, "proximity beyond segment ends")
        print("PASS: \(checks) geometry and configuration checks")
    }
}
