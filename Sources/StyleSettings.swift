import SwiftUI
import AppKit

extension EdgeColor {
    var swiftUIColor: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

enum StyleTarget: String, CaseIterable, Identifiable {
    case extended, universal
    var id: String { rawValue }
    var title: String { self == .extended ? "扩展屏" : "通用控制" }
    var icon: String { self == .extended ? "display.2" : "laptopcomputer.and.ipad" }
}

struct StyleSettings: View {
    @ObservedObject var model: AppModel
    @State private var target: StyleTarget = .extended
    private var selection: Binding<EdgeAppearance> {
        target == .extended ? $model.preferences.extendedAppearance : $model.preferences.universalAppearance
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                previewCard(.extended, style: model.preferences.extendedAppearance)
                previewCard(.universal, style: model.preferences.universalAppearance)
            }
            StyleEditor(title: target.title + "外观", appearance: selection).id(target)
            HStack(spacing: 16) {
                Button("恢复此类默认外观") {
                    selection.wrappedValue = target == .extended ? .softExtended : .softUniversal
                }.buttonStyle(.borderless)
                Spacer()
                Button("在屏幕上预览") { model.onPreview?() }.disabled(model.screenLocked)
            }.font(.system(size: 12))
            Text("预览 4 秒：左侧显示扩展屏样式，右侧显示通用控制样式。两台 Mac 的配色分别保存；手动标记沿用通用控制外观。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func previewCard(_ item: StyleTarget, style: EdgeAppearance) -> some View {
        Button { target = item } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: item.icon).font(.system(size: 13))
                    Text(item.title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: target == item ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(target == item ? Color.accentColor : Color.secondary.opacity(0.35))
                }
                StyleDesktopPreview(appearance: style, thickness: model.preferences.thickness)
                    .frame(height: 76).clipShape(RoundedRectangle(cornerRadius: 10))
                HStack {
                    Text(style.material.title)
                    Spacer()
                    Text("\(Int((style.effectiveOpacity * 100).rounded()))%").monospacedDigit()
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(target == item ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: target == item ? 1.5 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityIdentifier("styleTarget-\(item.rawValue)")
            .accessibilityLabel("编辑\(item.title)外观").accessibilityValue(target == item ? "已选中" : "")
    }
}

struct StyleEditor: View {
    let title: String
    @Binding var appearance: EdgeAppearance
    private func colorBinding(_ keyPath: WritableKeyPath<EdgeAppearance, EdgeColor>) -> Binding<EdgeColor> {
        Binding(get: { appearance[keyPath: keyPath] }, set: { appearance[keyPath: keyPath] = $0 })
    }
    var body: some View {
        SettingsCard(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("材质", selection: $appearance.material) {
                    ForEach(EdgeMaterial.allCases) { material in Text(material.title).tag(material) }
                }.pickerStyle(.segmented).accessibilityIdentifier("edgeMaterial")
                if appearance.material == .gradient {
                    gradientChoices
                    if appearance.gradient == .custom {
                        HStack {
                            LabeledColorWell(title: "起始色", color: colorBinding(\.gradientStart))
                            Spacer(minLength: 24)
                            LabeledColorWell(title: "结束色", color: colorBinding(\.gradientEnd))
                        }.font(.system(size: 12))
                    }
                } else {
                    colorChoices
                }
                Divider()
                HStack {
                    Text("不透明度").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int((appearance.effectiveOpacity * 100).rounded()))%").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { appearance.effectiveOpacity }, set: { appearance.opacity = ($0 * 20).rounded() / 20 }), in: 0.15...1)
                    .accessibilityLabel("边缘不透明度")
                Text(appearance.material == .glass ? "轻透磨砂，随背景呈现细微变化。开启系统“减少透明度”时，会使用清晰的实色材质。" : "降低不透明度，让提示线更轻盈。颜色和材质会立即应用到对应通道。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(16)
        }
    }
    private var colorChoices: some View {
        HStack(spacing: 10) {
            ForEach(EdgeColor.swatches, id: \.0) { name, color in
                Button { appearance.color = color } label: {
                    Circle().fill(color.swiftUIColor).frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .padding(3)
                        .overlay(Circle().stroke(appearance.color == color ? Color.accentColor : .clear, lineWidth: 1.5))
                }.buttonStyle(.plain).help(name).accessibilityLabel(name)
                    .accessibilityValue(appearance.color == color ? "已选中" : "")
            }
            Spacer(minLength: 0)
            LabeledColorWell(title: "自选", color: colorBinding(\.color)).font(.system(size: 12))
        }.padding(.vertical, 2)
    }
    private var gradientChoices: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(EdgeGradient.allCases) { preset in
                Button { appearance.gradient = preset } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule().fill(LinearGradient(colors: (preset == .custom ? [appearance.gradientStart, appearance.gradientEnd] : preset.colors).map(\.swiftUIColor), startPoint: .leading, endPoint: .trailing))
                            .frame(height: 8)
                        HStack {
                            Text(preset.title)
                            Spacer()
                            if appearance.gradient == preset { Image(systemName: "checkmark").fontWeight(.semibold) }
                        }.font(.system(size: 11)).foregroundStyle(appearance.gradient == preset ? Color.accentColor : Color.secondary)
                    }.padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(appearance.gradient == preset ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityLabel(preset.title + "渐变")
                    .accessibilityValue(appearance.gradient == preset ? "已选中" : "")
            }
        }
    }
}

struct StyleStripSample: NSViewRepresentable {
    let appearance: EdgeAppearance
    var vertical = false
    func makeNSView(context: Context) -> EdgeStripView {
        EdgeStripView(frame: .zero, appearance: appearance, vertical: vertical, blendingMode: .withinWindow)
    }
    func updateNSView(_ view: EdgeStripView, context: Context) { view.updateAppearance(appearance) }
}

struct StyleDesktopPreview: NSViewRepresentable {
    let appearance: EdgeAppearance
    let thickness: Double
    func makeNSView(context: Context) -> StyleDesktopView { StyleDesktopView() }
    func updateNSView(_ view: StyleDesktopView, context: Context) {
        view.strip.updateAppearance(appearance); view.thickness = thickness; view.needsLayout = true
    }
}

final class StyleDesktopView: NSView {
    let strip = EdgeStripView(frame: .zero, appearance: .softExtended, vertical: false, blendingMode: .withinWindow)
    var thickness: Double = 4
    override init(frame: NSRect) {
        super.init(frame: frame)
        addSubview(strip)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        strip.frame = CGRect(x: 14, y: 9, width: max(0, bounds.width - 28), height: thickness)
    }
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let colors: [NSColor] = dark ? [.init(srgbRed: 0.12, green: 0.20, blue: 0.33, alpha: 1), .init(srgbRed: 0.34, green: 0.29, blue: 0.48, alpha: 1)] :
            [.init(srgbRed: 0.72, green: 0.84, blue: 0.94, alpha: 1), .init(srgbRed: 0.89, green: 0.81, blue: 0.89, alpha: 1)]
        NSGradient(colors: colors)?.draw(in: bounds, angle: 20)
        NSColor.white.withAlphaComponent(dark ? 0.05 : 0.15).setFill()
        NSBezierPath(ovalIn: CGRect(x: bounds.width * 0.35, y: -32, width: bounds.width, height: 140)).fill()
        let frame = CGRect(x: 22, y: 25, width: max(0, bounds.width - 44), height: max(0, bounds.height - 39))
        NSColor.white.withAlphaComponent(dark ? 0.10 : 0.34).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 7, yRadius: 7).fill()
        NSColor.white.withAlphaComponent(dark ? 0.20 : 0.55).setFill()
        for i in 0..<3 { NSBezierPath(ovalIn: CGRect(x: frame.minX + 9 + CGFloat(i) * 7, y: frame.maxY - 11, width: 3.5, height: 3.5)).fill() }
    }
}


struct LabeledColorWell: View {
    let title: String
    @Binding var color: EdgeColor
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            NativeColorWell(title: title, color: $color).frame(width: 30, height: 26)
        }.fixedSize()
    }
}

struct NativeColorWell: NSViewRepresentable {
    let title: String
    @Binding var color: EdgeColor
    func makeCoordinator() -> Coordinator { Coordinator(color: $color) }
    func makeNSView(context: Context) -> ColorPickerButton {
        let button = ColorPickerButton(frame: .zero)
        button.well.target = context.coordinator
        button.well.action = #selector(Coordinator.changed(_:))
        return button
    }
    func updateNSView(_ button: ColorPickerButton, context: Context) {
        context.coordinator.color = $color
        button.updateSwatch(NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1))
        button.setAccessibilityLabel("选择" + title)
        button.toolTip = "打开系统颜色选择器"
    }
    static func dismantleNSView(_ button: ColorPickerButton, coordinator: Coordinator) { button.well.deactivate() }
    final class Coordinator: NSObject {
        var color: Binding<EdgeColor>
        init(color: Binding<EdgeColor>) { self.color = color }
        @objc func changed(_ sender: NSColorWell) {
            guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
            color.wrappedValue = EdgeColor(rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
        }
    }
}
