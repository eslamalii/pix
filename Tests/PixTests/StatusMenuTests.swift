import AppKit
import Testing
import AmbientCore
@testable import Pix

@MainActor
@Test func menuProjectsChoicesAndOnlyOffersEarnedHats() throws {
    let owner = StatusMenu()
    owner.state = {
        StatusMenu.State(startAtLogin: true, hidden: true,
                         frontApp: ("test.app", "Test", .activity(.coding)), focusLeft: 7,
                         hat: .cap, wearableHats: [.cap], clock: .twelveHour, skin: "Rose", skins: ["Rose", "Mint"])
    }
    var hidden: Bool?, login: Bool?, chosenHat: Hat?, chosenSkin: String?, clock: ClockStyle?
    owner.onHidden = { hidden = $0 }
    owner.onStartAtLogin = { login = $0 }
    owner.onHat = { chosenHat = $0 }
    owner.onSkin = { chosenSkin = $0 }
    owner.onClock = { clock = $0 }
    let menu = NSMenu()
    owner.menuNeedsUpdate(menu)
    func item(_ title: String, in menu: NSMenu) throws -> NSMenuItem { try #require(menu.items.first { $0.title == title }) }
    func choose(_ entry: NSMenuItem) throws {
        let action = try #require(entry.action)
        #expect(NSApplication.shared.sendAction(action, to: entry.target, from: entry))
    }
    try choose(item("Show Pix", in: menu))
    #expect(hidden == false)
    let loginItem = try item("Start at Login", in: menu)
    #expect(loginItem.state == .on)
    try choose(loginItem)
    #expect(login == false)
    #expect(menu.items.contains { $0.title == "Stop Focus (7 min left)" })
    let hats = try #require(item("Hat", in: menu).submenu)
    let cap = try item("Cap", in: hats)
    #expect(cap.state == .on)
    try choose(cap)
    #expect(chosenHat == .cap)
    #expect(hats.items.contains { $0.title.hasPrefix("Crown (") && $0.action == nil })
    let skins = try #require(item("Skin", in: menu).submenu)
    #expect(try item("Rose", in: skins).state == .on)
    try choose(item("Mint", in: skins))
    #expect(chosenSkin == "Mint")
    let styles = try #require(item("Clock", in: menu).submenu)
    #expect(try item(ClockStyle.twelveHour.title, in: styles).state == .on)
    try choose(item(ClockStyle.twentyFourHour.title, in: styles))
    #expect(clock == .twentyFourHour)
    let treatment = try #require(item("Treat Test as", in: menu).submenu)
    #expect(try item("Coding", in: treatment).state == .on)
    // A rebuild reads fresh state rather than retaining old checkmarks.
    owner.state = { StatusMenu.State() }
    owner.menuNeedsUpdate(menu)
    #expect(menu.items.first?.title == "Hide Pix")
    #expect(try item("Start at Login", in: menu).state == .off)
    #expect(!menu.items.contains { $0.title == "Treat Test as" })
}
