import Foundation
import CoreGraphics

struct EdgeColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        func channel(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0.5 }
        self.red = channel(red); self.green = channel(green); self.blue = channel(blue)
    }
    private enum CodingKeys: String, CodingKey { case red, green, blue }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try c.decode(Double.self, forKey: .red), try c.decode(Double.self, forKey: .green),
                  try c.decode(Double.self, forKey: .blue))
    }
    var components: [CGFloat] { [CGFloat(red), CGFloat(green), CGFloat(blue), 1] }
    static let frost = EdgeColor(0.91, 0.94, 0.98)
    static let blue = EdgeColor(0.38, 0.66, 0.96)
    static let mint = EdgeColor(0.36, 0.78, 0.67)
    static let lavender = EdgeColor(0.68, 0.59, 0.91)
    static let rose = EdgeColor(0.90, 0.52, 0.64)
    static let amber = EdgeColor(0.94, 0.70, 0.34)
    static let graphite = EdgeColor(0.32, 0.37, 0.44)
    static let swatches: [(String, EdgeColor)] = [
        ("霜白", .frost), ("雾蓝", .blue), ("薄荷", .mint), ("淡紫", .lavender),
        ("玫瑰", .rose), ("琥珀", .amber), ("石墨", .graphite)
    ]
}

enum EdgeMaterial: String, Codable, CaseIterable, Identifiable {
    case gradient, solid
    var id: String { rawValue }
    var title: String {
        switch self { case .gradient: return "渐变"; case .solid: return "纯色" }
    }
}

enum EdgeGradient: String, Codable, CaseIterable, Identifiable {
    case ocean, sunset, aurora, lavender, graphite, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ocean: return "海岸"; case .sunset: return "日落"; case .aurora: return "极光"
        case .lavender: return "暮紫"; case .graphite: return "月光"; case .custom: return "自定义"
        }
    }
    var colors: [EdgeColor] {
        switch self {
        case .ocean: return PortalPalette.automatic.map { EdgeColor(Double($0[0]), Double($0[1]), Double($0[2])) }
        case .sunset: return PortalPalette.manual.map { EdgeColor(Double($0[0]), Double($0[1]), Double($0[2])) }
        case .aurora: return [EdgeColor(0.35, 0.83, 0.73), EdgeColor(0.40, 0.69, 0.94), EdgeColor(0.67, 0.57, 0.90)]
        case .lavender: return [EdgeColor(0.67, 0.73, 0.96), EdgeColor(0.75, 0.60, 0.87), EdgeColor(0.91, 0.66, 0.73)]
        case .graphite: return [EdgeColor(0.80, 0.87, 0.94), EdgeColor(0.59, 0.67, 0.77), EdgeColor(0.38, 0.46, 0.58)]
        case .custom: return [.blue, .lavender]
        }
    }
}

struct EdgeAppearance: Codable, Equatable {
    var material: EdgeMaterial = .solid
    var gradient: EdgeGradient = .aurora
    var color: EdgeColor = .frost
    var gradientStart: EdgeColor = .blue
    var gradientEnd: EdgeColor = .lavender
    var opacity: Double = 0.8

    static let softExtended = EdgeAppearance(color: .frost)
    static let softUniversal = EdgeAppearance(color: .blue)
    static let legacyExtended = EdgeAppearance(material: .gradient, gradient: .ocean, opacity: 1)
    static let legacyUniversal = EdgeAppearance(material: .gradient, gradient: .sunset, opacity: 1)

    var colors: [EdgeColor] {
        material == .gradient ? (gradient == .custom ? [gradientStart, gradientEnd] : gradient.colors) : [color, color]
    }
    var effectiveOpacity: Double { opacity.isFinite ? min(1, max(0.15, opacity)) : 0.8 }

    private enum CodingKeys: String, CodingKey { case material, gradient, color, gradientStart, gradientEnd, opacity }
    init(material: EdgeMaterial = .solid, gradient: EdgeGradient = .aurora, color: EdgeColor = .frost,
         gradientStart: EdgeColor = .blue, gradientEnd: EdgeColor = .lavender, opacity: Double = 0.8) {
        self.material = material; self.gradient = gradient; self.color = color
        self.gradientStart = gradientStart; self.gradientEnd = gradientEnd; self.opacity = opacity
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Retired "glass" values migrate to the same color and opacity in solid mode.
        material = (try c.decodeIfPresent(String.self, forKey: .material)).flatMap(EdgeMaterial.init(rawValue:)) ?? .solid
        gradient = (try c.decodeIfPresent(String.self, forKey: .gradient)).flatMap(EdgeGradient.init(rawValue:)) ?? .aurora
        color = (try? c.decode(EdgeColor.self, forKey: .color)) ?? .frost
        gradientStart = (try? c.decode(EdgeColor.self, forKey: .gradientStart)) ?? .blue
        gradientEnd = (try? c.decode(EdgeColor.self, forKey: .gradientEnd)) ?? .lavender
        let raw = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.8
        opacity = raw.isFinite ? min(1, max(0.15, raw)) : 0.8
    }
}
