import AppKit
import Combine
import ServiceManagement

struct Preferences: Codable {
    var enabled = true
    var automatic = true
    var nearOnly = false
    var thickness: Double = 4
    var markers: [ManualMarker] = []
}

@MainActor final class AppModel: ObservableObject {
    @Published var preferences: Preferences { didSet { save(); onChange?() } }
    @Published private(set) var displays: [DisplayInfo] = []
    @Published var configWarning: String?
    @Published var loginEnabled = false
    @Published var loginMessage: String?
    var onChange: (() -> Void)?
    var onPreview: (() -> Void)?
    private let defaults: UserDefaults?
    private let key = "screenEdge.preferences.v1"
    private var observations: [NSObjectProtocol] = []

    init(ephemeral: Bool = false) {
        defaults = ephemeral ? nil : .standard
        if let data = defaults?.data(forKey: key) {
            do { preferences = try JSONDecoder().decode(Preferences.self, from: data) }
            catch {
                preferences = Preferences()
                // Keep the original bytes available for recovery, never silently discard them.
                defaults?.set(data, forKey: key + ".unreadableBackup")
                configWarning = "旧设置未能读取，已保留备份；当前使用默认设置。"
            }
        } else { preferences = Preferences() }
        refreshDisplays()
        refreshLoginStatus()
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplays() }
        })
        observations.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplays() }
        })
    }

    var portals: [Portal] {
        (preferences.automatic ? PortalGeometry.automatic(displays) : []) + PortalGeometry.manual(preferences.markers, displays: displays)
    }
    var automaticCount: Int { PortalGeometry.automatic(displays).count / 2 }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            guard CGDisplayMirrorsDisplay(displayID) == kCGNullDirectDisplay else { return nil }
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
            let id = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "display-\(displayID)"
            return DisplayInfo(id: id, name: screen.localizedName, frame: screen.frame)
        }
        onChange?()
    }

    func addMarker() {
        guard let display = displays.first else { return }
        preferences.markers.append(ManualMarker(displayID: display.id))
    }
    func removeMarker(_ id: UUID) { preferences.markers.removeAll { $0.id == id } }
    func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval { loginMessage = "请在系统设置 → 通用 → 登录项中允许跨屏边缘。" }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
        } catch { loginMessage = "未能更新登录项：\(error.localizedDescription)" }
        refreshLoginStatus()
    }
    private func save() {
        guard let defaults else { return }
        do { defaults.set(try JSONEncoder().encode(preferences), forKey: key) }
        catch { configWarning = "设置未能保存：\(error.localizedDescription)" }
    }
}
