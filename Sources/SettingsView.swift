import SwiftUI

func passageGradient(manual: Bool, vertical: Bool = false) -> LinearGradient {
    let colors = PortalPalette.stops(manual: manual).map { Color(.sRGB, red: Double($0[0]), green: Double($0[1]), blue: Double($0[2]), opacity: 1) }
    return LinearGradient(colors: colors, startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing)
}

let mint = Color(red: 0.12, green: 0.64, blue: 0.51)

enum SettingsPage: String, CaseIterable, Identifiable {
    case appearance, channels, markers, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appearance: return "边缘显示"
        case .channels: return "屏幕与通道"
        case .markers: return "手动标记"
        case .general: return "锁屏与启动"
        }
    }
    var icon: String {
        switch self {
        case .appearance: return "cursorarrow"
        case .channels: return "display.2"
        case .markers: return "slider.horizontal.3"
        case .general: return "lock"
        }
    }
    var subtitle: String {
        switch self {
        case .appearance: return "选择边缘出现的时机，调整线条样式。"
        case .channels: return "查看屏幕排列与可以跨越的通道。"
        case .markers: return "为需要额外提示的位置补充标记。"
        case .general: return "设置锁屏行为与应用启动方式。"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var page: SettingsPage

    init(model: AppModel, initialPage: SettingsPage = .appearance) {
        self.model = model
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(page.title).font(.system(size: 23, weight: .semibold))
                            Text(page.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        pageContent
                        if let warning = model.configWarning {
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(26).frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }.background(Color(nsColor: .windowBackgroundColor))
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "cursorarrow.rays")
                Text("提示线穿透点击，不影响键鼠操作")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .monospacedDigit()
            }.font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 22).padding(.vertical, 12)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 610)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(mint)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(mint)
                .frame(width: 42, height: 42).background(mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text("跨屏边缘").font(.system(size: 17, weight: .semibold))
                Text("让跨屏通道一目了然").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("显示边缘", isOn: $model.preferences.enabled)
                .toggleStyle(.switch).controlSize(.small).accessibilityIdentifier("overlayEnabled")
        }.padding(.horizontal, 22).padding(.vertical, 15)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsPage.allCases) { item in
                Button { page = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon).font(.system(size: 14)).frame(width: 20)
                        Text(item.title).font(.system(size: 13, weight: page == item ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }.foregroundStyle(page == item ? mint : Color.primary)
                        .padding(.horizontal, 12).frame(height: 38)
                        .background(page == item ? mint.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("settingsPage-\(item.rawValue)")
                    .accessibilityValue(page == item ? "已选中" : "")
            }
            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                Text("\(model.displays.count) 块本机屏幕")
                Text(model.preferences.enabled ? "边缘提示已开启" : "边缘提示已暂停")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(12)
        }.padding(12).frame(width: 166).frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    @ViewBuilder private var pageContent: some View {
        switch page {
        case .appearance: AppearanceSettings(model: model)
        case .channels: ChannelSettings(model: model)
        case .markers: ManualSettings(model: model)
        case .general: GeneralSettings(model: model)
        }
    }
}


struct MarkerEditor: View {
    @Binding var marker: ManualMarker
    let displays: [DisplayInfo]
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Toggle("启用标记", isOn: $marker.enabled).labelsHidden().help("显示或隐藏这段手动标记")
                TextField("目标设备名称", text: $marker.label).textFieldStyle(.roundedBorder)
                Text("手动").font(.caption2).foregroundStyle(.orange)
                Button(action: remove) { Image(systemName: "trash") }.buttonStyle(.borderless).help("删除这段标记")
                    .accessibilityLabel("删除标记")
            }
            HStack {
                Picker("本机屏幕", selection: $marker.displayID) {
                    ForEach(displays) { display in Text(display.name).tag(display.id) }
                    if !displays.contains(where: { $0.id == marker.displayID }) {
                        Text("原屏幕未连接").tag(marker.displayID)
                    }
                }
                Picker("边缘", selection: $marker.edge) {
                    ForEach(Edge.allCases) { edge in Text(edge.title).tag(edge) }
                }.frame(width: 155)
            }
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("起点").font(.caption).frame(width: 32, alignment: .leading)
                    Slider(value: Binding(get: { marker.start * 100 }, set: { marker.start = min($0.rounded() / 100, marker.end - 0.01) }), in: 0...99)
                        .accessibilityLabel("标记起点")
                    Text("\(Int((marker.start * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 38, alignment: .trailing)
                }
                HStack(spacing: 12) {
                    Text("终点").font(.caption).frame(width: 32, alignment: .leading)
                    Slider(value: Binding(get: { marker.end * 100 }, set: { marker.end = max($0.rounded() / 100, marker.start + 0.01) }), in: 1...100)
                        .accessibilityLabel("标记终点")
                    Text("\(Int((marker.end * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 38, alignment: .trailing)
                }
            }
            Text(marker.edge.vertical ? "0% 是屏幕顶端，100% 是底端；边缘线会随调整实时更新。" : "0% 是屏幕左端，100% 是右端；边缘线会随调整实时更新。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(16).background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DisplayMap: View {
    let displays: [DisplayInfo]
    let portals: [Portal]
    private let remoteColor = Color(red: 0.91, green: 0.35, blue: 0.08)

    var body: some View {
        let hints = DisplayMapGeometry.remoteHints(displays: displays, portals: portals)
        GeometryReader { geometry in
            let union = (displays.map(\.frame) + hints.map(\.frame)).reduce(CGRect.null) { $0.union($1) }
            if !union.isNull && union.width > 0 && union.height > 0 {
                let scale = min((geometry.size.width - 56) / union.width, (geometry.size.height - 36) / union.height)
                let origin = CGPoint(x: (geometry.size.width - union.width * scale) / 2,
                                     y: (geometry.size.height - union.height * scale) / 2)
                let point: (CGPoint) -> CGPoint = { p in
                    CGPoint(x: origin.x + (p.x - union.minX) * scale, y: origin.y + (union.maxY - p.y) * scale)
                }
                ZStack(alignment: .topLeading) {
                    ForEach(hints) { hint in
                        Path { path in
                            path.move(to: point(hint.source)); path.addLine(to: point(hint.destination))
                        }.stroke(remoteColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(remoteColor)
                            .rotationEffect(.degrees(hint.source.x == hint.destination.x ? 0 : 90))
                            .padding(3).background(Color(nsColor: .windowBackgroundColor), in: Circle())
                            .position(point(CGPoint(x: (hint.source.x + hint.destination.x) / 2,
                                                    y: (hint.source.y + hint.destination.y) / 2)))
                    }
                    ForEach(displays) { display in
                        let f = display.frame
                        RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.25), lineWidth: 1))
                            .overlay(Text(display.name).font(.system(size: 11, weight: .medium)).lineLimit(2).minimumScaleFactor(0.7).padding(8))
                            .frame(width: f.width * scale, height: f.height * scale)
                            .position(point(CGPoint(x: f.midX, y: f.midY)))
                    }
                    ForEach(hints) { hint in
                        RoundedRectangle(cornerRadius: 7).fill(remoteColor.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(remoteColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
                            .overlay(VStack(spacing: 4) {
                                Text("通用控制对端").font(.system(size: 11, weight: .semibold)).foregroundStyle(remoteColor)
                                Text("示意 · 非实际比例").font(.system(size: 9)).foregroundStyle(.secondary)
                            }.lineLimit(1).minimumScaleFactor(0.7).padding(6))
                            .frame(width: hint.frame.width * scale, height: hint.frame.height * scale)
                            .position(point(CGPoint(x: hint.frame.midX, y: hint.frame.midY)))
                            .help("这里表示该通道通向的另一台 Mac 或 iPad；远端屏幕尺寸和设备名称尚未读取。")
                    }
                    ForEach(portals) { portal in
                        if let display = displays.first(where: { $0.id == portal.displayID }) {
                            let rect = portal.rect(on: display, thickness: 4 / scale)
                            RoundedRectangle(cornerRadius: 2).fill(passageGradient(manual: portal.usesWarmPalette, vertical: portal.edge.vertical))
                                .frame(width: max(4, rect.width * scale), height: max(4, rect.height * scale))
                                .position(point(CGPoint(x: rect.midX, y: rect.midY)))
                                .help("\(portal.edge.title) → \(portal.label)")
                        }
                    }
                }
            } else {
                Text("等待系统显示器信息…").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("屏幕排列预览，\(displays.count) 块本机屏幕，\(hints.count) 处通用控制对端示意，\(portals.count) 段边缘标记")
    }
}
