import AppKit
import IOKit
import Darwin

/// Observes the current user's session only. It never locks, unlocks, or reads input.
@MainActor final class ScreenLockMonitor {
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var previous: Bool?
    private let changed: (Bool) -> Void

    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
        let distributed = DistributedNotificationCenter.default()
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            let observer = distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            observers.append((distributed, observer))
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.sessionDidResignActiveNotification,
                     NSWorkspace.screensDidWakeNotification] {
            let observer = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            observers.append((workspace, observer))
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 0.25
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    static func isCurrentSessionLocked() -> Bool {
        var console = stat()
        guard getuid() != 0, stat("/dev/console", &console) == 0, console.st_uid == getuid() else { return false }
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        guard let value = IORegistryEntryCreateCFProperty(root, "IOConsoleLocked" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue(),
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
        return (value as? NSNumber)?.boolValue == true
    }

    private func refresh() {
        let locked = Self.isCurrentSessionLocked()
        guard previous != locked else { return }
        previous = locked
        changed(locked)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
    }
}

/// An app-owned, temporary system overlay space. Only click-through edge panels enter it.
/// Symbol availability, level and window membership are checked; failure hides the overlay.
final class LockScreenSpace {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CreateSpace = @convention(c) (Int32, Int, CFDictionary?) -> UInt64
    private typealias DestroySpace = @convention(c) (Int32, UInt64) -> Void
    private typealias SetLevel = @convention(c) (Int32, UInt64, Int32) -> Void
    private typealias GetLevel = @convention(c) (Int32, UInt64) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Void
    private typealias MoveWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void
    private typealias CopySpaces = @convention(c) (Int32, UInt32, CFArray) -> Unmanaged<CFArray>?

    private let library: UnsafeMutableRawPointer
    private let connection: Int32
    private let space: UInt64
    private let destroy: DestroySpace
    private let hide: ShowSpaces
    private let move: MoveWindows
    private let copySpaces: CopySpaces

    init?() {
        guard let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW | RTLD_LOCAL) else { return nil }
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            guard let address = dlsym(library, name) else { return nil }
            return unsafeBitCast(address, to: T.self)
        }
        guard let main = symbol("SLSMainConnectionID", MainConnection.self),
              let create = symbol("SLSSpaceCreate", CreateSpace.self),
              let destroy = symbol("SLSSpaceDestroy", DestroySpace.self),
              let setLevel = symbol("SLSSpaceSetAbsoluteLevel", SetLevel.self),
              let getLevel = symbol("SLSSpaceGetAbsoluteLevel", GetLevel.self),
              let show = symbol("SLSShowSpaces", ShowSpaces.self),
              let hide = symbol("SLSHideSpaces", ShowSpaces.self),
              let move = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", MoveWindows.self),
              let copySpaces = symbol("SLSCopySpacesForWindows", CopySpaces.self) else {
            dlclose(library); return nil
        }
        let connection = main()
        guard connection != 0 else { dlclose(library); return nil }
        let space = create(connection, 1, nil)
        guard space != 0 else { dlclose(library); return nil }
        // Notification overlays at the lock screen; do not alter any existing desktop space.
        setLevel(connection, space, 400)
        guard getLevel(connection, space) == 400 else {
            destroy(connection, space); dlclose(library); return nil
        }
        self.library = library; self.connection = connection; self.space = space
        self.destroy = destroy; self.hide = hide; self.move = move; self.copySpaces = copySpaces
        show(connection, [NSNumber(value: space)] as CFArray)
    }

    @MainActor func attach(_ panel: EdgePanel) -> Bool {
        guard panel.ignoresMouseEvents, !panel.canBecomeKey, !panel.canBecomeMain,
              panel.canBecomeVisibleWithoutLogin else { return false }
        let windows = [NSNumber(value: panel.windowNumber)] as CFArray
        move(connection, space, windows, 7)
        guard let result = copySpaces(connection, 0xF, windows)?.takeRetainedValue() as? [NSNumber] else { return false }
        return result.contains { $0.uint64Value == space }
    }

    deinit {
        hide(connection, [NSNumber(value: space)] as CFArray)
        destroy(connection, space)
        dlclose(library)
    }
}
