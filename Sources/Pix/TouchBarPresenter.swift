import AppKit
import IOKit

struct MissingTouchBarAPI: Error, CustomStringConvertible {
    let names: [String]
    var description: String { "this macOS is missing private Touch Bar API: \(names.joined(separator: ", "))" }
}

/// Live lookup and controlled missing-symbol lookup share the same launch check.
struct TouchBarSymbols {
    var method: (AnyClass, Selector) -> IMP?
    var function: (String) -> UnsafeMutableRawPointer?

    static var live: TouchBarSymbols {
        let dfr = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)
        return TouchBarSymbols(method: { cls, selector in
            class_getClassMethod(cls, selector).map(method_getImplementation)
        }, function: { name in dlsym(dfr, name) })
    }
}

/// Thin adapter over the private Touch Bar API (DFRFoundation + hidden NSTouchBar class methods).
/// Every symbol is resolved up front, so a macOS update that removes one fails at launch, not mid-use.
@MainActor
final class TouchBarPresenter {
    private typealias PresentFn = @convention(c) (AnyClass, Selector, NSTouchBar, Int, NSString) -> Void
    private typealias BarFn = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
    private typealias ItemFn = @convention(c) (AnyClass, Selector, NSTouchBarItem) -> Void
    private typealias PresenceFn = @convention(c) (CFString, Bool) -> Void
    private typealias CloseBoxFn = @convention(c) (Bool) -> Void

    private static let presentSel = Selector(("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"))
    private static let minimizeSel = Selector(("minimizeSystemModalTouchBar:"))
    private static let addTraySel = Selector(("addSystemTrayItem:"))

    private let present: PresentFn
    private let minimize: BarFn
    private let addTray: ItemFn
    private let setPresence: PresenceFn
    private let setCloseBox: CloseBoxFn

    init(symbols: TouchBarSymbols = .live) throws {
        var missing: [String] = []
        func method<T>(_ cls: AnyClass, _ sel: Selector, as: T.Type) -> T? {
            guard let implementation = symbols.method(cls, sel) else { missing.append("+[\(cls) \(sel)]"); return nil }
            return unsafeBitCast(implementation, to: T.self)
        }
        func function<T>(_ name: String, as: T.Type) -> T? {
            guard let sym = symbols.function(name) else { missing.append(name); return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        let present = method(NSTouchBar.self, Self.presentSel, as: PresentFn.self)
        let minimize = method(NSTouchBar.self, Self.minimizeSel, as: BarFn.self)
        let addTray = method(NSTouchBarItem.self, Self.addTraySel, as: ItemFn.self)
        let setPresence = function("DFRElementSetControlStripPresenceForIdentifier", as: PresenceFn.self)
        let setCloseBox = function("DFRSystemModalShowsCloseBoxWhenFrontMost", as: CloseBoxFn.self)
        guard let present, let minimize, let addTray, let setPresence, let setCloseBox else {
            throw MissingTouchBarAPI(names: missing)
        }
        (self.present, self.minimize, self.addTray, self.setPresence, self.setCloseBox) =
            (present, minimize, addTray, setPresence, setCloseBox)
    }

    /// Puts `item` (the ✨ button) in the Control Strip. Its identifier ties the modal bar to it.
    func addToControlStrip(_ item: NSTouchBarItem) {
        addTray(NSTouchBarItem.self, Self.addTraySel, item)
        setPresence(item.identifier.rawValue as CFString, true)
        setCloseBox(false)  // macOS 27 still shows the ✕; accepted in the spec
    }

    /// Takes over the whole Touch Bar: placement 1 hides the Control Strip while Pix is shown. Safe to call while already shown.
    func show(_ bar: NSTouchBar, tray: NSTouchBarItem.Identifier) {
        present(NSTouchBar.self, Self.presentSel, bar, 1, tray.rawValue as NSString)
    }

    /// Whether the hardware registry lists a Touch Bar input device. The device's name is only known from Apple
    /// Silicon, so a "no" is only trusted together with the bar never taking Pix's view (see the app delegate).
    static func hasTouchBarDevice() -> Bool {
        var devices: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDDevice"), &devices) == KERN_SUCCESS else { return true }
        defer { IOObjectRelease(devices) }
        while case let device = IOIteratorNext(devices), device != 0 {
            defer { IOObjectRelease(device) }
            let product = IORegistryEntryCreateCFProperty(device, "Product" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String ?? ""
            if product.localizedCaseInsensitiveContains("touchbar") || product.localizedCaseInsensitiveContains("touch bar") { return true }
        }
        return false
    }

    /// Hands the Touch Bar back to the system's default bar, and claims the Control Strip's one slot for apps back for
    /// `tray` (the ✨ button): whichever app claimed it last shows there.
    func hide(_ bar: NSTouchBar, tray: NSTouchBarItem.Identifier) {
        minimize(NSTouchBar.self, Self.minimizeSel, bar)
        setPresence(tray.rawValue as CFString, true)
    }
}
