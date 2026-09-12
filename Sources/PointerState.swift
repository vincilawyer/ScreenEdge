import AppKit
import Darwin

enum PointerStateReader {
    // CGRemoteOperation.h declares boolean_t (UInt32), not a Swift/C++ Bool.
    // The deprecated read-only function is loaded dynamically so its absence is safe.
    private typealias VisibilityFunction = @convention(c) () -> UInt32
    private static let framework = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY | RTLD_LOCAL)
    private static let visibility: VisibilityFunction? = {
        guard let framework, let symbol = dlsym(framework, "CGCursorIsVisible") else { return nil }
        return unsafeBitCast(symbol, to: VisibilityFunction.self)
    }()
    static var isAvailable: Bool { visibility != nil }

    @MainActor static func read() -> PointerSnapshot {
        PointerSnapshot(location: NSEvent.mouseLocation, isVisible: visibility.map { $0() != 0 })
    }
}
