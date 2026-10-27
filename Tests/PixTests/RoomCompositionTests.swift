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
@Test func theMonitorsStayFullOfCodeThroughoutTheirScroll() throws {
    let composition = RoomComposition(effects: RoutineEffects(saveGarden: { _ in }))
    let host = CALayer()
    composition.build(in: host, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)),
                      room: Room(spot: .desk, activity: .coding, mood: .content, fps: 12))
    let world = try #require(composition.world)
    let lines = world.sublayers?.compactMap { $0.sublayers?.first { $0.animation(forKey: "scroll") != nil } } ?? []
    #expect(lines.count == Art.monitors.count)
    for code in lines {
        let screen = try #require(code.superlayer).bounds
        let scroll = try #require(code.animation(forKey: "scroll") as? CABasicAnimation)
        let by = try #require(scroll.byValue as? CGFloat)
        for step in 0...4 {
            let shown = code.frame.offsetBy(dx: 0, dy: by * CGFloat(step) / 4)
            #expect(shown.contains(screen), "\(step)/4 of the way, the code no longer covers the screen")
        }
    }
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
    var deadlines: [Date] = []
    var cancellations = 0
    var garden = Garden()
    var captions: [Caption] = []
    var observations: [(Date, TimeZone)] = []
    var saves: [Garden] = []
    let host = CALayer()
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    lazy var composition: RoomComposition = {
        let composition = RoomComposition(
            routine: Routine(timeZone: zone, random: { 0 }, garden: garden, thirstRandom: { 0 }),
            effects: RoutineEffects(now: { self.reads += 1; return self.time }, wake: { deadline, work in
                self.wakes.append(work)
                self.deadlines.append(deadline)
                return { self.cancellations += 1 }
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

/// Every animation in `layer` and below that loops forever.
@MainActor
private func loops(in layer: CALayer) -> [(layer: String, key: String, animation: CAAnimation)] {
    let own = (layer.animationKeys() ?? []).compactMap { key in
        layer.animation(forKey: key).map { (layer.name ?? "unnamed", key, $0) }
    }.filter { $0.2.repeatCount == .infinity }
    return own + (layer.sublayers ?? []).flatMap { loops(in: $0) }
}

@MainActor
@Test(arguments: [Spot.window, .desk])
func aNewFrameCapReachesEverythingThatLoopsInTheRoom(at spot: Spot) throws {
    let execution = RoomExecution()
    execution.time = ISO8601DateFormatter().date(from: "2026-10-31T22:00:00Z")!  // Halloween night: glows, bats and stars
    execution.build(at: spot)
    defer { execution.composition.stop() }
    let world = try #require(execution.composition.world)
    execution.composition.update(to: Room(spot: spot, activity: .other, mood: .content, fps: 6))
    let looping = loops(in: world)
    #expect(looping.contains { $0.key == "flicker" } && looping.contains { $0.key == "scroll" })
    if spot == .window { #expect(looping.contains { $0.key == "flap" } && looping.contains { $0.key == "twinkle" }) }
    for loop in looping {
        #expect(loop.animation.preferredFrameRateRange.maximum == 6, "\(loop.layer)'s \(loop.key) kept its old cap")
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
    #expect(execution.drawing("deskSteam") === oldSteam)  // a new cap re-caps the steam rather than redrawing it
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

@MainActor
@Test func composedWakeIsReplacedByEachEventAndCannotReachTheRoutineOnceSupersededOrStopped() throws {
    let execution = RoomExecution()
    execution.build(at: .window)
    let first = try #require(execution.wakes.first)
    #expect(execution.deadlines.first == execution.time + 30)
    let cancellations = execution.cancellations
    execution.composition.refreshTime()
    #expect(execution.cancellations == cancellations + 1)
    execution.time = try #require(execution.deadlines.first)
    let reads = execution.reads
    first() // Deliberately deliver despite cancellation.
    #expect(execution.reads == reads)
    let current = try #require(execution.wakes.last)
    current()
    #expect(execution.reads == reads + 1)
    // A due wake during a Stroll is held for arrival, without another step.
    try execution.finish()
    #expect(execution.composition.step == .fidget(.gaze))
    try execution.finish()
    let beforeStop = try #require(execution.wakes.last)
    execution.composition.stop()
    let afterStop = execution.reads
    beforeStop()
    #expect(execution.reads == afterStop)
}

@MainActor
@Test func composedMinuteRefreshesPropsWithOneTimeObservationAndKeepsAnUnchangedGarden() {
    let execution = RoomExecution()
    execution.build()
    defer { execution.composition.stop() }
    #expect(execution.saves.count == 1) // Newly adopted plants are kept.
    let step = execution.composition.step
    let reads = execution.reads
    execution.time += 3 * 3600
    execution.composition.refreshTime()
    #expect(execution.composition.step == step)
    #expect(execution.reads == reads + 1)
    #expect(execution.composition.props.thirstyPlants == Set(Art.plantProps.map(Plant.init)))
    #expect(execution.saves.count == 1)
}

@MainActor
@Test func composedCareSavesTheGardenOnceAndANewCompositionRestoresIt() throws {
    let execution = RoomExecution()
    execution.garden.adopt(Art.plantProps.map(Plant.init), at: execution.time - 4 * 3600, random: { 0 })
    execution.build()
    defer { execution.composition.stop() }
    #expect(execution.saves.isEmpty)
    execution.time += 30
    let wake = try #require(execution.wakes.last)
    wake()
    let plant = Plant(strip: "desk", x: 404)
    #expect(execution.composition.step == .errand(.waterPlant(plant, fromRight: true)))
    try execution.finish() // Arrive at the plant.
    #expect(execution.saves.isEmpty)
    try execution.finish() // Water it.
    #expect(execution.saves.count == 1)
    #expect(!execution.composition.props.thirstyPlants.contains(plant))
    try execution.finish() // Return home.
    #expect(execution.saves.count == 1)
    let restored = RoomExecution()
    restored.garden = execution.saves[0]
    #expect(!restored.composition.props.thirstyPlants.contains(plant))
}
