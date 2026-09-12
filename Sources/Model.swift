import AppKit
import Combine
import ServiceManagement

@MainActor final class AppModel: ObservableObject {
    @Published var preferences: Preferences { didSet { save(); syncUniversalControl(); onChange?() } }
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var universalControlPortals: [Portal] = []
    @Published private(set) var universalControlStatus = "正在读取通用控制通道…"
    @Published var configWarning: String?
    @Published var loginEnabled = false
    @Published var loginMessage: String?
    var onChange: (() -> Void)?
    var onPreview: (() -> Void)?
    private let defaults: UserDefaults?
    private let key = "screenEdge.preferences.v1"
    private var observations: [NSObjectProtocol] = []
    private let ephemeral: Bool
    private var ucTimer: Timer?
    private var ucInFlight = false
    private var ucGeneration = 0
    private var ucValues: [UCEdgeValue] = []

    init(ephemeral: Bool = false) {
        self.ephemeral = ephemeral
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
        syncUniversalControl()
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplays() }
        })
        observations.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplays() }
        })
    }

    var portals: [Portal] {
        (preferences.automatic ? PortalGeometry.automatic(displays) : []) + universalControlPortals + PortalGeometry.manual(preferences.markers, displays: displays)
    }
    var automaticCount: Int { PortalGeometry.automatic(displays).count / 2 }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            guard CGDisplayMirrorsDisplay(displayID) == kCGNullDirectDisplay else { return nil }
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
            let id = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "display-\(displayID)"
            return DisplayInfo(id: id, name: screen.localizedName, frame: screen.frame, quartzFrame: CGDisplayBounds(displayID))
        }
        universalControlPortals = ucValues.compactMap { $0.portal(displays: displays) }
        onChange?()
        requestUniversalControl()
    }

    private func syncUniversalControl() {
        if !preferences.enabled || !preferences.automaticUniversalControl {
            ucTimer?.invalidate(); ucTimer = nil
            ucGeneration += 1; ucInFlight = false
            ucValues = []; universalControlPortals = []
            universalControlStatus = "自动通用控制标记已暂停。"
            return
        }
        guard !ephemeral, ucTimer == nil else { return }
        universalControlStatus = "正在读取通用控制通道…"
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.requestUniversalControl() }
        }
        timer.tolerance = 0.3
        ucTimer = timer; RunLoop.main.add(timer, forMode: .common)
        requestUniversalControl()
    }

    func requestUniversalControl() {
        guard !ephemeral, preferences.enabled, preferences.automaticUniversalControl, !ucInFlight else { return }
        ucInFlight = true
        let generation = ucGeneration
        SEReadUniversalControlEdges { [weak self] dictionaries, error in
            Task { @MainActor in
                guard let self, generation == self.ucGeneration else { return }
                self.ucInFlight = false
                self.applyUniversalControlResponse(dictionaries, error: error)
            }
        }
    }

    // Replace the entire snapshot, including empty/error responses, so stale edges disappear.
    func applyUniversalControlResponse(_ dictionaries: [[AnyHashable: Any]]?, error: String?) {
        let old = universalControlPortals
        let raw = dictionaries ?? []
        ucValues = raw.compactMap { UCEdgeValue(dictionary: $0 as? [String: Any] ?? [:]) }
        universalControlPortals = ucValues.compactMap { $0.portal(displays: displays) }
        if let error {
            ucValues = []; universalControlPortals = []
            universalControlStatus = error
        } else if universalControlPortals.count != raw.count {
            universalControlStatus = "部分通道坐标暂未识别；已显示能确认的位置。"
        } else if universalControlPortals.isEmpty {
            universalControlStatus = "系统当前没有可用的通用控制通道；连接后会自动显示。"
        } else {
            universalControlStatus = "已自动识别 \(universalControlPortals.count) 段通用控制通道，随系统连接和排列更新。"
        }
        if old != universalControlPortals { onChange?() }
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
