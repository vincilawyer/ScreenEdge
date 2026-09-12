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

        // Synthetic identifiers only: never commit a user's actual display/device IDs.
        let ucScreen = DisplayInfo(id: "UC-SCREEN", name: "Synthetic", frame: CGRect(x: -1200, y: 200, width: 1200, height: 800),
                                   quartzFrame: CGRect(x: -1200, y: -100, width: 1200, height: 800))
        func ucData(_ edge: String = "top", _ rect: [Double] = [300, 0, 900, 1]) -> [String: Any] {
            ["id": ["display": "uc-screen", "device": "synthetic"], "edge": edge, "rect": rect]
        }
        func uc(_ edge: String, _ rect: [Double]) -> Portal? {
            let global = [rect[0] - 1200, rect[1] - 100, rect[2], rect[3]]
            return UCEdgeValue(dictionary: ucData(edge, global))?.portal(displays: [ucScreen])
        }
        let ucTop = uc("top", [300, 0, 900, 1])!
        expect(ucTop.start == -900 && ucTop.end == 0, "UC global coordinates convert through display-local space, including nonzero origin")
        expect(ucTop.rect(on: ucScreen, thickness: 3) == CGRect(x: -900, y: 997, width: 900, height: 3), "UC top strip lies at actual AppKit screen edge")
        expect(ucTop.universalControl && !ucTop.manual && ucTop.usesWarmPalette, "UC is automatic and uses warm palette")
        let ucLeft = uc("left", [0, 100, 1, 500])!
        expect(ucLeft.start == 400 && ucLeft.end == 900, "UC vertical range flips top-left coordinates to AppKit")
        expect(ucLeft.rect(on: ucScreen, thickness: 4) == CGRect(x: -1200, y: 400, width: 4, height: 500), "UC left strip on translated screen")
        expect(uc("right", [1199, 100, 1, 500])?.start == 400, "UC right edge")
        expect(uc("bottom", [100, 799, 700, 1])?.start == -1100, "UC bottom edge")
        expect(uc("top", [-50, 0, 1400, 1])?.start == -1200 && uc("top", [-50, 0, 1400, 1])?.end == 0, "UC clips range to owning screen")
        expect(uc("top", [1300, 0, 50, 1]) == nil, "UC entirely outside screen rejected")
        expect(uc("top", [300, 50, 100, 1]) == nil, "UC incompatible edge offset rejected")
        expect(uc("right", [400, 0, 1, 100]) == nil, "UC wrong right boundary rejected")
        expect(uc("left", [0, 0, 80, 100]) == nil, "UC malformed edge thickness rejected")
        expect(UCEdgeValue(dictionary: ucData())?.portal(displays: [main]) == nil, "UC unknown screen cannot move marker onto another screen")
        expect(UCEdgeValue(dictionary: ucData("diagonal")) == nil, "UC unsupported edge rejected")
        expect(UCEdgeValue(dictionary: ucData("top", [1, 2, 3])) == nil, "UC malformed coordinate count rejected")
        expect(UCEdgeValue(dictionary: ucData("top", [0, 0, 0, 1])) == nil, "UC zero length rejected")
        expect(UCEdgeValue(dictionary: ucData("top", [0, 0, -1, 1])) == nil, "UC negative length rejected")
        expect(UCEdgeValue(dictionary: ucData("top", [.nan, 0, 100, 1])) == nil, "UC NaN rejected")
        expect(UCEdgeValue(dictionary: ucData("top", [0, 0, .infinity, 1])) == nil, "UC infinity rejected")
        expect(UCEdgeValue(dictionary: [:]) == nil, "UC missing data rejected")
        expect(ucLeft.gradientFraction(at: CGPoint(x: -1200, y: 900)) == 0, "UC vertical palette begins at top")
        expect(ucTop.gradientFraction(at: CGPoint(x: -450, y: 1000)) == 0.5, "UC horizontal palette midpoint")
        var ucWithoutQuartz = ucScreen; ucWithoutQuartz.quartzFrame = nil
        expect(UCEdgeValue(dictionary: ucData())?.portal(displays: [ucWithoutQuartz]) == nil, "UC without known Quartz origin is rejected")
        let ucAbove = DisplayInfo(id: "UC-SCREEN", name: "Synthetic above", frame: CGRect(x: 100, y: 900, width: 1600, height: 900),
                                  quartzFrame: CGRect(x: 100, y: -900, width: 1600, height: 900))
        let abovePortal = UCEdgeValue(dictionary: ucData("top", [760, -900, 940, 1]))?.portal(displays: [ucAbove])
        expect(abovePortal?.rect(on: ucAbove, thickness: 3) == CGRect(x: 760, y: 1797, width: 940, height: 3), "UC above external display regression: negative global y and shifted x")

        let legacy: [String: Any] = ["enabled": false, "automatic": false, "nearOnly": true, "thickness": 3,
                                     "markers": [try JSONSerialization.jsonObject(with: data)]]
        let migrated = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(!migrated.enabled && !migrated.automatic && migrated.nearOnly && migrated.thickness == 3, "v1 upgrade preserves existing switches and thickness")
        expect(migrated.automaticUniversalControl && migrated.markers == [marker], "v1 upgrade enables UC without losing manual markers")
        var saved = migrated; saved.automaticUniversalControl = false
        expect(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(saved)).automaticUniversalControl == false, "UC disabled preference persists")
        expect(try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8)).automaticUniversalControl, "new preferences enable automatic UC")
        print("PASS: \(checks) geometry and configuration checks")
    }
}
