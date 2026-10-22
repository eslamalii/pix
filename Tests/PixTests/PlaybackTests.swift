import AppKit
import Testing
import AmbientCore
@testable import Pix

@MainActor
private final class PlaybackWaits {
    var transactions: [@MainActor () -> Void] = []
    var beats: [@MainActor () -> Void] = []
    var cancelled = 0
    var finiteFlightsInTransaction = 0
    var host: CALayer?

    var timing: PlaybackTiming {
        PlaybackTiming(transaction: { animations, completion in
            animations()
            self.transactions.append(completion)
            self.finiteFlightsInTransaction = self.host?.sublayers?.filter {
                ($0.animation(forKey: "flight")?.repeatCount ?? .infinity).isFinite
            }.count ?? 0
        }, after: { _, work in
            self.beats.append(work)
            return { self.cancelled += 1 }
        })
    }
}

@MainActor
private func playing(_ waits: PlaybackWaits, at spot: Spot = .window) -> (Playback, CALayer) {
    let playback = Playback(timing: waits.timing)
    let world = CALayer()
    playback.build(in: world, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)), at: spot, mood: .content)
    waits.host = playback.pix
    return (playback, world)
}

@MainActor
@Test func interruptedWalkCannotCompleteItsReplacement() throws {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits)
    var finished = 0
    playback.onFinished = { finished += 1 }
    playback.run(.stroll(to: .left))
    let old = try #require(waits.transactions.last)
    playback.run(.moment(.reaction(.wave)))
    let replacement = try #require(waits.transactions.last)
    old()
    #expect(finished == 0)
    replacement()
    replacement()
    #expect(finished == 1)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func relookKeepsWalkAndItsCompletion() throws {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits)
    var finished = 0
    playback.onFinished = { finished += 1 }
    playback.run(.stroll(to: .left))
    let completion = try #require(waits.transactions.last)
    let before = try #require(playback.pix.animation(forKey: "slide-position.x"))
    playback.run(.relook(.sleepy))
    #expect(playback.step == .stroll(to: .left))
    #expect(playback.pix.animation(forKey: "slide-position.x")?.duration == before.duration)
    #expect(waits.transactions.count == 1)
    completion()
    #expect(finished == 1)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func stoppingPlaybackInvalidatesDelayedAndAnimationCallbacks() throws {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits)
    var finished = 0
    playback.onFinished = { finished += 1 }
    playback.run(.stroll(to: .left))
    let oldWalk = try #require(waits.transactions.last)
    playback.run(.stop(at: .left, body: nil))
    let oldBeat = try #require(waits.beats.last)
    playback.stop()
    oldWalk()
    oldBeat()
    #expect(finished == 0)
    #expect(waits.transactions.count == 1)
    #expect(waits.cancelled == 1)
    #expect(playback.pix.superlayer == nil)
    #expect(playback.pix.animationKeys()?.isEmpty != false)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func momentEffectsJoinFiniteTransactionAndClearOnInterruption() {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits)
    playback.run(.moment(.reaction(.pet)))
    #expect(waits.finiteFlightsInTransaction == 3)
    #expect(playback.pix.sublayers?.filter { $0.animation(forKey: "flight") != nil }.count == 3)
    playback.run(.idle(.window, .content))
    #expect(playback.pix.sublayers?.contains { $0.animation(forKey: "flight") != nil } == false)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func stoppingDeskSteamPreservesRestingRecordAndMomentEffects() {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits, at: .desk)
    let drawings = RoomProps()
    drawings.build(in: world, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)))
    var routine = Routine(timeZone: TimeZone(secondsFromGMT: 0)!, random: { 0 })
    let noon = Date(timeIntervalSince1970: 12 * 3600)
    let room = Room(spot: .desk, activity: .coding, mood: .content, fps: 12)
    routine.handle(.sceneStarted(room), at: noon)
    // First desk Fidget refills the mug: arrive, pour, then return.
    routine.handle(.wake, at: noon + 30)
    routine.handle(.finished, at: noon + 30)
    routine.handle(.finished, at: noon + 30)
    routine.handle(.finished, at: noon + 30)
    var routineProps = routine.props(at: noon + 30)
    playback.onStepChanged = { [weak playback] in drawings.update(routineProps, step: playback?.step, fps: 12) }
    playback.update(routineProps)
    playback.run(.idle(.desk, .content))
    #expect(world.sublayers?.filter { $0.animation(forKey: "flight") != nil }.count == 1)
    routineProps = routine.props(at: noon + 6 * 3600)
    drawings.update(routineProps, step: playback.step, fps: 12)
    #expect(world.sublayers?.contains { $0.animation(forKey: "flight") != nil } == false)
    playback.run(.idle(.musicCorner, .content))
    let glints = world.sublayers?.filter { $0.animation(forKey: "turn") != nil } ?? []
    #expect(glints.count == 2)
    playback.run(.moment(.reaction(.pet)))
    routineProps = routine.props(at: noon + 6 * 3600)
    drawings.update(routineProps, step: playback.step, fps: 12)
    #expect(glints.allSatisfy { $0.superlayer === world })
    #expect(playback.pix.sublayers?.filter { $0.animation(forKey: "flight") != nil }.count == 3)
    playback.stop()
    drawings.stop()
    #expect(world.sublayers?.isEmpty != false)
}

@MainActor
@Test func interruptedStrollStopCannotStartItsRemainingBody() throws {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits)
    var finished = 0
    playback.onFinished = { finished += 1 }
    playback.run(.stop(at: .right, body: "stretch"))
    let initialBeat = try #require(waits.beats.last)
    initialBeat() // The initial beat ends and the glance starts.
    let glanceDone = try #require(waits.transactions.last)
    playback.run(.moment(.reaction(.wave)))
    let momentDone = try #require(waits.transactions.last)
    glanceDone()
    #expect(waits.transactions.count == 2) // No obsolete stretch starts.
    momentDone()
    #expect(finished == 1)
    withExtendedLifetime(world) {}
}

@MainActor
@Test func aZeroDistanceWalkFinishesOnceWithoutStartingATransaction() {
    let waits = PlaybackWaits()
    let (playback, world) = playing(waits, at: .desk)
    var finished = 0
    playback.onFinished = { finished += 1 }
    playback.run(.walk(to: .desk))
    #expect(finished == 1)
    #expect(waits.transactions.isEmpty)
    withExtendedLifetime(world) {}
}
