import Foundation
import Testing
import AmbientCore

/// Rolls that come back in order, so the Routine's random choices are fixed. 0.5 when they run out.
final class Dice {
    private var rolls: [Double]
    init(_ rolls: [Double]) { self.rolls = rolls }
    func roll() -> Double { rolls.isEmpty ? 0.5 : rolls.removeFirst() }
}

func scene(_ spot: Spot, _ mood: Mood = .content, activity: Activity? = nil, fps: Int = 12) -> Room {
    let usual: Activity = switch spot {
    case .desk: .coding
    case .call: .meeting
    case .couch: .watching
    case .musicCorner: .music
    case .window: .browsing
    }
    return Room(spot: spot, activity: activity ?? usual, mood: mood, fps: fps)
}

/// A Routine with its scene started at `spot`, at noon (the lamp is off and wanted off), with fixed dice.
func started(at spot: Spot, _ mood: Mood = .content, time: Date = at(12), dice: Dice = Dice([])) -> Routine {
    var routine = Routine(timeZone: utc, random: dice.roll)
    routine.handle(.sceneStarted(scene(spot, mood)), at: time)
    if spot == .musicCorner { routine.handle(.finished, at: time) }  // the needle drops on arriving
    return routine
}

/// Idling at the Spot in the Mood.
func idling(_ spot: Spot, _ mood: Mood = .content) -> Routine.Step { .idle(spot, mood) }

// MARK: - Spots and walking

@Test(arguments: [(0.0, 30), (0.5, 60), (0.99, 89)])
func theSceneStartsWithPixIdlingAtItsSpotAndAFidgetDueIn30To90Seconds(roll: Double, seconds: Int) {
    var routine = Routine(timeZone: utc, random: Dice([roll]).roll)
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: at(12)) == .idle(.desk, .content))
    #expect(routine.nextWake.map { Int($0.timeIntervalSince(at(12))) } == seconds)
}

@Test func aNewSpotSendsPixWalkingThereAndItIdlesOnArrival() {
    var routine = started(at: .desk)
    #expect(routine.handle(.roomChanged(scene(.window)), at: at(12, 1)) == .walk(to: .window))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
}

@Test func switchingBetweenTwoAppsThatKeepPixAtTheWindowChangesNothing() {
    var routine = started(at: .window)
    #expect(routine.handle(.roomChanged(scene(.window, activity: .other)), at: at(12, 1)) == nil)
    #expect(routine.handle(.roomChanged(scene(.window, activity: .browsing)), at: at(12, 2)) == nil)
}

@Test func aFrameRateChangeAloneChangesNothing() {
    var routine = started(at: .desk)
    #expect(routine.handle(.roomChanged(scene(.desk, fps: 10)), at: at(12, 1)) == nil)
}

@Test func aNewMoodWhileIdlingShowsAtOnce() {
    var routine = started(at: .desk)
    #expect(routine.handle(.roomChanged(scene(.desk, .grumpy)), at: at(12, 1)) == idling(.desk, .grumpy))
}

@Test func aNewMoodWhileBusyShowsWhenPixIsDone() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    #expect(routine.handle(.roomChanged(scene(.desk, .cheerful)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.desk, .cheerful))
}

@Test func whenFocusedNoFidgetIsDue() {
    var routine = started(at: .desk)
    #expect(routine.handle(.roomChanged(scene(.desk, .focused)), at: at(12, 1)) == .idle(.desk, .focused))
    #expect(routine.nextWake == nil)
}

// MARK: - Moments

@Test func aMomentPlaysAtOnceWhileIdlingThenPixIdlesAgain() {
    var routine = started(at: .window)
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
}

@Test func aNewerMomentReplacesOneStillPlaying() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    #expect(routine.handle(.momentArrived(.reaction(.pet)), at: at(12, 1)) == .moment(.reaction(.pet)))
}

@Test func aMomentDuringAWalkToASpotWaitsForPixToArrive() {
    var routine = started(at: .desk)
    routine.handle(.roomChanged(scene(.window)), at: at(12, 1))
    #expect(routine.handle(.momentArrived(.reaction(.pet)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == .moment(.reaction(.pet)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
}

@Test func aGreetingThatArrivesBeforeTheSceneIsReadyPlaysOnceItIs() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    #expect(routine.handle(.momentArrived(.greeting(.hello)), at: at(12)) == nil)
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: at(12)) == .moment(.greeting(.hello)))
}

@Test func aMomentStillWaitingWhenTheSceneStopsIsDropped() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    routine.handle(.momentArrived(.greeting(.hello)), at: at(12))
    routine.handle(.sceneStopped, at: at(12))
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: at(12, 30)) == idling(.desk))
}

// MARK: - Starting and stopping the scene

@Test func whenTheSpotChangedWhileTheSceneWasStoppedPixWalksBackIntoView() {
    var routine = started(at: .desk)
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.lastSpot == .desk)  // the view starts Pix here
    #expect(routine.handle(.sceneStarted(scene(.window)), at: at(12, 2)) == .walk(to: .window))
    #expect(routine.lastSpot == .window)
}

@Test func aSceneThatStartsAgainAtTheSameSpotResumesIdling() {
    var routine = started(at: .desk)
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: at(12, 2)) == idling(.desk))
}

@Test func nothingHappensWhileTheSceneIsStopped() {
    var routine = started(at: .desk)
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.handle(.roomChanged(scene(.window)), at: at(12, 2)) == nil)
    #expect(routine.handle(.wake, at: at(12, 2)) == nil)
    #expect(routine.handle(.minutePassed, at: at(20)) == nil)
}

// MARK: - The music corner's needle

@Test func arrivingInTheMusicCornerDropsTheNeedleFirst() {
    var routine = started(at: .desk)
    routine.handle(.roomChanged(scene(.musicCorner)), at: at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 1)) == .dropNeedle)
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.musicCorner))
}

@Test func theNeedleDoesNotDropAgainWhenTheSceneIsRebuilt() {
    var routine = started(at: .musicCorner)
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.handle(.sceneStarted(scene(.musicCorner)), at: at(12, 1)) == idling(.musicCorner))
}

@Test func theNeedleDropsAgainAfterPixLeavesAndComesBack() {
    var routine = started(at: .musicCorner)
    routine.handle(.roomChanged(scene(.window)), at: at(12, 1))
    routine.handle(.finished, at: at(12, 1))
    routine.handle(.roomChanged(scene(.musicCorner)), at: at(12, 2))
    #expect(routine.handle(.finished, at: at(12, 2)) == .dropNeedle)
}

@Test func aMomentCanInterruptTheNeedleWhichStaysDown() {
    var routine = started(at: .desk)
    routine.handle(.roomChanged(scene(.musicCorner)), at: at(12, 1))
    routine.handle(.finished, at: at(12, 1))  // arrived: the needle starts dropping
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.musicCorner))
}

// MARK: - The call Spot

@Test func fromTheDeskToACallPixStaysInItsSeatAndPutsTheHeadsetOn() {
    var routine = started(at: .desk)
    #expect(routine.handle(.roomChanged(scene(.call)), at: at(12, 1)) == idling(.call))
    #expect(routine.handle(.roomChanged(scene(.desk)), at: at(12, 2)) == idling(.desk))
}

@Test func aCallStartingDuringAMomentSettlesOnTheCallWhenPixIsDone() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    #expect(routine.handle(.roomChanged(scene(.call)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.call))
}

@Test func fromTheCouchPixWalksToTheCallAndFromTheCallToTheWindow() {
    var routine = started(at: .couch)
    #expect(routine.handle(.roomChanged(scene(.call)), at: at(12, 1)) == .walk(to: .call))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.call))
    #expect(routine.handle(.roomChanged(scene(.window)), at: at(12, 2)) == .walk(to: .window))
}

@Test func onACallASleepyPixDoesNoFidgets() {
    var rolled = started(at: .call, .sleepy, dice: Dice([0]))
    #expect(rolled.handle(.wake, at: at(12, 1)) == nil)
}

// MARK: - The Stroll

@Test func arrivingAtTheWindowPixRestsThenStrollsLeft() {
    var routine = started(at: .window)
    #expect(routine.handle(.finished, at: at(12)) == .stroll(to: .left))
}

@Test func theStrollStandsAtTheLeftEndStretchesAtTheRightAndGoesBackAndForth() {
    var routine = started(at: .window)
    routine.handle(.finished, at: at(12))  // walking left
    #expect(routine.handle(.finished, at: at(12, 1)) == .stopAt(.left, body: nil))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))
    #expect(routine.handle(.finished, at: at(12, 2)) == .stopAt(.right, body: "stretch"))
    #expect(routine.handle(.finished, at: at(12, 2)) == .stroll(to: .left))
}

@Test func aFidgetDueMidWalkWaitsForTheEndOfTheWindowThenAnotherWalk() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))  // the window's first Fidget
    routine.handle(.finished, at: at(12))  // walking left
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == .fidget(.gaze))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))  // it had reached the left end
}

@Test func aFidgetDueWhilePixStopsAtAnEndPlaysAtOnce() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))
    routine.handle(.finished, at: at(12))  // walking left
    routine.handle(.finished, at: at(12, 1))  // stopped at the left end
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.gaze))
}

/// Strolling right, after the first walk left and the stop at the left end. A Fidget is due at 12:01.
func strollingRight(dice: Dice = Dice([])) -> Routine {
    var routine = started(at: .window, dice: dice)
    for _ in 0..<3 { routine.handle(.finished, at: at(12)) }
    return routine
}

@Test func theStrollsWalksAndStopsKeepTheFidgetDeadline() {
    var routine = started(at: .window)
    let due = routine.nextWake
    #expect(due == at(12, 1))
    routine.handle(.finished, at: at(12))  // walking left
    #expect(routine.nextWake == due)
    routine.handle(.finished, at: at(12, 0, 30))  // stopped at the left end
    #expect(routine.nextWake == due)
    routine.handle(.finished, at: at(12, 0, 35))  // walking right
    #expect(routine.nextWake == due)
}

@Test func aNewMoodMidWalkRestartsTheFidgetDeadline() {
    var routine = strollingRight()
    routine.handle(.roomChanged(scene(.window, .cheerful)), at: at(12, 0, 40))
    #expect(routine.nextWake == at(12, 1, 40))
}

@Test func aFidgetHeldMidWalkPlaysInPlaceOfTheStopAtTheEndPixReaches() {
    var routine = strollingRight(dice: Dice([0.5, 0.9]))  // the window's third Fidget
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // never mid-walk
    #expect(routine.nextWake == nil)
    #expect(routine.handle(.finished, at: at(12, 2)) == .fidget(.scratch))  // no stop or stretch at the right end
    #expect(routine.handle(.finished, at: at(12, 2)) == idling(.window))
    #expect(routine.handle(.finished, at: at(12, 2)) == .stroll(to: .left))
}

@Test func afterAMomentMidWalkPixKeepsHeadingForTheSameEnd() {
    var routine = strollingRight()
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))
}

@Test func aNewMoodMidWalkRestsAfreshAndTheWalkCarriesOnToItsStop() {
    var routine = started(at: .window, .focused)  // no Fidget clock while focused
    routine.handle(.finished, at: at(12))  // walking left
    #expect(routine.handle(.roomChanged(scene(.window, .content)), at: at(12, 1)) == idling(.window))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stopAt(.left, body: nil))
}

@Test func aFidgetDueAfterANewMoodMidWalkStillWaitsForTheEnd() {
    var routine = started(at: .window, .focused)  // no Fidget clock while focused
    routine.handle(.finished, at: at(12))  // walking left
    #expect(routine.handle(.roomChanged(scene(.window, .content)), at: at(12, 1)) == idling(.window))
    #expect(routine.strolling)
    #expect(routine.handle(.wake, at: at(12, 2)) == nil)  // still mid-walk
    #expect(routine.handle(.finished, at: at(12, 2)) == .fidget(.wave))
}

@Test func leavingTheWindowMidStrollAndComingBackStartsLeftAgain() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.desk)), at: at(12, 1)) == .walk(to: .desk))
    routine.handle(.finished, at: at(12, 1))
    routine.handle(.roomChanged(scene(.window)), at: at(12, 2))
    #expect(routine.handle(.finished, at: at(12, 2)) == idling(.window))
    #expect(routine.handle(.finished, at: at(12, 2)) == .stroll(to: .left))
}

@Test func whenTheSceneStartsAgainAtTheWindowTheStrollStartsLeftAgain() {
    var routine = strollingRight()
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.handle(.sceneStarted(scene(.window)), at: at(12, 2)) == idling(.window))
    #expect(!routine.strolling)
    #expect(routine.handle(.finished, at: at(12, 2)) == .stroll(to: .left))
}

@Test func switchingBetweenTwoAppsThatKeepPixAtTheWindowLeavesTheWalkAlone() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.window, activity: .other, fps: 10)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == .stopAt(.right, body: "stretch"))
}

@Test func afterAMomentAtAnEndPixHeadsForTheOtherEnd() {
    var routine = strollingRight()
    routine.handle(.finished, at: at(12, 1))  // stopped at the right end
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    routine.handle(.finished, at: at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .left))
}

// MARK: - Fidgets

@Test(arguments: [
    (Spot.desk, Mood.content, [Fidget.sip, .stretch, .lookaround]), (.couch, .content, [.popcorn]),
    (.musicCorner, .content, [.spin]), (.window, .content, [.gaze, .wave, .scratch]),
    (.desk, .sleepy, [.nod]), (.window, .sleepy, [.nod]), (.call, .content, [.nod]),
])
func fidgetsFitWherePixIsAndHowItFeels(spot: Spot, mood: Mood, bodies: [Fidget]) {
    for (i, body) in bodies.enumerated() {
        let count = spot == .desk && mood != .sleepy ? 4 : bodies.count  // the desk's fourth is watering the plant
        var routine = started(at: spot, mood, dice: Dice([0.5, (Double(i) + 0.5) / Double(count)]))
        #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(body))
        #expect(routine.handle(.finished, at: at(12, 1)) == idling(spot, mood))
    }
}

@Test func asleepOnTheCouchPixDoesNoFidgets() {
    var routine = started(at: .couch, .sleepy)
    #expect(routine.handle(.roomChanged(scene(.couch, .sleepy)), at: at(12)) == nil)
    var rolled = started(at: .couch, .sleepy, dice: Dice([0]))
    #expect(rolled.handle(.wake, at: at(12, 1)) == nil)
}

@Test func asleepOnTheCouchNoFidgetIsDue() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    #expect(routine.handle(.sceneStarted(scene(.couch, .sleepy)), at: at(12)) == .idle(.couch, .sleepy))
    #expect(routine.nextWake == nil)
}

@Test func aWakeBeforeTheFidgetDeadlineDoesNothing() {
    var routine = started(at: .desk)
    #expect(routine.handle(.wake, at: at(12, 0, 59)) == nil)
    #expect(routine.nextWake == at(12, 1))
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.lookaround))
}

@Test func aLateWakeStillPlaysTheFidgetAndAStaleOneDoesNothing() {
    var routine = started(at: .desk)
    #expect(routine.handle(.wake, at: at(12, 5)) == .fidget(.lookaround))
    #expect(routine.nextWake == nil)
    #expect(routine.handle(.wake, at: at(12, 6)) == nil)
}

@Test func aFidgetEndingRestartsTheClockFromTheNewIdle() {
    var routine = started(at: .desk)
    routine.handle(.wake, at: at(12, 1))
    #expect(routine.nextWake == nil)  // no Fidget clock while one plays
    #expect(routine.handle(.finished, at: at(12, 1, 10)) == idling(.desk))
    #expect(routine.nextWake == at(12, 2, 10))
}

@Test func aStepOutsideTheStrollClearsTheFidgetDeadline() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 30))
    #expect(routine.nextWake == nil)
    routine.handle(.roomChanged(scene(.window)), at: at(12, 0, 40))
    #expect(routine.nextWake == nil)  // walking to the window
}

@Test func aFidgetThatComesDueWhileBusyIsSkipped() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)
}

// MARK: - Errands

let wateringFromTheDesk = Errand.waterPlant(at: 404, fromRight: true)  // the plant left of the desk is nearest

func wateringThePlant() -> Routine {
    started(at: .desk, dice: Dice([0.5, 0.9]))  // the fourth desk Fidget
}

@Test func wateringThePlantWalksToItUsesItAndWalksBack() {
    var routine = wateringThePlant()
    #expect(routine.handle(.wake, at: at(12, 1)) == .errand(wateringFromTheDesk))
    #expect(routine.handle(.finished, at: at(12, 1)) == .use(wateringFromTheDesk))
    #expect(routine.handle(.finished, at: at(12, 1)) == .walkBack(to: .desk))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.desk))
}

@Test(arguments: [0, 1, 2])
func aMomentThatCutsAnErrandShortIsFollowedByAWalkHomeNotAJump(leg: Int) {
    var routine = wateringThePlant()
    routine.handle(.wake, at: at(12, 1))
    for _ in 0..<leg { routine.handle(.finished, at: at(12, 1)) }  // out, at the plant, or on the way back
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == .walkBack(to: .desk))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.desk))
}

@Test func aMomentDuringTheWalkHomeIsFollowedByAnotherWalkHome() {
    var routine = wateringThePlant()
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    routine.handle(.finished, at: at(12, 1))  // now walking home
    routine.handle(.momentArrived(.reaction(.pet)), at: at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 1)) == .walkBack(to: .desk))
}

@Test func anAppSwitchDuringAnErrandSendsPixStraightToTheNewSpot() {
    var routine = wateringThePlant()
    routine.handle(.wake, at: at(12, 1))
    #expect(routine.handle(.roomChanged(scene(.window)), at: at(12, 1)) == .walk(to: .window))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.window))
}

// MARK: - The lamp

@Test func theLampIsAsTheHourWantsItWhenTheSceneFirstStarts() {
    #expect(started(at: .desk, time: at(21)).lampLit == true)
    #expect(started(at: .desk, time: at(12)).lampLit == false)
}

@Test func at7pmPixWalksToTheLampAndSwitchesItOn() {
    var routine = started(at: .desk, time: at(18, 59))
    #expect(routine.handle(.minutePassed, at: at(19)) == .errand(.switchLamp))
    #expect(routine.handle(.finished, at: at(19)) == .use(.switchLamp))
    #expect(routine.lampLit == false)
    #expect(routine.handle(.finished, at: at(19)) == .walkBack(to: .desk))
    #expect(routine.lampLit == true)
    #expect(routine.handle(.finished, at: at(19)) == idling(.desk))
}

@Test func at6amPixSwitchesTheLampOff() {
    var routine = started(at: .couch, time: at(5, 59))
    #expect(routine.handle(.minutePassed, at: at(6)) == .errand(.switchLamp))
    routine.handle(.finished, at: at(6))
    routine.handle(.finished, at: at(6))
    #expect(routine.lampLit == false)
    #expect(routine.handle(.finished, at: at(6)) == idling(.couch))
}

@Test func afterFlyingEastTheLampFollowsTheNewHour() {
    var routine = started(at: .desk, time: at(12))
    #expect(routine.handle(.minutePassed, at: at(12, 1)) == nil)
    routine.handle(.timeZoneChanged(TimeZone(identifier: "Asia/Singapore")!), at: at(12, 2))  // 20:02 there
    #expect(routine.handle(.minutePassed, at: at(12, 3)) == .errand(.switchLamp))
}

@Test func atTheWindowTheLampWaitsUntilPixIsBackOnTheDeskSide() {
    var routine = started(at: .window, time: at(18, 59))
    #expect(routine.handle(.minutePassed, at: at(19)) == nil)
    routine.handle(.roomChanged(scene(.desk)), at: at(19, 5))
    #expect(routine.handle(.finished, at: at(19, 5)) == .errand(.switchLamp))
}

@Test func whileBusyTheLampWaitsUntilPixIsDone() {
    var routine = started(at: .desk, time: at(18, 59))
    routine.handle(.momentArrived(.reaction(.wave)), at: at(18, 59))
    #expect(routine.handle(.minutePassed, at: at(19)) == nil)
    #expect(routine.handle(.finished, at: at(19)) == .errand(.switchLamp))
}

@Test func theLampKeepsItsStateWhenTheSceneStopsAndStartsAgain() {
    var routine = started(at: .desk, time: at(18, 59))
    routine.handle(.minutePassed, at: at(19))
    for _ in 0..<3 { routine.handle(.finished, at: at(19)) }
    routine.handle(.sceneStopped, at: at(19, 1))
    #expect(routine.handle(.sceneStarted(scene(.desk)), at: at(19, 2)) == idling(.desk))
    #expect(routine.lampLit == true)
}

@Test func aMomentDuringTheLampSwitchLeavesItForTheNextIdle() {
    var routine = started(at: .desk, time: at(18, 59))
    routine.handle(.minutePassed, at: at(19))
    routine.handle(.finished, at: at(19))  // at the lamp, reaching up
    routine.handle(.momentArrived(.reaction(.wave)), at: at(19))
    #expect(routine.lampLit == false)
    #expect(routine.handle(.finished, at: at(19)) == .errand(.switchLamp))
}
