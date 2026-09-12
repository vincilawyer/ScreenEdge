import Foundation

struct Preferences: Codable {
    var enabled = true
    var automatic = true
    var automaticUniversalControl = true
    var nearOnly = false
    var thickness: Double = 4
    var markers: [ManualMarker] = []

    init() {}
    enum CodingKeys: String, CodingKey { case enabled, automatic, automaticUniversalControl, nearOnly, thickness, markers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        automatic = try c.decodeIfPresent(Bool.self, forKey: .automatic) ?? true
        automaticUniversalControl = try c.decodeIfPresent(Bool.self, forKey: .automaticUniversalControl) ?? true
        nearOnly = try c.decodeIfPresent(Bool.self, forKey: .nearOnly) ?? false
        thickness = min(8, max(2, try c.decodeIfPresent(Double.self, forKey: .thickness) ?? 4))
        markers = try c.decodeIfPresent([ManualMarker].self, forKey: .markers) ?? []
    }
}
