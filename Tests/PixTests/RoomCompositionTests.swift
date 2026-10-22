import AppKit
import Testing
import AmbientCore
@testable import Pix

@MainActor
@Test func composedRoomPreservesDrawingOrderHostPolicyAndRebuildCleanup() throws {
    let composition = RoomComposition(effects: RoutineEffects(saveGarden: { _ in }))
    let host = CALayer()
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    let room = Room(spot: .window, activity: .other, mood: .content, fps: 12)
    composition.build(in: host, geometry: geometry, room: room)
    let world = try #require(composition.world)
    let children = try #require(world.sublayers)
    let patches = try #require(children.firstIndex { $0.name == "propPatches" })
    let occasion = try #require(children.firstIndex { $0.name == "occasionProps" })
    let pix = try #require(children.firstIndex(of: composition.pix))
    let light = try #require(children.firstIndex { $0.name == "lampGlow" })
    let strip = try #require(children.lastIndex { $0.name == "roomStrip" })
    #expect(strip < patches && patches < occasion && occasion < pix && pix < light)
    #expect(world.actions?["sublayers"] is NSNull)
    #expect(composition.pix.actions?["sublayers"] is NSNull)
    #expect(world.position.x == geometry.scroll(for: .window))
    composition.build(in: host, geometry: geometry, room: room)
    #expect(world.superlayer == nil)
    #expect(world.sublayers?.contains(composition.pix) == false)
    #expect(host.sublayers?.count == 1)
    composition.stop()
    #expect(composition.world == nil)
    #expect(host.sublayers?.isEmpty != false)
    #expect(composition.pix.superlayer == nil)
    composition.stop()
}

@MainActor
private final class RoomExecution {
    let zone = TimeZone(secondsFromGMT: 0)!
    var time = Date(timeIntervalSince1970: 12 * 3600)
    var reads = 0
    var transactions: [@MainActor () -> Void] = []
    var beats: [@MainActor () -> Void] = []
    var wakes: [@MainActor () -> Void] = []
    var captions: [Caption] = []
    var observations: [(Date, TimeZone)] = []
    var saves: [Garden] = []
    let host = CALayer()
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    lazy var composition: RoomComposition = {
        let composition = RoomComposition(
            routine: Routine(timeZone: zone, random: { 0 }, thirstRandom: { 0 }),
            effects: RoutineEffects(now: { self.reads += 1; return self.time }, wake: { _, work in
                self.wakes.append(work)
                return {}
            }, saveGarden: { self.saves.append($0) }),
            timing: PlaybackTiming(transaction: { animations, completion in
                animations()
                self.transactions.append(completion)
            }, after: { _, work in
                self.beats.append(work)
                return {}
            }), timeZone: zone)
        composition.onCaption = { self.captions.append($0) }
        composition.onTime = { self.observations.append(($0, $1)) }
        return composition
    }()

    func build(at spot: Spot = .desk) {
        composition.build(in: host, geometry: geometry,
                          room: Room(spot: spot, activity: .other, mood: .content, fps: 12))
    }

    func finish() throws {
        let completion = try #require(transactions.last)
        completion()
    }

    func refill() throws {
        time += 30
        let wake = try #require(wakes.last)
        wake()
        #expect(composition.step == .errand(.refillMug))
        try finish() // Arrive at the coffee machine.
        #expect(composition.step == .use(.refillMug))
        try finish() // Pour.
        #expect(composition.step == .walkBack(to: .desk))
        try finish() // Return and set the mug down.
        #expect(composition.step == .idle(.desk, .content))
    }

    func drawing(_ name: String) -> CALayer? {
        func find(_ layer: CALayer) -> CALayer? {
            if layer.name == name { return layer }
            return layer.sublayers?.lazy.compactMap { find($0) }.first
        }
        return find(host)
    }
}

@MainActor
@Test func composedRefillUpdatesMugAndSteamAndMinuteCanRemoveSteamWithoutANewStep() throws {
    let execution = RoomExecution()
    execution.build()
    defer { execution.composition.stop() }
    try execution.refill()
    #expect(execution.composition.props.mugSteams)
    #expect(execution.drawing("mugGone")?.isHidden == true)
    #expect(execution.drawing("deskSteam") != nil)
    let oldSteam = try #require(execution.drawing("deskSteam"))
    execution.composition.update(to: Room(spot: .desk, activity: .other, mood: .content, fps: 6))
    #expect(oldSteam.superlayer == nil)
    #expect(execution.drawing("deskSteam")?.animation(forKey: "flight")?.preferredFrameRateRange.maximum == 6)
    #expect(execution.composition.pix.sublayers?.contains { $0.animation(forKey: "frames")?.preferredFrameRateRange.maximum == 6 } == true)
    let step = execution.composition.step
    execution.time = Date(timeIntervalSince1970: 17 * 3600)
    execution.composition.refreshTime()
    #expect(execution.composition.step == step)
    #expect(!execution.composition.props.mugSteams)
    #expect(execution.drawing("deskSteam") == nil)
}

@MainActor
@Test func composedInterruptionRejectsOldCompletionAndRestoresDeskSteam() throws {
    let execution = RoomExecution()
    execution.build()
    defer { execution.composition.stop() }
    try execution.refill()
    execution.composition.play(.reaction(.wave))
    let obsolete = try #require(execution.transactions.last)
    execution.composition.play(.reaction(.pet))
    #expect(execution.drawing("deskSteam") == nil)
    obsolete()
    #expect(execution.composition.step == .moment(.reaction(.pet)))
    try execution.finish()
    #expect(execution.composition.step == .idle(.desk, .content))
    #expect(execution.drawing("deskSteam") != nil)
    #expect(execution.captions.count == 2)
}

@MainActor
@Test func composedPastimeShowsSkyThenGreetingBeforeQueuedMoment() throws {
    let execution = RoomExecution()
    execution.composition.play(.greeting(.hello, after: .gaze))
    execution.build()
    defer { execution.composition.stop() }
    #expect(execution.composition.step == .pastime(.gaze))
    #expect(execution.drawing("skyLife")?.sublayers?.filter { $0.animation(forKey: "drift") != nil }.count == 3)
    execution.composition.play(.reaction(.pet))
    let beat = try #require(execution.beats.last)
    beat()
    #expect(execution.composition.step == .moment(.greeting(.hello, after: .gaze)))
    try execution.finish()
    #expect(execution.composition.step == .moment(.reaction(.pet)))
    try execution.finish()
    #expect(execution.composition.step == .walk(to: .desk))
    try execution.finish()
    #expect(execution.composition.step == .idle(.desk, .content))
}

@MainActor
@Test func composedRebuildPreservesPropsAndRejectsOldWorkAndPendingMoments() throws {
    let execution = RoomExecution()
    execution.build()
    try execution.refill()
    let garden = execution.composition.props.thirstyPlants
    execution.composition.play(.reaction(.wave))
    let obsolete = try #require(execution.transactions.last)
    let oldWake = try #require(execution.wakes.last)
    let oldWorld = try #require(execution.composition.world)
    execution.composition.stop()
    execution.composition.play(.greeting(.hello, after: .gaze))
    execution.composition.stop() // Hiding before drawings exist also drops a waiting Greeting.
    execution.build()
    defer { execution.composition.stop() }
    obsolete()
    oldWake()
    #expect(oldWorld.superlayer == nil)
    #expect(execution.host.sublayers?.count == 1)
    #expect(execution.composition.step == .idle(.desk, .content))
    #expect(execution.composition.props.mugSteams)
    #expect(execution.composition.props.thirstyPlants == garden)
    #expect(execution.drawing("deskSteam") != nil)
    #expect(execution.captions.count == 1)
    #expect(execution.saves.count == 1)
}

@MainActor
@Test func composedTimeRefreshSharesObservationAndFrameRateUpdateKeepsBusyStep() throws {
    let execution = RoomExecution()
    execution.build(at: .window)
    defer { execution.composition.stop() }
    execution.time += 3600
    var reads = execution.reads
    execution.composition.refreshTime()
    #expect(execution.reads == reads + 1)
    #expect(execution.observations.last?.0 == execution.time)
    reads = execution.reads
    let zone = TimeZone(secondsFromGMT: 9 * 3600)!
    execution.composition.timeZoneChanged(zone)
    #expect(execution.reads == reads + 1)
    #expect(execution.observations.last?.1 == zone)
    #expect(execution.drawing("skyLife")?.sublayers?.contains { $0.animation(forKey: "twinkle") != nil } == true)
    let step = execution.composition.step
    let transactions = execution.transactions.count
    execution.composition.update(to: Room(spot: .window, activity: .other, mood: .content, fps: 6))
    #expect(execution.composition.step == step)
    #expect(execution.transactions.count == transactions)
    try execution.finish()
    let beat = try #require(execution.beats.last)
    beat()
    #expect(execution.transactions.last != nil)
    // The glance started after the busy walk takes the new cap.
    #expect(execution.composition.pix.sublayers?.contains { $0.animation(forKey: "glance")?.preferredFrameRateRange.maximum == 6 } == true)
}

@MainActor
@Test func composedSynchronousWalkCompletionSettlesBeforeBuildReturns() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let composition = RoomComposition(routine: Routine(timeZone: zone),
        effects: RoutineEffects(now: { Date(timeIntervalSince1970: 12 * 3600) }, saveGarden: { _ in }),
        timing: PlaybackTiming(transaction: { animations, completion in animations(); completion() }, after: { _, _ in {} }), timeZone: zone)
    let host = CALayer()
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    composition.build(in: host, geometry: geometry, room: Room(spot: .window, activity: .other, mood: .content, fps: 12))
    composition.stop()
    composition.build(in: host, geometry: geometry, room: Room(spot: .desk, activity: .coding, mood: .content, fps: 12))
    #expect(composition.step == .idle(.desk, .content))
    #expect(composition.pix.position.x == geometry.rest(at: .desk).x)
    composition.stop()
}
