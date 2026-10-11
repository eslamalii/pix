import AmbientCore
import Foundation

/// How the Clock reads.
enum ClockStyle: String, CaseIterable {
    case system, twelveHour, twentyFourHour

    var title: String {
        switch self {
        case .system: "Follow macOS"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }
}

/// What the user chose in the menu, kept in the app's user defaults.
enum Settings {
    /// Hide Pix sticks across launches until Show Pix (or ✨).
    static var hidden: Bool {
        get { UserDefaults.standard.bool(forKey: "hidden") }
        set { UserDefaults.standard.set(newValue, forKey: "hidden") }
    }

    /// Where the copy of Pix that owns the login item lives (nil before the first launch). A Homebrew upgrade puts the
    /// new version somewhere else.
    static var loginItemPath: String? {
        get { UserDefaults.standard.string(forKey: "loginItemPath") }
        set { UserDefaults.standard.set(newValue, forKey: "loginItemPath") }
    }

    /// What the user chose some apps are for, by bundle ID ("Treat … as" in the menu). Unknown values are dropped.
    static var overrides: [String: Override] {
        get { (UserDefaults.standard.dictionary(forKey: "overrides") as? [String: String] ?? [:]).compactMapValues(Override.init(stored:)) }
        set { UserDefaults.standard.set(newValue.mapValues(\.stored), forKey: "overrides") }
    }

    /// What Pix remembers of the user's days (see Memory), as JSON. A copy that can't be read starts over.
    static var memory: Memory {
        get { UserDefaults.standard.data(forKey: "memory").flatMap { try? JSONDecoder().decode(Memory.self, from: $0) } ?? Memory() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "memory") }
    }

    /// Pix's own usage report, once a minute in the log. Off unless switched on, so nothing else wakes Pix:
    ///   defaults write io.github.eslamalii.Pix usageLog -bool true   (then quit and reopen Pix)
    static var usageLog: Bool { UserDefaults.standard.bool(forKey: "usageLog") }

    /// The hat Pix wears, chosen from those it has earned; nil for none.
    static var hat: Hat? {
        get { UserDefaults.standard.string(forKey: "hat").flatMap(Hat.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: "hat") }
    }

    /// Every hat to wear without earning it, for the developer or the impatient (no menu item):
    ///   defaults write io.github.eslamalii.Pix allHats -bool true   (then quit and reopen Pix)
    static var allHats: Bool { UserDefaults.standard.bool(forKey: "allHats") }

    /// The chosen skin: a folder's name in the skins folder; nil for Pix's own art.
    static var skin: String? {
        get { UserDefaults.standard.string(forKey: "skin") }
        set { UserDefaults.standard.set(newValue, forKey: "skin") }
    }

    /// Where skins live: ~/Library/Application Support/Pix/Skins/<name>/, each a folder of art files.
    static var skinsFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pix/Skins", isDirectory: true)
    }

    /// The skins there, by name.
    static var skins: [String] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: skinsFolder, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return folders.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.map(\.lastPathComponent).sorted()
    }

    static var clock: ClockStyle {
        get { UserDefaults.standard.string(forKey: "clock").flatMap(ClockStyle.init(rawValue:)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "clock") }
    }
}
