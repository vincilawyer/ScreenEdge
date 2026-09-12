import AppKit
import SwiftUI

extension AppDelegate {
    /// Render only this process's own settings view. No screen capture permission or user settings.
    @MainActor func runSettingsSnapshots() async {
        guard let index = CommandLine.arguments.firstIndex(of: "--settings-snapshots"),
              CommandLine.arguments.indices.contains(index + 1), let window else {
            fputs("Usage: --settings-snapshots OUTPUT_DIRECTORY\n", stderr); exit(1)
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            model.onChange = nil
            overlays.stop()
            model.preferences.displayMode = .pointerScreen
            model.preferences.markers = []
            NSApp.appearance = NSAppearance(named: .aqua)
            if let screen = model.displays.first, let frame = screen.quartzFrame {
                model.applyUniversalControlResponse([["id": ["display": screen.id, "device": "synthetic-preview"],
                    "edge": "bottom", "rect": [frame.minX, frame.maxY - 1, frame.width * 0.7, 1]]], error: nil)
            }
            for page in SettingsPage.allCases {
                try await snapshot(page, name: page.rawValue, size: NSSize(width: 820, height: 720), window: window, directory: directory)
            }
            try await snapshot(.styles, name: "styles-minimum", size: NSSize(width: 760, height: 610), window: window, directory: directory)
            try await snapshot(.styles, name: "styles-minimum-bottom", size: NSSize(width: 760, height: 610), window: window, directory: directory, scrollToBottom: true)
            model.preferences.extendedAppearance = EdgeAppearance(material: .solid, color: .lavender, opacity: 0.7)
            model.preferences.thickness = 8
            try await snapshot(.styles, name: "styles-solid", size: NSSize(width: 820, height: 720), window: window, directory: directory)
            model.preferences.thickness = 4
            model.preferences.extendedAppearance = EdgeAppearance(material: .gradient, gradient: .custom, gradientStart: .rose, gradientEnd: .blue, opacity: 0.8)
            try await snapshot(.styles, name: "styles-gradient", size: NSSize(width: 820, height: 720), window: window, directory: directory)
            try await snapshot(.styles, name: "styles-gradient-minimum-bottom", size: NSSize(width: 760, height: 610), window: window, directory: directory, scrollToBottom: true)
            try await snapshot(.appearance, name: "appearance-minimum", size: NSSize(width: 760, height: 610), window: window, directory: directory)
            try await snapshot(.general, name: "general-minimum", size: NSSize(width: 760, height: 610), window: window, directory: directory)
            model.addMarker()
            try await snapshot(.markers, name: "marker-editor-minimum", size: NSSize(width: 760, height: 610), window: window, directory: directory)
            NSApp.appearance = NSAppearance(named: .darkAqua)
            try await snapshot(.appearance, name: "appearance-dark", size: NSSize(width: 820, height: 720), window: window, directory: directory)
            try await snapshot(.styles, name: "styles-gradient-dark", size: NSSize(width: 820, height: 720), window: window, directory: directory)
            model.preferences.extendedAppearance = .softExtended
            try await snapshot(.styles, name: "styles-solid-dark", size: NSSize(width: 820, height: 720), window: window, directory: directory)
            print("PASS: rendered 16 settings snapshots from ephemeral settings, including materials, minimum size, scrolling and dark mode")
            NSApp.terminate(nil)
        } catch {
            fputs("FAIL: settings snapshot: \(error.localizedDescription)\n", stderr); exit(1)
        }
    }

    @MainActor private func snapshot(_ page: SettingsPage, name: String, size: NSSize,
                                    window: NSWindow, directory: URL, scrollToBottom: Bool = false) async throws {
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model, initialPage: page))
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(nanoseconds: 350_000_000)
        guard let view = window.contentView else { throw CocoaError(.coderInvalidValue) }
        view.layoutSubtreeIfNeeded()
        if scrollToBottom {
            func findScrollView(_ view: NSView) -> NSScrollView? {
                if let scroll = view as? NSScrollView { return scroll }
                return view.subviews.lazy.compactMap { findScrollView($0) }.first
            }
            guard let scroll = findScrollView(view), let document = scroll.documentView,
                  document.bounds.height > scroll.contentView.bounds.height else { throw CocoaError(.coderInvalidValue) }
            let y = document.isFlipped ? document.bounds.height - scroll.contentView.bounds.height : 0
            scroll.contentView.scroll(to: CGPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        window.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.coderInvalidValue) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
