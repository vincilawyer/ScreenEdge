import SwiftUI

private func passageGradient(manual: Bool, vertical: Bool = false) -> LinearGradient {
    let colors = PortalPalette.stops(manual: manual).map { Color(.sRGB, red: Double($0[0]), green: Double($0[1]), blue: Double($0[2]), opacity: 1) }
    return LinearGradient(colors: colors, startPoint: vertical ? .top : .leading, endPoint: vertical ? .bottom : .trailing)
}

private let mint = Color(red: 0.12, green: 0.64, blue: 0.51)

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 28, weight: .medium)).foregroundStyle(mint)
                    .frame(width: 54, height: 54).background(mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text("跨屏边缘").font(.system(size: 23, weight: .semibold))
                    Text("沿着渐变，找到跨屏的通道。").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("显示边缘", isOn: $model.preferences.enabled).toggleStyle(.switch)
                    .accessibilityIdentifier("overlayEnabled")
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("屏幕与通道").font(.headline)
                            Spacer()
                            Text("\(model.displays.count) 块本机屏幕 · \(model.universalControlPortals.count) 处通用控制入口")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        DisplayMap(displays: model.displays, portals: model.portals)
                            .frame(height: model.universalControlPortals.isEmpty ? 200 : 300)
                            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                        HStack(spacing: 18) {
                            Label { Text("蓝绿渐变 · 扩展屏通道") } icon: { Capsule().fill(passageGradient(manual: false)).frame(width: 28, height: 5) }
                            Label { Text("橙红渐变 · 通用控制通道") } icon: { Capsule().fill(passageGradient(manual: true)).frame(width: 28, height: 5) }
                            Spacer()
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    Text("扩展屏同色位置相互对应；通用控制按本机通道范围渐变标记。另一台 Mac 也需运行本应用才能显示对端提示。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("自动标记扩展屏交界", isOn: $model.preferences.automatic)
                        VStack(alignment: .leading, spacing: 5) {
                            Toggle("自动标记通用控制通道", isOn: $model.preferences.automaticUniversalControl)
                            Text(model.universalControlStatus).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Toggle("靠近任意屏幕边缘时显示全部通道", isOn: $model.preferences.nearOnly)
                            .help("靠近任意屏幕的任意边缘约 110 点时，全部提示线一起显示；离开所有边缘后一起隐藏。")
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("锁屏时显示边缘", isOn: $model.preferences.showWhenLocked)
                            if model.preferences.showWhenLocked {
                                Toggle("锁屏时保持常显", isOn: $model.preferences.alwaysShowWhenLocked)
                                    .padding(.leading, 20)
                            }
                            Text("适用于登录后锁屏；重启后的首次登录界面不显示。通用控制断开时，其自动提示会清除。")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            if let message = model.lockScreenMessage {
                                Text(message).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        HStack {
                            Text("线条粗细").frame(width: 76, alignment: .leading)
                            Slider(value: $model.preferences.thickness, in: 2...8, step: 1)
                            Text("\(Int(model.preferences.thickness)) 点").monospacedDigit().foregroundStyle(.secondary).frame(width: 36)
                            Button("预览 4 秒") { model.onPreview?() }
                                .help("临时在每块本机屏幕右侧显示示例线，预览不会保存成通道。")
                        }
                    }.padding(16).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("手动补充标记").font(.headline)
                            Spacer()
                            Button { model.addMarker() } label: { Label("添加标记", systemImage: "plus") }
                                .disabled(model.displays.isEmpty)
                        }
                        Text("自动识别后无需添加。若需要额外提示，可按系统排列手动标记；手动标记需自行开关。")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if model.preferences.markers.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "laptopcomputer.and.ipad").font(.title2).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("当前没有手动标记").font(.system(size: 13, weight: .medium))
                                    Text("已连接的通用控制通道会自动显示。")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(18).frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                        }
                        ForEach($model.preferences.markers) { $marker in
                            MarkerEditor(marker: $marker, displays: model.displays) { model.removeMarker(marker.id) }
                        }
                    }
                    if let warning = model.configWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("显示菜单栏图标", isOn: $model.preferences.showMenuBarIcon)
                        Text("隐藏后边缘提示仍会运行；重新打开“跨屏边缘.app”即可进入设置并恢复图标。")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .top) {
                        Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                        Spacer()
                        Button("系统显示器设置…") { model.openDisplaySettings() }
                    }
                    if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                }.padding(24)
            }
            Divider()
            HStack {
                Image(systemName: "cursorarrow").foregroundStyle(mint)
                Text("提示线可穿透点击；键鼠共享由系统通用控制完成。")
                Spacer()
                Text("1.3.0").monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 13)
        }
        .frame(minWidth: 660, idealWidth: 720, minHeight: 650)
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
            HStack {
                Text("起点").font(.caption).frame(width: 28)
                Slider(value: Binding(get: { marker.start * 100 }, set: { marker.start = min($0 / 100, marker.end - 0.01) }), in: 0...99, step: 1)
                Text("\(Int((marker.start * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 34)
                Text("终点").font(.caption).frame(width: 28)
                Slider(value: Binding(get: { marker.end * 100 }, set: { marker.end = max($0 / 100, marker.start + 0.01) }), in: 1...100, step: 1)
                Text("\(Int((marker.end * 100).rounded()))%").monospacedDigit().font(.caption).frame(width: 34)
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
