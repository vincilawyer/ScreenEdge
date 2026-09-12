import Foundation

struct Preferences: Codable {
    var enabled = true
    var automatic = true
    var automaticUniversalControl = true
    var displayMode: EdgeDisplayMode = .always
    // Preserve source compatibility and downgrade behavior for the original setting.
    var nearOnly: Bool {
        get { displayMode == .nearEdges }
        set { displayMode = newValue ? .nearEdges : .always }
    }
    var showMenuBarIcon = true
    var showWhenLocked = true
    var alwaysShowWhenLocked = true
    var thickness: Double = 4
    var extendedAppearance: EdgeAppearance = .softExtended
    var universalAppearance: EdgeAppearance = .softUniversal
    var markers: [ManualMarker] = []

    init() {}
    enum CodingKeys: String, CodingKey { case enabled, automatic, automaticUniversalControl, displayMode, nearOnly, showMenuBarIcon, showWhenLocked, alwaysShowWhenLocked, thickness, extendedAppearance, universalAppearance, markers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        automatic = try c.decodeIfPresent(Bool.self, forKey: .automatic) ?? true
        automaticUniversalControl = try c.decodeIfPresent(Bool.self, forKey: .automaticUniversalControl) ?? true
        let legacyMode: EdgeDisplayMode = (try c.decodeIfPresent(Bool.self, forKey: .nearOnly) ?? false) ? .nearEdges : .always
        displayMode = try c.decodeIfPresent(String.self, forKey: .displayMode).flatMap(EdgeDisplayMode.init(rawValue:)) ?? legacyMode
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        showWhenLocked = try c.decodeIfPresent(Bool.self, forKey: .showWhenLocked) ?? true
        alwaysShowWhenLocked = try c.decodeIfPresent(Bool.self, forKey: .alwaysShowWhenLocked) ?? true
        thickness = min(8, max(2, try c.decodeIfPresent(Double.self, forKey: .thickness) ?? 4))
        // Existing installations keep their original colors until the user chooses a style.
        extendedAppearance = (try? c.decode(EdgeAppearance.self, forKey: .extendedAppearance)) ?? .legacyExtended
        universalAppearance = (try? c.decode(EdgeAppearance.self, forKey: .universalAppearance)) ?? .legacyUniversal
        markers = try c.decodeIfPresent([ManualMarker].self, forKey: .markers) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(automatic, forKey: .automatic)
        try c.encode(automaticUniversalControl, forKey: .automaticUniversalControl)
        try c.encode(displayMode, forKey: .displayMode)
        try c.encode(nearOnly, forKey: .nearOnly)
        try c.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try c.encode(showWhenLocked, forKey: .showWhenLocked)
        try c.encode(alwaysShowWhenLocked, forKey: .alwaysShowWhenLocked)
        try c.encode(thickness, forKey: .thickness)
        try c.encode(extendedAppearance, forKey: .extendedAppearance)
        try c.encode(universalAppearance, forKey: .universalAppearance)
        try c.encode(markers, forKey: .markers)
    }

    func appearance(for portal: Portal) -> EdgeAppearance {
        portal.usesWarmPalette ? universalAppearance : extendedAppearance
    }
}
