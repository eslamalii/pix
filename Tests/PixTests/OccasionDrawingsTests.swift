import AppKit
import Testing
import AmbientCore
@testable import Pix

private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

/// A Room at the window on a day, with that day's Occasion Props already placed (no tour), and the clock to move.
@MainActor
private final class OccasionDay {
    let composition: RoomComposition
    let host = CALayer()

    init(_ start: String, placedOn: String? = nil, art: ArtFiles = ArtFiles(), fps: Int = 12) {
        let zone = TimeZone(secondsFromGMT: 0)!
        let saved = Routine.Saved(occasionPropsPlacedOn: placedOn ?? String(start.prefix(10)))
        let holder = TimeHolder()
        composition = RoomComposition(
            routine: Routine(timeZone: zone, random: { 0 }, saved: saved),
            effects: RoutineEffects(now: { holder.time }, wake: { _, _ in {} }),
            timing: PlaybackTiming(transaction: { animations, _ in animations() }, after: { _, _ in {} }),
            timeZone: zone, art: art)
        self.holder = holder
        holder.time = date(start)
        composition.build(in: host, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)),
                          room: Room(spot: .window, activity: .other, mood: .content, fps: fps))
    }
    private let holder: TimeHolder
    private final class TimeHolder { var time = Date() }

    func move(to text: String) {
        holder.time = date(text)
        composition.refreshTime()
    }

    var stage: CALayer { composition.world!.sublayers!.first { $0.name == "occasionProps" }! }
    var perches: [CALayer] { stage.sublayers?.filter { $0.name == "occasionProp" } ?? [] }
    var glows: [CALayer] { stage.sublayers?.filter { $0.name == "occasionGlow" } ?? [] }
    var sky: CALayer { composition.world!.sublayers!.first { $0.name == "skyBox" }!.sublayers!.first { $0.name == "skyLife" }! }
}

@MainActor
@Test(arguments: [("2026-10-31", "flicker"), ("2026-12-25", "twinkle"), ("2027-01-01", "sparkle")])
func eachOccasionsPlacedPropsGlowAtNightAndNotByDay(day: String, key: String) {
    let night = OccasionDay(day + "T22:00:00Z")
    defer { night.composition.stop() }
    #expect(night.glows.count == 4)
    for glow in night.glows {
        #expect(!glow.isHidden)
        #expect(glow.animation(forKey: key)?.preferredFrameRateRange.maximum == 12)
    }
    night.move(to: day + "T12:00:00Z")
    #expect(night.glows.count == 4 && night.glows.allSatisfy(\.isHidden))
    night.move(to: day + "T18:00:00Z")  // dusk
    #expect(night.glows.allSatisfy { !$0.isHidden })
}

@MainActor
@Test func aGlowShowsOnlyOnceItsPropIsPlaced() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let time = date("2026-10-31T22:00:00Z")
    let composition = RoomComposition(
        routine: Routine(timeZone: zone, random: { 0 }),  // not placed yet: the tour starts
        effects: RoutineEffects(now: { time }, wake: { _, _ in {} }),
        timing: PlaybackTiming(transaction: { animations, _ in animations() }, after: { _, _ in {} }), timeZone: zone)
    composition.build(in: CALayer(), geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)),
                      room: Room(spot: .desk, activity: .other, mood: .content, fps: 12))
    defer { composition.stop() }
    let stage = composition.world!.sublayers!.first { $0.name == "occasionProps" }!
    let glows = stage.sublayers!.filter { $0.name == "occasionGlow" }
    #expect(glows.count == 4 && glows.allSatisfy(\.isHidden))
}

@MainActor
@Test func aNewFrameCapReachesThePerchGlows() {
    let day = OccasionDay("2026-12-25T22:00:00Z")
    defer { day.composition.stop() }
    day.composition.update(to: Room(spot: .window, activity: .other, mood: .content, fps: 6))
    #expect(day.glows.count == 4)
    for glow in day.glows { #expect(glow.animation(forKey: "twinkle")?.preferredFrameRateRange.maximum == 6) }
}

@MainActor
@Test func crossingMidnightOutOfHalloweenTheDaysPropsAndGlowsLeaveTheSeasonStaysAndTheDaysArtIsReleased() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    let cells = Art.perches.count * Art.occasionProp
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.2)
    let art = ArtFiles(classicFolder: fixture.classic)
    let day = OccasionDay("2026-10-31T22:00:00Z", art: art)
    defer { day.composition.stop() }
    #expect(day.perches.count == 4 && day.glows.count == 4)
    let seasonal = day.stage.sublayers!.count - (day.perches.count + day.glows.count)  // the strips and the flickering faces and flames
    #expect(seasonal == Art.strips.count + Halloween.glows.count)
    #expect(day.sky.sublayers?.filter { $0.animation(forKey: "fly") != nil }.count == 3)
    let before = try #require(art.occasionPropSheet(.halloween)?.dataProvider?.data as Data?)

    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.5)
    day.move(to: "2026-10-31T23:00:00Z")  // later the same day: still cached
    #expect((art.occasionPropSheet(.halloween)?.dataProvider?.data as Data?) == before, "the sheet was dropped mid-day")
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.2)

    day.move(to: "2026-11-01T00:00:00Z")
    #expect(day.perches.isEmpty && day.glows.isEmpty)
    #expect(day.stage.sublayers?.count == seasonal)
    #expect(day.sky.sublayers?.filter { $0.animation(forKey: "fly") != nil }.count == 3)
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.8)
    let after = try #require(art.occasionPropSheet(.halloween)?.dataProvider?.data as Data?)
    #expect(after != before, "the day's art stayed cached")
}

@MainActor
@Test func crossingMidnightOutOfTheSeasonItsPropsAndGlowsLeaveTheRoom() {
    let day = OccasionDay("2026-11-01T22:00:00Z")
    defer { day.composition.stop() }
    #expect(day.stage.sublayers?.count == Art.strips.count + Halloween.glows.count)
    day.move(to: "2026-11-02T00:00:00Z")
    #expect(day.stage.sublayers?.isEmpty != false)
    #expect(day.sky.sublayers?.contains { $0.animation(forKey: "fly") != nil } == false)
}

@MainActor
@Test func theDaysArtLoadsOnlyOnAnOccasionDay() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    let cells = Art.perches.count * Art.occasionProp
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.2)
    let day = OccasionDay("2026-11-05T12:00:00Z", placedOn: "2026-10-31", art: ArtFiles(classicFolder: fixture.classic))
    defer { day.composition.stop() }
    #expect(day.perches.isEmpty && day.glows.isEmpty)
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.8)
    let latest = try #require(ArtFiles(classicFolder: fixture.classic).occasionPropSheet(.halloween)?.dataProvider?.data as Data?)
    day.move(to: "2026-10-31T12:00:00Z")  // the first load, so it reads the file as it is now
    let image = try #require(day.perches.first?.contents) as! CGImage
    #expect((image.dataProvider?.data as Data?) == latest)
}

@MainActor
@Test func aRoomRebuiltAfterTheOccasionHasEndedReleasesTheDaysArtToo() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    let cells = Art.perches.count * Art.occasionProp
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.2)
    let art = ArtFiles(classicFolder: fixture.classic)
    let day = OccasionDay("2026-10-31T22:00:00Z", art: art)
    defer { day.composition.stop() }
    let before = try #require(art.occasionPropSheet(.halloween)?.dataProvider?.data as Data?)
    day.composition.stop()
    day.move(to: "2026-11-01T00:00:00Z")  // the scene is off while midnight passes
    day.composition.build(in: day.host, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)),
                          room: Room(spot: .window, activity: .other, mood: .content, fps: 12))
    try fixture.draw(Art.occasionPropSheet("halloween"), in: fixture.classic, width: cells, height: Art.occasionProp, shade: 0.8)
    let after = try #require(art.occasionPropSheet(.halloween)?.dataProvider?.data as Data?)
    #expect(after != before, "the rebuilt Room kept the ended day's art cached")
}
