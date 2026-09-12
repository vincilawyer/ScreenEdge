import AppKit
import SwiftUI
import CoreServices

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let smokeTest = CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--uc-check") || CommandLine.arguments.contains("--settings-snapshots")
    lazy var model = AppModel(ephemeral: smokeTest)
    let overlays = OverlayController()
    var status: NSStatusItem!
    var window: NSWindow?
    var lockMonitor: ScreenLockMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !smokeTest {
            let id = Bundle.main.bundleIdentifier ?? "local.screenedge.app"
            if let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
                other.activate(options: [.activateIgnoringOtherApps])
                NSApp.terminate(nil)
                return
            }
        }
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let quitItem = NSMenuItem(title: "退出跨屏边缘", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self; appMenu.addItem(quitItem); appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("拷贝", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        editItem.submenu = editMenu; mainMenu.addItem(editItem); NSApp.mainMenu = mainMenu
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "跨屏边缘")
        status.button?.toolTip = "跨屏边缘"
        model.onChange = { [weak self] in
            guard let self else { return }
            self.overlays.rebuild(model: self.model)
            self.updateMenu()
        }
        model.onPreview = { [weak self] in
            guard let self else { return }
            self.overlays.preview(model: self.model)
        }
        overlays.rebuild(model: model)
        updateMenu()
        if !smokeTest {
            lockMonitor = ScreenLockMonitor { [weak self] locked in
                self?.model.setScreenLocked(locked)
            }
        }
        let firstLaunch = !UserDefaults.standard.bool(forKey: "screenEdge.didLaunch")
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.eventID == kAEOpenApplication &&
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        // A manual cold launch must remain a settings entry point when the icon is hidden.
        if firstLaunch || CommandLine.arguments.contains("--settings") || smokeTest ||
            (!model.preferences.showMenuBarIcon && !launchedAtLogin) { showSettings() }
        if !smokeTest { UserDefaults.standard.set(true, forKey: "screenEdge.didLaunch") }
        if CommandLine.arguments.contains("--settings-snapshots") {
            Task { @MainActor in await self.runSettingsSnapshots() }
        } else if CommandLine.arguments.contains("--uc-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.runUCCheck() }
        } else if smokeTest { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.runSmokeTest() } }
    }

    func updateMenu() {
        status.isVisible = model.preferences.showMenuBarIcon
        let menu = NSMenu()
        let title = NSMenuItem(title: "跨屏边缘", action: nil, keyEquivalent: "")
        title.isEnabled = false; menu.addItem(title)
        let toggle = NSMenuItem(title: "显示边缘", action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self; toggle.state = model.preferences.enabled ? .on : .off; menu.addItem(toggle)
        let modeItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in EdgeDisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = mode.rawValue
            item.state = model.preferences.displayMode == mode ? .on : .off
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu; menu.addItem(modeItem)
        let uc = NSMenuItem(title: "自动识别通用控制", action: #selector(toggleUC), keyEquivalent: "")
        uc.target = self; uc.state = model.preferences.automaticUniversalControl ? .on : .off; menu.addItem(uc)
        menu.addItem(.separator())
        for marker in model.preferences.markers {
            let item = NSMenuItem(title: "\(marker.edge.title) · \(marker.label)", action: #selector(toggleMarker(_:)), keyEquivalent: "")
            item.representedObject = marker.id.uuidString; item.target = self
            item.state = marker.enabled ? .on : .off; menu.addItem(item)
        }
        if !model.preferences.markers.isEmpty { menu.addItem(.separator()) }
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        let refresh = NSMenuItem(title: "刷新屏幕", action: #selector(refresh), keyEquivalent: "")
        refresh.target = self; menu.addItem(refresh)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出跨屏边缘", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        status.menu = menu
    }
    @objc func toggleEnabled() { model.preferences.enabled.toggle() }
    @objc func toggleUC() { model.preferences.automaticUniversalControl.toggle() }
    @objc func selectDisplayMode(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let mode = EdgeDisplayMode(rawValue: raw) else { return }
        model.preferences.displayMode = mode
    }
    @objc func toggleMarker(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String,
              let index = model.preferences.markers.firstIndex(where: { $0.id.uuidString == id }) else { return }
        model.preferences.markers[index].enabled.toggle()
    }
    @objc func refresh() { model.refreshDisplays() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model))
            let w = NSWindow(contentViewController: controller)
            w.title = "跨屏边缘"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 820, height: 720))
            w.contentMinSize = NSSize(width: 760, height: 610)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        lockMonitor?.stop()
        overlays.stop()
    }

    func runUCCheck() {
        SEReadUniversalControlEdges { [weak self] dictionaries, error in
            Task { @MainActor in
                guard let self else { return }
                if let error { fputs("FAIL: \(error)\n", stderr); exit(1) }
                let raw = dictionaries ?? []
                guard !raw.isEmpty else {
                    fputs("INCONCLUSIVE: the system returned no active UC edges; actual UC rendering was not tested\n", stderr)
                    exit(2)
                }
                let values = raw.compactMap { UCEdgeValue(dictionary: $0 as? [String: Any] ?? [:]) }
                let portals = values.compactMap { $0.portal(displays: self.model.displays) }
                guard portals.count == raw.count else { fputs("FAIL: some active edge coordinates could not be mapped\n", stderr); exit(1) }
                self.model.applyUniversalControlResponse(dictionaries, error: nil)
                let entries = self.overlays.entries.filter { $0.portal.universalControl }
                precondition(entries.count == portals.count)
                precondition(DisplayMapGeometry.remoteHints(displays: self.model.displays, portals: portals).count == portals.count)
                for entry in entries {
                    precondition(entry.window.frame == entry.frame)
                    precondition(entry.window.ignoresMouseEvents && !entry.window.canBecomeKey)
                    precondition((entry.window.contentView as? EdgeStripView)?.manual == true)
                    precondition(entry.window.isVisible && entry.window.alphaValue == 1)
                }
                self.model.applyUniversalControlResponse([], error: nil)
                precondition(self.overlays.entries.allSatisfy { !$0.portal.universalControl })
                self.model.applyUniversalControlResponse(dictionaries, error: nil)
                self.model.applyUniversalControlResponse(nil, error: "simulated read failure")
                precondition(self.overlays.entries.allSatisfy { !$0.portal.universalControl })
                self.model.applyUniversalControlResponse(dictionaries, error: nil)
                self.model.preferences.automaticUniversalControl = false
                precondition(self.overlays.entries.allSatisfy { !$0.portal.universalControl })
                print("PASS: read-only Universal Control query, \(raw.count) active edge(s), mapped and rendered as click-through warm gradients; empty/error/disable responses remove UC overlays")
                for portal in portals {
                    print("edge=\(portal.edge.rawValue) start=\(portal.start) end=\(portal.end) warmGradient=\(portal.usesWarmPalette)")
                }
                NSApp.terminate(nil)
            }
        }
    }

    func runSmokeTest() {
        guard let screen = model.displays.first else { fputs("FAIL: no display\n", stderr); exit(1) }
        let realPortals = PortalGeometry.automatic(model.displays)
        var matchedSamples = 0
        for a in realPortals {
            guard let source = model.displays.first(where: { $0.id == a.displayID }),
                  let b = realPortals.first(where: { $0.displayID != a.displayID && $0.label == source.name && $0.start == a.start && $0.end == a.end && $0.edge.vertical == a.edge.vertical }) else { continue }
            for fraction: CGFloat in [0.05, 0.25, 0.5, 0.75, 0.95] {
                let coordinate = a.start + fraction * (a.end - a.start)
                let point = a.edge.vertical ? CGPoint(x: 0, y: coordinate) : CGPoint(x: coordinate, y: 0)
                precondition(abs(a.gradientFraction(at: point) - b.gradientFraction(at: point)) < 0.00001)
                matchedSamples += 1
            }
        }
        // Render the same strip at two physical lengths, representing displays with different scales.
        func render(_ size: NSSize, vertical: Bool, warm: Bool) -> NSBitmapImageRep {
            let view = EdgeStripView(frame: CGRect(origin: .zero, size: size), manual: warm, vertical: vertical)
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            return rep
        }
        for warm in [false, true] {
            for vertical in [false, true] {
                let a = render(vertical ? NSSize(width: 8, height: 400) : NSSize(width: 400, height: 8), vertical: vertical, warm: warm)
                let b = render(vertical ? NSSize(width: 8, height: 800) : NSSize(width: 800, height: 8), vertical: vertical, warm: warm)
                for fraction: CGFloat in [0.05, 0.25, 0.5, 0.75, 0.95] {
                    func color(_ image: NSBitmapImageRep) -> NSColor {
                        let x = vertical ? image.pixelsWide / 2 : Int(CGFloat(image.pixelsWide) * fraction)
                        let y = vertical ? Int(CGFloat(image.pixelsHigh) * fraction) : image.pixelsHigh / 2
                        return image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    }
                    let ca = color(a), cb = color(b)
                    precondition(abs(ca.redComponent - cb.redComponent) < 0.04 && abs(ca.greenComponent - cb.greenComponent) < 0.04 && abs(ca.blueComponent - cb.blueComponent) < 0.04)
                    precondition(ca.alphaComponent > 0.9 && cb.alphaComponent > 0.9)
                }
                let start = a.colorAt(x: vertical ? a.pixelsWide / 2 : 12, y: vertical ? 12 : a.pixelsHigh / 2)!.usingColorSpace(.deviceRGB)!
                let end = a.colorAt(x: vertical ? a.pixelsWide / 2 : a.pixelsWide - 12, y: vertical ? a.pixelsHigh - 12 : a.pixelsHigh / 2)!.usingColorSpace(.deviceRGB)!
                precondition(abs(start.greenComponent - end.greenComponent) + abs(start.blueComponent - end.blueComponent) > 0.2)
            }
        }
        print("PASS: actual display geometry has \(realPortals.count / 2) passage(s), \(matchedSamples) corresponding gradient samples; both gradient palettes match across 400/800-point lengths in both orientations")
        model.preferences.automatic = false
        model.preferences.nearOnly = false
        model.preferences.markers = [ManualMarker(displayID: screen.id, label: "测试标记")]
        precondition(overlays.entries.count == 1)
        let entry = overlays.entries[0]
        precondition(entry.window.ignoresMouseEvents && !entry.window.canBecomeKey && !entry.window.canBecomeMain)
        precondition(entry.window.level == .screenSaver)
        precondition(entry.window.collectionBehavior.contains(.fullScreenAuxiliary))
        precondition(entry.window.collectionBehavior.contains(.canJoinAllSpaces))
        precondition(entry.window.frame == entry.frame, "actual=\(entry.window.frame), expected=\(entry.frame)")
        precondition(abs(entry.frame.maxX - screen.frame.maxX) < 0.5)
        model.preferences.enabled = false
        precondition(overlays.entries.isEmpty)
        model.preferences.enabled = true
        precondition(overlays.entries.count == 1)
        model.preferences.markers[0].edge = .top
        precondition(abs(overlays.entries[0].window.frame.maxY - screen.frame.maxY) < 0.5)
        model.preferences.nearOnly = true
        precondition(overlays.entries.count == 1)
        model.preferences.markers = [ManualMarker(displayID: screen.id, edge: .left, start: 0.25, end: 0.75),
                                     ManualMarker(displayID: screen.id, edge: .right, start: 0.25, end: 0.75)]
        precondition(overlays.entries.count == 2)
        overlays.updateProximity(at: CGPoint(x: screen.frame.minX + 20, y: screen.frame.midY))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "near one passage reveals all passages")
        overlays.updateProximity(at: CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 20))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "a screen edge without a passage also reveals all passages")
        overlays.updateProximity(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 }, "moving into screen center hides all passages together")
        model.setScreenLocked(true)
        guard overlays.usesLockScreenSpace else {
            fputs("FAIL: could not create or attach the lock-screen overlay space\n", stderr); exit(1)
        }
        precondition(overlays.entries.count == 2)
        precondition(overlays.entries.allSatisfy { $0.window.canBecomeVisibleWithoutLogin && $0.window.ignoresMouseEvents && !$0.window.canBecomeKey })
        precondition(window?.canBecomeVisibleWithoutLogin == false, "settings window stays off the lock screen")
        overlays.updateProximity(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "lock-screen always-visible setting overrides desktop proximity")
        model.preferences.alwaysShowWhenLocked = false
        overlays.updateProximity(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 }, "lock-screen proximity option is honored")
        model.preferences.showWhenLocked = false
        precondition(overlays.entries.isEmpty && !overlays.usesLockScreenSpace, "disabled lock overlays release their space")
        model.setScreenLocked(false)
        precondition(overlays.entries.count == 2 && !overlays.usesLockScreenSpace)
        precondition(overlays.entries.allSatisfy { !$0.window.canBecomeVisibleWithoutLogin }, "unlock restores ordinary desktop panels")
        print("PASS: temporary lock overlay space, edge-only membership, visibility options and teardown; simulated transition only, actual screen lock still requires validation")
        model.preferences.displayMode = .pointerScreen
        let localPointer = PointerSnapshot(location: CGPoint(x: screen.frame.midX, y: screen.frame.midY), isVisible: true)
        overlays.updateVisibility(pointer: localPointer)
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "pointer screen shows all of its passages, including from screen center")
        overlays.updateVisibility(pointer: PointerSnapshot(location: localPointer.location, isVisible: false))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 }, "hidden cursor cannot leave stale-coordinate overlays visible")
        overlays.updateVisibility(pointer: PointerSnapshot(location: localPointer.location, isVisible: nil))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 }, "unknown cursor visibility hides pointer-screen overlays")
        overlays.updateVisibility(pointer: localPointer)
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "returning pointer restores its passages")
        model.preferences.showWhenLocked = true
        model.preferences.alwaysShowWhenLocked = true
        model.setScreenLocked(true)
        precondition(overlays.usesLockScreenSpace)
        overlays.updateVisibility(pointer: PointerSnapshot(location: localPointer.location, isVisible: false))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 0 }, "lock-screen constant visibility cannot override pointer ownership")
        overlays.updateVisibility(pointer: localPointer)
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "local pointer reveals lock-screen passages")
        model.setScreenLocked(false)
        model.preferences.displayMode = .always
        overlays.updateVisibility(pointer: PointerSnapshot(location: localPointer.location, isVisible: false))
        precondition(overlays.entries.allSatisfy { $0.window.alphaValue == 1 }, "switching back to always visible restores original behavior")
        print("PASS: pointer-screen native visibility, hidden/unknown state, return, mode switching and simulated lock; visibility API available=\(PointerStateReader.isAvailable)")
        model.preferences.markers = []
        precondition(overlays.entries.isEmpty)
        print("PASS: overlay bounds, click-through, nonactivation, Spaces, switches, edits, deletion; near any screen edge reveals all passages, screen center hides all; \(model.displays.count) local screen(s)")
        NSApp.terminate(nil)
    }
}

@main struct ScreenEdgeApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
