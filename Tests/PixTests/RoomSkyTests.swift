import AppKit
import Testing
import AmbientCore
@testable import Pix

private func skyTime(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
private var skyCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

@MainActor
private func windowSky() -> (sky: RoomSky, world: CALayer, life: CALayer) {
    let world = CALayer()
    let halloween = HalloweenLayers()
    let sky = RoomSky(halloween: halloween)
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    sky.build(in: world, geometry: geometry)
    halloween.build(in: world, geometry: geometry, frameRange: capped(12))
    let box = world.sublayers!.first { $0.name == "skyBox" }!
    return (sky, world, box.sublayers!.first { $0.name == "skyLife" }!)
}

@MainActor
@Test func visibleSkyReusesUnchangedDrawingsAndClearsWhenHidden() throws {
    let (sky, world, life) = windowSky()
    let time = skyTime("2026-10-21T12:00:00Z")
    sky.refresh(at: time, calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.isEmpty != false)
    sky.show(true)
    let cloud = try #require(life.sublayers?.first)
    #expect(life.sublayers?.count == 3)
    sky.refresh(at: time + 60, calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.first === cloud)
    sky.show(false)
    #expect(life.sublayers?.isEmpty != false)
    sky.refresh(at: skyTime("2026-12-01T12:00:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.isEmpty != false)
    sky.show(true)
    #expect(life.sublayers?.contains { $0.animation(forKey: "fall") != nil } == true)
    sky.stop()
    #expect(life.sublayers?.isEmpty != false)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func snowChangesAtMidnightWithoutADaylightChange() {
    let (sky, world, life) = windowSky()
    sky.show(true)
    sky.refresh(at: skyTime("2026-11-30T23:59:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "fall") != nil } == false)
    sky.refresh(at: skyTime("2026-12-01T00:00:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.filter { $0.animation(forKey: "fall") != nil }.count == 10)
    sky.refresh(at: skyTime("2027-02-01T00:00:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "fall") != nil } == false)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func visibleSkyAdoptsFrameCapsAndBatterySnowDensity() {
    let (sky, world, life) = windowSky()
    let time = skyTime("2026-12-01T12:00:00Z")
    sky.show(true)
    sky.refresh(at: time, calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.filter { $0.animation(forKey: "fall") != nil }.count == 10)
    sky.refresh(at: time, calendar: skyCalendar, fps: 6)
    #expect(life.sublayers?.filter { $0.animation(forKey: "fall") != nil }.count == 5)
    for child in life.sublayers ?? [] {
        for key in child.animationKeys() ?? [] {
            #expect(child.animation(forKey: key)?.preferredFrameRateRange.maximum == 6)
        }
    }
    withExtendedLifetime(world) {}
}

@MainActor
@Test func halloweenSkyEntersAndLeavesItsSeasonWhileVisible() {
    let (sky, world, life) = windowSky()
    sky.show(true)
    sky.refresh(at: skyTime("2026-10-23T23:59:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "fly") != nil } == false)
    sky.refresh(at: skyTime("2026-10-24T00:00:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.filter { $0.animation(forKey: "fly") != nil }.count == 3)
    sky.refresh(at: skyTime("2026-11-02T00:00:00Z"), calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "fly") != nil } == false)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func halloweenGlowsKeepFlickeringAtTheNewCapWhenTheBatteryTakesOver() {
    let (sky, world, _) = windowSky()
    let night = skyTime("2026-10-26T21:00:00Z")
    sky.refresh(at: night, calendar: skyCalendar, fps: 12)
    sky.refresh(at: night + 60, calendar: skyCalendar, fps: 6)
    let stage = world.sublayers?.first { $0.name == "occasionProps" }
    let flickers = stage?.sublayers?.compactMap { $0.animation(forKey: "flicker") } ?? []
    #expect(!flickers.isEmpty)
    for flicker in flickers {
        #expect(flicker.preferredFrameRateRange == CAFrameRateRange(minimum: 6, maximum: 6, preferred: 6))
    }
    withExtendedLifetime(world) {}
}

@MainActor
@Test func changingTimeZoneUpdatesTheSkyAtTheSameInstant() {
    let (sky, world, life) = windowSky()
    let time = skyTime("2026-10-21T12:00:00Z")
    sky.show(true)
    sky.refresh(at: time, calendar: skyCalendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "drift") != nil } == true)
    var calendar = skyCalendar
    calendar.timeZone = TimeZone(secondsFromGMT: 10 * 3600)!
    sky.refresh(at: time, calendar: calendar, fps: 12)
    #expect(life.sublayers?.contains { $0.animation(forKey: "twinkle") != nil } == true)
    #expect(life.sublayers?.contains { $0.animation(forKey: "drift") != nil } == false)
    withExtendedLifetime(world) {}
}
