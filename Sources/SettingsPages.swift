import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel(title)
        }.padding(16)
    }
}

struct AppearanceSettings: View {
    @ObservedObject var model: AppModel
    private func detail(_ mode: EdgeDisplayMode) -> String {
        switch mode {
        case .always: return "在所有屏幕上持续显示已有通道"
        case .nearEdges: return "鼠标靠近任意屏幕边缘时，显示全部通道"
        case .pointerScreen: return "鼠标在哪块屏幕，就只显示那块屏幕的通道"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard(title: "显示模式") {
                ForEach(EdgeDisplayMode.allCases) { mode in
                    Button { model.preferences.displayMode = mode } label: {
                        HStack(spacing: 13) {
                            Image(systemName: model.preferences.displayMode == mode ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18)).foregroundStyle(model.preferences.displayMode == mode ? mint : Color.secondary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(mode.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                                Text(detail(mode)).font(.system(size: 11)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(model.preferences.displayMode == mode ? mint.opacity(0.06) : .clear)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("displayMode-\(mode.rawValue)")
                        .accessibilityValue(model.preferences.displayMode == mode ? "已选中" : "未选中")
                    if mode != EdgeDisplayMode.allCases.last { Divider().padding(.leading, 47) }
                }
            }
            if model.preferences.displayMode == .pointerScreen {
                Text(PointerStateReader.isAvailable ? "通用控制两端都需选择此模式。鼠标离开本机或被系统隐藏时，本机提示线暂时隐藏。" : "当前系统无法读取鼠标可见状态，请选择其他显示模式。")
                    .font(.system(size: 11)).foregroundStyle(PointerStateReader.isAvailable ? Color.secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SettingsCard(title: "线条样式") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("线条粗细").font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(model.preferences.thickness)) 点").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Text("细").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $model.preferences.thickness, in: 2...8, step: 1).accessibilityLabel("线条粗细")
                        Text("粗").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 14) {
                        Capsule().fill(passageGradient(manual: false)).frame(height: model.preferences.thickness)
                        Capsule().fill(passageGradient(manual: true)).frame(height: model.preferences.thickness)
                    }.frame(height: 12).accessibilityLabel("扩展屏与通用控制线条样式")
                    HStack {
                        Text("在各屏幕上临时显示示例线").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button("预览 4 秒") { model.onPreview?() }.disabled(model.screenLocked)
                    }
                }.padding(16)
            }
        }
    }
}

struct ChannelSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard(title: "屏幕排列") {
                DisplayMap(displays: model.displays, portals: model.portals)
                    .frame(height: model.universalControlPortals.isEmpty ? 170 : 200)
                Divider().padding(.horizontal, 16)
                HStack(spacing: 20) {
                    legend("扩展屏通道", warm: false)
                    legend("通用控制", warm: true)
                    Spacer(minLength: 0)
                }.padding(16)
            }
            SettingsCard(title: "自动识别") {
                SettingsToggleRow(title: "扩展屏交界", detail: "标记本机相邻屏幕间可跨越的边缘", isOn: $model.preferences.automatic)
                Divider().padding(.horizontal, 16)
                SettingsToggleRow(title: "通用控制通道", detail: model.universalControlStatus, isOn: $model.preferences.automaticUniversalControl)
            }
            HStack(alignment: .top, spacing: 16) {
                Text("对端卡片仅为示意。另一台 Mac 也需运行本应用，才能显示对端提示。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("显示器设置…") { model.openDisplaySettings() }
            }
        }
    }
    private func legend(_ title: String, warm: Bool) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(passageGradient(manual: warm)).frame(width: 24, height: 4)
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct ManualSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                Text("自动识别后通常无需添加。手动标记需自行选择位置，并在不需要时关闭。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { model.addMarker() } label: { Label("添加标记", systemImage: "plus") }
                    .disabled(model.displays.isEmpty)
            }
            if model.preferences.markers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed").font(.system(size: 34, weight: .light)).foregroundStyle(mint.opacity(0.7))
                    Text("还没有手动标记").font(.system(size: 15, weight: .medium))
                    Text("已有通道会自动显示\n需要额外提示时，再添加一段标记")
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
                }.frame(maxWidth: .infinity).padding(.vertical, 64)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach($model.preferences.markers) { $marker in
                MarkerEditor(marker: $marker, displays: model.displays) { model.removeMarker(marker.id) }
            }
        }
    }
}

struct GeneralSettings: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard(title: "锁屏显示") {
                SettingsToggleRow(title: "锁屏时显示边缘", detail: "适用于登录后锁屏，不含重启后的首次登录界面", isOn: $model.preferences.showWhenLocked)
                if model.preferences.showWhenLocked {
                    Divider().padding(.horizontal, 16)
                    if model.preferences.displayMode == .pointerScreen {
                        HStack(spacing: 12) {
                            Image(systemName: "cursorarrow").foregroundStyle(mint)
                            Text("锁屏后仍只显示鼠标所在屏幕的通道")
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.padding(16)
                    } else {
                        SettingsToggleRow(title: "锁屏时保持常显", detail: "锁屏期间无需靠近边缘，解锁后恢复原模式", isOn: $model.preferences.alwaysShowWhenLocked)
                    }
                }
            }
            if let message = model.lockScreenMessage {
                Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            SettingsCard(title: "应用设置") {
                SettingsToggleRow(title: "显示菜单栏图标", detail: "隐藏后可重新打开应用进入设置", isOn: $model.preferences.showMenuBarIcon)
                Divider().padding(.horizontal, 16)
                SettingsToggleRow(title: "登录时启动", detail: "登录这台 Mac 后自动运行跨屏边缘",
                                  isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            }
            if let message = model.loginMessage {
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text("通用控制由 macOS 管理；连接断开时，自动通道提示会随之清除。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
