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

        let mirrorDesktop = DisplayInfo(id: "MIRROR-PRIMARY", name: "Synthetic mirrored desktop",
                                        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                        quartzFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                        mirroredDisplayIDs: ["MIRROR-SECONDARY"])
        let mirrorEdge = UCEdgeValue(displayID: "mirror-secondary", edge: .bottom,
                                    rect: CGRect(x: 0, y: 1079, width: 1119, height: 1))
        let mirrorPortal = mirrorEdge.portal(displays: [mirrorDesktop])
        expect(mirrorPortal?.displayID == mirrorDesktop.id, "UC secondary mirror identity maps to the visible desktop")
        expect(mirrorPortal?.rect(on: mirrorDesktop, thickness: 3) == CGRect(x: 0, y: 0, width: 1119, height: 3), "UC mirrored bottom passage preserves the actual range")
        expect(mirrorPortal?.universalControl == true && mirrorPortal?.manual == false, "mirrored UC remains an automatic warm passage")
        var unmirroredDesktop = mirrorDesktop; unmirroredDesktop.mirroredDisplayIDs = []
        expect(mirrorEdge.portal(displays: [unmirroredDesktop]) == nil, "removing mirror membership removes the alias mapping")
        expect(UCEdgeValue(displayID: "UNKNOWN-SCREEN", edge: .bottom, rect: mirrorEdge.rect).portal(displays: [mirrorDesktop]) == nil, "matching geometry without a confirmed mirror identity is rejected")
        expect(UCEdgeValue(displayID: "MIRROR-SECONDARY", edge: .bottom,
                           rect: CGRect(x: 0, y: 500, width: 1119, height: 1)).portal(displays: [mirrorDesktop]) == nil, "mirror aliases still require compatible edge coordinates")

        let hints = DisplayMapGeometry.remoteHints(displays: [main, ucAbove], portals: [abovePortal!])
        expect(hints.count == 1, "map includes UC destination in addition to the two real screens")
        expect(hints[0].frame.minY > ucAbove.frame.maxY, "UC destination appears beyond the correct external screen edge")
        expect(hints[0].source == CGPoint(x: 1230, y: 1800), "diagram connection starts at actual passage midpoint")
        expect(DisplayMapGeometry.remoteHints(displays: [main], portals: pair).isEmpty, "ordinary extension passages do not create fictional remote screens")
        expect(DisplayMapGeometry.remoteHints(displays: [main], portals: [abovePortal!]).isEmpty, "missing local display removes its remote hint")
        expect(DisplayMapGeometry.remoteHints(displays: [main], portals: []).isEmpty, "empty UC snapshot removes destination hints")
        for edge in Edge.allCases {
            let portal = Portal(id: "hint-\(edge.rawValue)", displayID: main.id, edge: edge,
                                start: 250, end: 650, label: "Synthetic", manual: false, universalControl: true)
            let hint = DisplayMapGeometry.remoteHints(displays: [main], portals: [portal])[0]
            expect(!hint.frame.intersects(main.frame), "remote diagram does not overlap actual screen for \(edge)")
            switch edge {
            case .left: expect(hint.frame.maxX < main.frame.minX, "left destination")
            case .right: expect(hint.frame.minX > main.frame.maxX, "right destination")
            case .top: expect(hint.frame.minY > main.frame.maxY, "top destination")
            case .bottom: expect(hint.frame.maxY < main.frame.minY, "bottom destination")
            }
        }
        let collisionHints = DisplayMapGeometry.remoteHints(displays: [main, ucAbove], portals: [abovePortal!,
            Portal(id: "second-remote", displayID: ucAbove.id, edge: .top, start: 1000, end: 1500,
                   label: "Synthetic", manual: false, universalControl: true)])
        expect(collisionHints.count == 2 && !collisionHints[0].frame.intersects(collisionHints[1].frame), "multiple destination hints remain separately visible")

        let legacy: [String: Any] = ["enabled": false, "automatic": false, "nearOnly": true, "thickness": 3,
                                     "markers": [try JSONSerialization.jsonObject(with: data)]]
        let migrated = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        expect(!migrated.enabled && !migrated.automatic && migrated.nearOnly && migrated.thickness == 3, "v1 upgrade preserves existing switches and thickness")
        expect(migrated.automaticUniversalControl && migrated.markers == [marker], "v1 upgrade enables UC without losing manual markers")
        var saved = migrated; saved.automaticUniversalControl = false
        expect(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(saved)).automaticUniversalControl == false, "UC disabled preference persists")
        expect(try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8)).automaticUniversalControl, "new preferences enable automatic UC")
        expect(migrated.showWhenLocked && migrated.alwaysShowWhenLocked && migrated.nearOnly,
               "lock-screen defaults preserve the existing desktop proximity preference")
        var lockPreferences = migrated
        lockPreferences.showWhenLocked = false; lockPreferences.alwaysShowWhenLocked = false
        let savedLockPreferences = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(lockPreferences))
        expect(!savedLockPreferences.showWhenLocked && !savedLockPreferences.alwaysShowWhenLocked,
               "lock-screen display and proximity choices survive saving")
        expect(migrated.displayMode == .nearEdges, "legacy proximity setting migrates to its matching mode")
        expect(try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8)).displayMode == .always,
               "new installation keeps always-visible default")
        for mode in EdgeDisplayMode.allCases {
            var p = migrated; p.displayMode = mode
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
            expect(restored.displayMode == mode && restored.markers == migrated.markers && restored.thickness == 3,
                   "each display mode persists without losing existing settings")
        }
        expect(try JSONDecoder().decode(Preferences.self, from: Data("{\"nearOnly\":true,\"displayMode\":\"pointerScreen\"}".utf8)).displayMode == .pointerScreen,
               "explicit mode takes priority over legacy proximity field")
        expect(try JSONDecoder().decode(Preferences.self, from: Data("{\"nearOnly\":true,\"displayMode\":\"futureMode\"}".utf8)).displayMode == .nearEdges,
               "unknown mode falls back to legacy setting without discarding preferences")

        expect(migrated.extendedAppearance == .legacyExtended && migrated.universalAppearance == .legacyUniversal,
               "upgrades retain the original two gradient palettes")
        expect(Preferences().extendedAppearance == .softExtended && Preferences().universalAppearance == .softUniversal,
               "fresh installations use the softer independent glass styles")
        var styled = migrated
        styled.extendedAppearance = EdgeAppearance(material: .solid, color: .mint, opacity: 0.45)
        styled.universalAppearance = EdgeAppearance(material: .gradient, gradient: .custom,
            gradientStart: .rose, gradientEnd: .blue, opacity: 0.7)
        let restoredStyle = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(styled))
        expect(restoredStyle.extendedAppearance == styled.extendedAppearance && restoredStyle.universalAppearance == styled.universalAppearance,
               "independent channel colors, custom gradient and opacity survive restart")
        expect(restoredStyle.markers == migrated.markers && restoredStyle.thickness == migrated.thickness && restoredStyle.displayMode == migrated.displayMode,
               "saving appearances preserves markers, width and visibility mode")
        expect(styled.appearance(for: ucTop) == styled.universalAppearance && styled.appearance(for: pair[0]) == styled.extendedAppearance,
               "automatic UC and extension passages select their respective styles")
        expect(styled.appearance(for: Portal(id: "manual-style", displayID: main.id, edge: .left, start: 0, end: 200, label: "Synthetic", manual: true)) == styled.universalAppearance,
               "manual markers retain the UC style association")
        expect(styled.extendedAppearance.colors == [.mint, .mint] && styled.universalAppearance.colors == [.rose, .blue],
               "solid and custom gradient colors reach the renderer without preset substitution")
        for preset in EdgeGradient.allCases where preset != .custom {
            let style = EdgeAppearance(material: .gradient, gradient: preset)
            expect(style.colors.count >= 2 && style.colors.first != style.colors.last, "gradient preset has distinct endpoints: \(preset)")
        }
        let damagedStyle = try JSONDecoder().decode(Preferences.self, from: Data("{\"thickness\":7,\"displayMode\":\"pointerScreen\",\"extendedAppearance\":\"bad\",\"universalAppearance\":{\"material\":\"future\",\"color\":null,\"opacity\":10}}".utf8))
        expect(damagedStyle.thickness == 7 && damagedStyle.displayMode == .pointerScreen && damagedStyle.extendedAppearance == .legacyExtended,
               "invalid appearance does not reset unrelated user preferences")
        expect(damagedStyle.universalAppearance.material == .glass && damagedStyle.universalAppearance.opacity == 1,
               "unknown material and out-of-range opacity have safe fallbacks")
        expect(EdgeColor(-1, 2, .nan) == EdgeColor(0, 1, 0.5), "invalid color channels cannot escape sRGB bounds")
        expect(EdgeAppearance(opacity: -1).effectiveOpacity == 0.15 && EdgeAppearance(opacity: .nan).effectiveOpacity == 0.8,
               "invalid runtime opacity cannot hide a configured edge completely")

        func visible(_ point: CGPoint, cursor: Bool? = true, mode: EdgeDisplayMode = .pointerScreen,
                     screens: [DisplayInfo] = [main, right], locked: Bool = false, lockAlways: Bool = true) -> Set<String> {
            OverlayVisibility.visibleDisplayIDs(mode: mode, displays: screens,
                pointer: PointerSnapshot(location: point, isVisible: cursor), screenLocked: locked, alwaysShowWhenLocked: lockAlways)
        }
        let mainCenter = CGPoint(x: 720, y: 450), rightCenter = CGPoint(x: 2400, y: 740)
        expect(visible(mainCenter) == [main.id], "screen center reveals only that screen's passages")
        expect(visible(rightCenter) == [right.id], "moving onto a second display switches the visible screen")
        expect(visible(mainCenter, cursor: false).isEmpty, "UC departure hides stale local coordinates")
        expect(visible(mainCenter, cursor: nil).isEmpty, "unavailable visibility signal cannot show stale edges")
        expect(visible(mainCenter) == [main.id], "UC return restores the local screen without an activity timeout")
        expect(visible(CGPoint(x: 1440, y: 450)) == [right.id], "shared vertical boundary belongs to exactly one screen")
        expect(visible(CGPoint(x: 720, y: 900), screens: [above, main]) == [main.id], "top row belongs to the lower screen after AppKit y flip")
        expect(visible(CGPoint(x: 300, y: 901), screens: [main, above]) == [above.id], "crossing above switches to the upper screen")
        expect(visible(CGPoint(x: -50, y: -400), screens: [main, below]) == [below.id], "negative display origins work")
        expect(visible(CGPoint(x: -50, y: 0), screens: [main, below]) == [below.id], "negative-origin screen includes its top row")
        expect(visible(CGPoint(x: 1800, y: 50)).isEmpty, "desktop gaps do not select the nearest screen")
        expect(visible(CGPoint(x: 9000, y: 9000)).isEmpty, "off-desktop coordinates hide all screens")
        expect(visible(CGPoint(x: CGFloat.nan, y: 0)).isEmpty, "invalid pointer coordinates are rejected")
        expect(visible(mainCenter, screens: []).isEmpty, "no display snapshot means no visible edge")
        expect(visible(mainCenter, screens: [right]).isEmpty, "unplugged screen is not retained")
        expect(visible(mainCenter, screens: [mirrorDesktop]) == [mirrorDesktop.id], "mirrored desktop selects only the active display identity")
        expect(visible(mainCenter, cursor: false, mode: .always) == [main.id, right.id], "always mode remains independent of cursor visibility")
        expect(visible(mainCenter, mode: .nearEdges).isEmpty, "proximity mode still hides at the center")
        expect(visible(CGPoint(x: 20, y: 450), mode: .nearEdges) == [main.id, right.id], "proximity mode still reveals all displays together")
        expect(visible(mainCenter, mode: .nearEdges, locked: true) == [main.id, right.id], "lock-screen constant display still overrides proximity")
        expect(visible(mainCenter, mode: .nearEdges, locked: true, lockAlways: false).isEmpty, "lock-screen proximity choice is preserved")
        expect(visible(mainCenter, locked: true) == [main.id], "lock-screen constant option cannot reveal non-pointer screens")
        expect(visible(mainCenter, cursor: false, locked: true).isEmpty, "lock-screen constant option cannot reveal a remote pointer")
        print("PASS: \(checks) geometry and configuration checks")
    }
}
