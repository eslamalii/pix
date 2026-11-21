import Foundation
import Testing
@testable import AmbientCore

/// Pix has placed Halloween's Props: the tour is over.
private let toured = Routine.Saved(occasionPropsPlacedOn: "2026-10-31")

/// Every step a Fidget wake can ask for at `spot`: one wake per roll of the dice across 0..<1.
private func wakes(at spot: Spot, _ mood: Mood = .content, saved: Routine.Saved = Routine.Saved(), day: (Int, Int, Int) -> Date = halloween,
                   focusing: Bool = false) -> [Routine.Step] {
    (0..<20).compactMap { n in
        var routine = Routine(timeZone: utc, random: Dice([0.5, Double(n) / 20 + 0.01, 0]).roll, saved: saved)
        var room = scene(spot, mood)
        room.focusing = focusing
        routine.handle(.sceneStarted(room), at: day(12, 0, 0))
        return routine.handle(.wake, at: day(12, 1, 0))
    }
}

private func festiveSteps(_ steps: [Routine.Step]) -> [Routine.Step] {
    steps.filter { step in
        switch step {
        case .fidget(.celebrate), .fidget(.spin), .errand(.admireOccasionProp): true
        default: false
        }
    }
}

@Test(arguments: [Spot.desk, .couch])
func onAnOccasionDayAfterTheTourTheFestiveFidgetsJoinTheSpotsUsualOnes(spot: Spot) {
    let steps = wakes(at: spot, saved: toured)
    #expect(steps.contains(.fidget(.celebrate)))
    #expect(steps.contains(.fidget(.spin)))
}

@Test func theWindowsFidgetsJoinThemToo() {  // the Stroll wakes only between walks, so ask the Spot's list
    #expect(Routine.fidgets(for: scene(.window), coffee: nil, festive: true) == [.gaze, .wave, .scratch, .celebrate, .spin, .admire])
}

@Test func theDeskOffersToAdmireAPlacedOccasionProp() {
    #expect(wakes(at: .desk, saved: toured).contains { if case .errand(.admireOccasionProp) = $0 { true } else { false } })
    #expect(!wakes(at: .couch, saved: toured).contains { if case .errand(.admireOccasionProp) = $0 { true } else { false } })
}

@Test func onAnOrdinaryDayTheFestiveFidgetsNeverAppear() {
    for spot in [Spot.desk, .window, .couch] {
        #expect(festiveSteps(wakes(at: spot, day: at)).isEmpty, "\(spot)")
    }
    // Even with a placed-day saved from an earlier Occasion.
    #expect(festiveSteps(wakes(at: .desk, saved: toured, day: at)).isEmpty)
}

@Test func aSleepyPixNeverCelebratesOrAdmires() {
    #expect(festiveSteps(wakes(at: .desk, .sleepy, saved: toured)).isEmpty)
    #expect(festiveSteps(wakes(at: .window, .sleepy, saved: toured)).isEmpty)
}

@Test func aFocusedPixNeverCelebratesOrAdmires() {
    #expect(wakes(at: .desk, .focused, saved: toured).isEmpty)
    #expect(Routine.fidgets(for: scene(.desk, .focused), coffee: nil, festive: true) == [.stretch, .lookaround])  // nothing festive added
}

@Test func beforeTheTourThereAreNoFestiveFidgets() {
    // A Focus session holds the tour off, though the Mood is content and Fidgets are due.
    let steps = wakes(at: .desk, focusing: true)
    #expect(!steps.isEmpty)
    #expect(festiveSteps(steps).isEmpty)
}

@Test func midTourThereIsNothingToWake() {
    var routine = Routine(timeZone: utc, random: Dice([0.5, 0.9]).roll)
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: halloween(12)) == .tourWalk(perch: 0))
    #expect(routine.handle(.wake, at: halloween(12, 1)) == nil)
}

@Test func aMeetingStaysCalm() {
    #expect(Routine.fidgets(for: scene(.call), coffee: nil, festive: true) == [.nod])
}

@Test func theMusicCornerSpinsOnlyOnce() {
    #expect(Routine.fidgets(for: scene(.musicCorner), coffee: nil, festive: true) == [.spin, .celebrate])
}

@Test func admireIsOnlyOfferedWhereAPerchSharesTheStrip() {
    for spot in Spot.allCases {
        let room = scene(spot)
        let hasPerch = Art.perches.contains { $0.strip == Art.spot(spot).strip }
        let canLeave = spot == .desk || spot == .window
        #expect(Routine.fidgets(for: room, coffee: nil, festive: true).contains(.admire) == (hasPerch && canLeave), "\(spot)")
        #expect(!Routine.fidgets(for: room, coffee: nil).contains(.admire), "\(spot)")
    }
}

@Test(arguments: [(0.0, 0), (0.5, 1), (0.99, 2)])
func admiringWalksToAPlacedPerchOnPixsStripAndBack(roll: Double, perch: Int) {
    // Choices at the desk at noon: refill, stretch, lookaround, celebrate, spin, admire.
    var routine = Routine(timeZone: utc, random: Dice([0.5, 0.9, roll]).roll, saved: toured)
    routine.handle(.sceneStarted(scene(.desk)), at: halloween(12))
    #expect(routine.handle(.wake, at: halloween(12, 1)) == .errand(.admireOccasionProp(perch: perch)))
    #expect(Art.perches[perch].strip == Art.spot(.desk).strip)
    #expect(routine.handle(.finished, at: halloween(12, 2)) == .use(.admireOccasionProp(perch: perch)))
    #expect(routine.handle(.finished, at: halloween(12, 3)) == .walkBack(to: .desk))
    #expect(routine.handle(.finished, at: halloween(12, 4)) == idling(.desk))
}

@Test func aMomentCutsAnAdmiringErrandShortAndPixWalksBack() {
    var routine = Routine(timeZone: utc, random: Dice([0.5, 0.9, 0]).roll, saved: toured)
    routine.handle(.sceneStarted(scene(.desk)), at: halloween(12))
    routine.handle(.wake, at: halloween(12, 1))
    routine.handle(.finished, at: halloween(12, 2))  // at the Perch
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: halloween(12, 2)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: halloween(12, 3)) == .walkBack(to: .desk))
}

@Test func anAppSwitchCutsAnAdmiringErrandShort() {
    var routine = Routine(timeZone: utc, random: Dice([0.5, 0.9, 0]).roll, saved: toured)
    routine.handle(.sceneStarted(scene(.desk)), at: halloween(12))
    routine.handle(.wake, at: halloween(12, 1))
    #expect(routine.handle(.roomChanged(scene(.couch)), at: halloween(12, 2)) == .walk(to: .couch))
}

@Test func celebratingLooksLikeAJumpWithTheOccasionsEmote() {
    #expect(Fidget.celebrate.look(on: .halloween) == FidgetLook(body: "jump", emote: "pumpkin", extra: .hop))
    #expect(Fidget.celebrate.look(on: .holidays)?.emote == "star")
    #expect(Fidget.celebrate.look(on: .newYear)?.emote == "star")
    #expect(Fidget.celebrate.look(on: nil)?.emote == "star")
    #expect(Fidget.spin.look(on: .halloween) == FidgetLook(body: "spin"))
}
