import AmbientCore
import AppKit

/// The menu-bar icon (Pix's head in pixels) and its menu: Hide/Show Pix, Treat … as, Focus, Start at login, Clock, About, Quit.
/// It only shows and reports choices; the app decides what they mean.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    /// Everything the menu shows, asked for each time it opens.
    struct State {
        var startAtLogin = false
        var hidden = false
        /// The app in front (not Pix), for "Treat … as", and the user's choice for it.
        var frontApp: (id: String, name: String, override: Override?)?
        /// Minutes left in the Focus session, or nil when there's none.
        var focusLeft: Int?
        var hat: Hat?
        /// The hats Pix may wear; the others show greyed out with how to earn them.
        var wearableHats: [Hat] = []
        var clock = ClockStyle.system
        /// The chosen skin's name (nil: Classic), and the skins in the skins folder.
        var skin: String?
        var skins: [String] = []
    }

    var state: () -> State = { State() }
    var onHidden: (Bool) -> Void = { _ in }
    var onStartAtLogin: (Bool) -> Void = { _ in }
    var onClock: (ClockStyle) -> Void = { _ in }
    /// An app's new choice, or nil to go back to Pix's guess.
    var onOverride: (String, Override?) -> Void = { _, _ in }
    /// Start Focus (true) or stop it early (false).
    var onFocus: (Bool) -> Void = { _ in }
    var onForget: () -> Void = {}
    /// A hat to wear, or nil to take it off.
    var onHat: (Hat?) -> Void = { _ in }
    /// A skin to wear by name, or nil for Pix's own art.
    var onSkin: (String?) -> Void = { _ in }
    var onOpenSkins: () -> Void = {}

    /// Dims the icon while Pix is hidden.
    var hidden = false { didSet { item.button?.alphaValue = hidden ? 0.5 : 1 } }

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    override init() {
        super.init()
        item.button?.image = Self.icon
        item.button?.toolTip = "Pix"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    /// Rebuilt each time it opens, so checkmarks always match what the app says.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let state = state()
        menu.removeAllItems()
        menu.addItem(Action(state.hidden ? "Show Pix" : "Hide Pix") { [weak self] in self?.onHidden(!state.hidden) })
        if let app = state.frontApp { menu.addItem(treat(app)) }
        menu.addItem(.separator())
        if let left = state.focusLeft {
            menu.addItem(Action("Stop Focus (\(left) min left)") { [weak self] in self?.onFocus(false) })
        } else {
            menu.addItem(Action("Focus with Pix for \(Int(Controller.focusLength / 60)) Minutes") { [weak self] in self?.onFocus(true) })
        }
        menu.addItem(.separator())
        let startAtLogin = state.startAtLogin
        menu.addItem(Action("Start at Login", checked: startAtLogin) { [weak self] in self?.onStartAtLogin(!startAtLogin) })
        menu.addItem(hats(state))
        menu.addItem(skins(state))
        let clock = NSMenuItem(title: "Clock", action: nil, keyEquivalent: "")
        clock.submenu = NSMenu()
        for style in ClockStyle.allCases {
            clock.submenu?.addItem(Action(style.title, checked: state.clock == style) { [weak self] in self?.onClock(style) })
        }
        menu.addItem(clock)
        menu.addItem(.separator())
        menu.addItem(Action("Forget Pix's Memory…") { [weak self] in self?.onForget() })
        menu.addItem(.separator())
        menu.addItem(Action("About Pix") { Self.showAbout() })
        menu.addItem(Action("Quit Pix") { NSApp.terminate(nil) })
    }

    /// "Treat ‹app› as" and its Activities, the app's own Touch Bar, then Pix's own guess; the current choice is checked.
    private func treat(_ app: (id: String, name: String, override: Override?)) -> NSMenuItem {
        let chosen = app.override
        let item = NSMenuItem(title: "Treat \(app.name) as", action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        for activity in Activity.allCases {
            item.submenu?.addItem(Action(activity.title, checked: chosen == .activity(activity)) { [weak self] in
                self?.onOverride(app.id, .activity(activity))
            })
        }
        item.submenu?.addItem(.separator())
        item.submenu?.addItem(Action("Its Own Touch Bar", checked: chosen == .defaultBar) { [weak self] in self?.onOverride(app.id, .defaultBar) })
        item.submenu?.addItem(.separator())
        let guess = "Pix's Guess (\(Activity(guessing: app.id).title))"
        item.submenu?.addItem(Action(guess, checked: chosen == nil) { [weak self] in self?.onOverride(app.id, nil) })
        return item
    }

    /// "Hat": no hat, then every hat, the earned ones to wear and the others greyed out with how to earn them.
    private func hats(_ state: State) -> NSMenuItem {
        let wearable = state.wearableHats, worn = state.hat
        let item = NSMenuItem(title: "Hat", action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        item.submenu?.addItem(Action("No Hat", checked: worn == nil) { [weak self] in self?.onHat(nil) })
        item.submenu?.addItem(.separator())
        for hat in Hat.allCases {
            if wearable.contains(hat) {
                item.submenu?.addItem(Action(hat.title, checked: worn == hat) { [weak self] in self?.onHat(hat) })
            } else {
                item.submenu?.addItem(NSMenuItem(title: "\(hat.title) (\(hat.howToEarn))", action: nil, keyEquivalent: ""))  // no action: greyed out
            }
        }
        return item
    }

    /// "Skin": Pix's own art, every skin in the skins folder, and a way to that folder.
    private func skins(_ state: State) -> NSMenuItem {
        let worn = state.skin
        let item = NSMenuItem(title: "Skin", action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        item.submenu?.addItem(Action("Classic", checked: worn == nil) { [weak self] in self?.onSkin(nil) })
        for name in state.skins {
            item.submenu?.addItem(Action(name, checked: worn == name) { [weak self] in self?.onSkin(name) })
        }
        item.submenu?.addItem(.separator())
        item.submenu?.addItem(Action("Open Skins Folder…") { [weak self] in self?.onOpenSkins() })
        return item
    }

    private static func showAbout() {
        let link = "https://meetpix.app"
        let credits = NSAttributedString(string: "A tiny pixel robot that lives on your Touch Bar.\n\(link)",
                                         attributes: [.font: NSFont.systemFont(ofSize: 11), .link: URL(string: link)!])
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    /// Pix's head in pixels, as a template image so macOS tints it for light and dark menu bars.
    private static let icon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            for (x, y, w, h) in [(8, 1, 2, 2), (8, 3, 2, 1),                       // antenna
                                 (3, 4, 12, 1), (2, 5, 14, 9), (3, 14, 12, 1)] {   // a rounded head
                NSRect(x: x, y: y, width: w, height: h).fill()
            }
            NSRect(x: 4, y: 6, width: 10, height: 6).fill(using: .clear)          // the face-screen
            for x in [6, 10] { NSRect(x: x, y: 8, width: 2, height: 2).fill() }    // eyes
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// A menu item that runs a closure.
private final class Action: NSMenuItem {
    private let run: () -> Void

    init(_ title: String, checked: Bool = false, _ run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }
    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { run() }
}

extension Activity {
    /// How the menu names it.
    var title: String {
        switch self {
        case .coding: "Coding"
        case .browsing: "Browsing"
        case .watching: "Watching"
        case .music: "Music"
        case .meeting: "Meeting"
        case .other: "Other"
        }
    }
}

extension Hat {
    var title: String {
        switch self {
        case .cap: "Cap"
        case .beanie: "Beanie"
        case .party: "Party Hat"
        case .flower: "Flower Crown"
        case .crown: "Crown"
        case .headband: "Headband"
        case .witch: "Witch Hat"
        case .santa: "Santa Hat"
        case .topHat: "Top Hat"
        }
    }
}
