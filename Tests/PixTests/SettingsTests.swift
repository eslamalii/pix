import Foundation
import Testing
import AmbientCore
@testable import Pix

private struct SettingsFixture {
    let name = "pix-settings-\(UUID().uuidString)"

    func defaults() throws -> UserDefaults { try #require(UserDefaults(suiteName: name)) }
    func reader() throws -> Settings { Settings(defaults: try defaults()) }
    func remove() { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
}

@Test func savedChoicesAndGardenRoundTripThroughAFreshSettingsReader() throws {
    let fixture = SettingsFixture()
    defer { fixture.remove() }
    let settings = try fixture.reader()
    let time = Date(timeIntervalSince1970: 1_800_000_000)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var memory = Memory()
    memory.arrive(at: time, calendar: calendar)
    memory.petted(at: time, calendar: calendar)
    memory.finishedFocus()
    let saved = Saved(hidden: true, overrides: ["coding-app": .activity(.coding), "other-app": .defaultBar],
                      memory: memory, hat: .cap, lastSeen: time)
    let plant = Plant(strip: "desk", x: 404)
    var garden = Garden()
    garden.adopt([plant], at: time, random: { 0 })
    settings.saved = saved
    settings.garden = garden

    let restored = try fixture.reader()
    #expect(restored.saved == saved)
    #expect(restored.garden == garden)
    #expect(restored.garden.thirsty(at: time).isEmpty)
    #expect(restored.garden.thirsty(at: time + 3 * 3600) == [plant])
}

@Test func missingSettingsStartWithEmptySavedValuesAndGarden() throws {
    let fixture = SettingsFixture()
    defer { fixture.remove() }
    let settings = try fixture.reader()
    #expect(settings.saved == Saved())
    #expect(settings.garden == Garden())
}

@Test func unreadableMemoryAndGardenFallBackWithoutDiscardingOtherChoices() throws {
    let fixture = SettingsFixture()
    defer { fixture.remove() }
    let defaults = try fixture.defaults()
    defaults.set(true, forKey: "hidden")
    defaults.set(["known": "coding", "unknown": "future-activity"], forKey: "overrides")
    defaults.set("future-hat", forKey: "hat")
    let time = Date(timeIntervalSince1970: 1_800_000_000)
    defaults.set(time, forKey: "lastSeen")
    for invalid in [Data("not json".utf8), Data(#"{"days":42}"#.utf8)] {
        defaults.set(invalid, forKey: "memory")
        defaults.set(invalid, forKey: "garden")
        let settings = try fixture.reader()
        #expect(settings.saved == Saved(hidden: true, overrides: ["known": .activity(.coding)], lastSeen: time))
        #expect(settings.garden == Garden())
    }
}

@Test func settingsReadLegacyMemoryFromExistingKeys() throws {
    let fixture = SettingsFixture()
    defer { fixture.remove() }
    let defaults = try fixture.defaults()
    let legacy = #"{"days":["2026-10-12","2026-10-13","2026-10-14"],"arrivals":{},"pets":{"2026-10-14":4}}"#
    defaults.set(Data(legacy.utf8), forKey: "memory")
    defaults.set("cap", forKey: "hat")
    defaults.set(["video-app": "watching", "own-bar": "defaultBar"], forKey: "overrides")
    let saved = try fixture.reader().saved
    #expect(saved.memory.totalDays == 3)
    #expect(saved.memory.totalPets == 4)
    #expect(saved.memory.totalFocusSessions == 0)
    #expect(saved.memory.occasions.isEmpty)
    #expect(saved.hat == .cap)
    #expect(saved.overrides == ["video-app": .activity(.watching), "own-bar": .defaultBar])
}

@Test func clearingOptionalSavedValuesRemovesTheirExistingKeys() throws {
    let fixture = SettingsFixture()
    defer { fixture.remove() }
    let settings = try fixture.reader()
    settings.saved = Saved(hat: .cap, lastSeen: Date(timeIntervalSince1970: 1_800_000_000))
    settings.saved = Saved()
    let defaults = try fixture.defaults()
    #expect(defaults.object(forKey: "hat") == nil)
    #expect(defaults.object(forKey: "lastSeen") == nil)
    #expect(try fixture.reader().saved == Saved())
}

@Test func settingsStoresDoNotShareSavedValuesOrGarden() throws {
    let first = SettingsFixture(), second = SettingsFixture()
    defer { first.remove(); second.remove() }
    let one = try first.reader(), two = try second.reader()
    one.saved = Saved(hidden: true, hat: .cap)
    var garden = Garden()
    garden.adopt([Plant(strip: "desk", x: 404)], at: Date(timeIntervalSince1970: 0), random: { 0 })
    one.garden = garden
    #expect(two.saved == Saved())
    #expect(two.garden == Garden())
    two.saved = Saved(hat: .beanie)
    #expect(try first.reader().saved == Saved(hidden: true, hat: .cap))
    #expect(try first.reader().garden == garden)
}

@Test func preferencesAndSkinDiscoveryUseIsolatedDefaultsAndRealFolders() throws {
    let fixture = SettingsFixture()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pix-skins-\(UUID().uuidString)")
    defer { fixture.remove(); try? FileManager.default.removeItem(at: root) }
    let defaults = try fixture.defaults()
    let settings = Settings(defaults: defaults, skinsFolder: root)
    #expect(settings.skins.isEmpty)
    #expect(settings.clock == .system && settings.skin == nil && settings.loginItemPath == nil)
    defaults.set(true, forKey: "usageLog")
    defaults.set(true, forKey: "allHats")
    #expect(settings.usageLog && settings.allHats)
    defaults.set("future-clock", forKey: "clock")
    #expect(settings.clock == .system)
    for name in ["Rose", "Mint"] {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
    }
    try Data("not a Skin folder".utf8).write(to: root.appendingPathComponent("notes.txt"))
    #expect(Set(settings.skins) == ["Rose", "Mint"])
    settings.skin = "Rose"
    settings.clock = .twelveHour
    settings.loginItemPath = "/Applications/Pix.app"
    let restored = Settings(defaults: try fixture.defaults(), skinsFolder: root)
    #expect(restored.skinFolder == root.appendingPathComponent("Rose", isDirectory: true))
    #expect(restored.clock == .twelveHour && restored.loginItemPath == "/Applications/Pix.app")
    let other = SettingsFixture()
    defer { other.remove() }
    let independent = Settings(defaults: try other.defaults(), skinsFolder: root.appendingPathComponent("missing"))
    #expect(independent.skin == nil && independent.clock == .system && independent.skins.isEmpty)
    #expect(!independent.usageLog && !independent.allHats)
    settings.skin = nil
    settings.loginItemPath = nil
    #expect(defaults.object(forKey: "skin") == nil && defaults.object(forKey: "loginItemPath") == nil)
}
