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
    /// What the Controller owns that Pix keeps between launches (Hide Pix, "Treat … as", the Memory, the hat and when the
    /// user was last here), each in its own key as since 1.0. Unknown overrides are dropped, and a Memory that can't be read starts over.
    static var saved: Saved {
        get {
            let defaults = UserDefaults.standard
            return Saved(hidden: defaults.bool(forKey: "hidden"),
                         overrides: (defaults.dictionary(forKey: "overrides") as? [String: String] ?? [:]).compactMapValues(Override.init(stored:)),
                         memory: defaults.data(forKey: "memory").flatMap { try? JSONDecoder().decode(Memory.self, from: $0) } ?? Memory(),
                         hat: defaults.string(forKey: "hat").flatMap(Hat.init(rawValue:)),
                         lastSeen: defaults.object(forKey: "lastSeen") as? Date)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.hidden, forKey: "hidden")
            defaults.set(newValue.overrides.mapValues(\.stored), forKey: "overrides")
            defaults.set(try? JSONEncoder().encode(newValue.memory), forKey: "memory")
            defaults.set(newValue.hat?.rawValue, forKey: "hat")
            defaults.set(newValue.lastSeen, forKey: "lastSeen")
        }
    }

    /// Which plants are thirsty, kept so the Room carries on where it was; one that can't be read starts over.
    static var garden: Garden {
        get { UserDefaults.standard.data(forKey: "garden").flatMap { try? JSONDecoder().decode(Garden.self, from: $0) } ?? Garden() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "garden") }
    }

    /// Where the copy of Pix that owns the login item lives (nil before the first launch). A Homebrew upgrade puts the
    /// new version somewhere else.
    static var loginItemPath: String? {
        get { UserDefaults.standard.string(forKey: "loginItemPath") }
        set { UserDefaults.standard.set(newValue, forKey: "loginItemPath") }
    }

    /// Pix's own usage report, once a minute in the log. Off unless switched on, so nothing else wakes Pix:
    ///   defaults write io.github.eslamalii.Pix usageLog -bool true   (then quit and reopen Pix)
    static var usageLog: Bool { UserDefaults.standard.bool(forKey: "usageLog") }

    /// Every hat to wear without earning it, for the developer or the impatient (no menu item):
    ///   defaults write io.github.eslamalii.Pix allHats -bool true   (then quit and reopen Pix)
    static var allHats: Bool { UserDefaults.standard.bool(forKey: "allHats") }

    /// The chosen skin: a folder's name in the skins folder; nil for Pix's own art.
    static var skin: String? {
        get { UserDefaults.standard.string(forKey: "skin") }
        set { UserDefaults.standard.set(newValue, forKey: "skin") }
    }

    /// The chosen skin's folder; nil for Pix's own art.
    static var skinFolder: URL? { skin.map { skinsFolder.appendingPathComponent($0, isDirectory: true) } }

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
