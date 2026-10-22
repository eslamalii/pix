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
    #expect(routine.handle(.roomChanged(scene(.couch)), at: at(12, 1)) == .walk(to: .couch))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.couch))
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
    var routine = started(at: .couch)
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.couch))
}

@Test func aNewerMomentReplacesOneStillPlaying() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))
    #expect(routine.handle(.momentArrived(.reaction(.pet)), at: at(12, 1)) == .moment(.reaction(.pet)))
}

@Test func aMomentDuringAWalkToASpotWaitsForPixToArrive() {
    var routine = started(at: .desk)
    routine.handle(.roomChanged(scene(.couch)), at: at(12, 1))
    #expect(routine.handle(.momentArrived(.reaction(.pet)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == .moment(.reaction(.pet)))
    #expect(routine.handle(.finished, at: at(12, 1)) == idling(.couch))
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

@Test func arrivingAtTheWindowPixStrollsLeftDirectlyWithoutIdling() {
    var fresh = Routine(timeZone: utc)
    #expect(fresh.handle(.sceneStarted(scene(.window)), at: at(12)) == .stroll(to: .left))

    var arriving = started(at: .desk)
    arriving.handle(.roomChanged(scene(.window)), at: at(12, 1))
    #expect(arriving.handle(.finished, at: at(12, 1)) == .stroll(to: .left))
}

@Test func theStrollStopsAtEachEndThenWalksToTheOther() {
    var routine = started(at: .window)  // strolling left
    #expect(routine.handle(.finished, at: at(12, 0, 10)) == .stop(at: .left, body: nil))  // stands
    #expect(routine.nextWake == at(12, 1))  // the Fidget clock alone: the stop is timed by the view
    #expect(routine.handle(.finished, at: at(12, 0, 17)) == .stroll(to: .right))

    #expect(routine.handle(.finished, at: at(12, 0, 30)) == .stop(at: .right, body: "stretch"))
    #expect(routine.handle(.finished, at: at(12, 0, 33)) == .stroll(to: .left))
}

@Test func aWakeBeforeAFidgetIsDueChangesNothingDuringAStop() {
    var routine = started(at: .window)
    routine.handle(.finished, at: at(12, 0, 30))  // stop at the left
    #expect(routine.handle(.wake, at: at(12, 0, 31)) == nil)
    #expect(routine.nextWake == at(12, 1))
}

@Test func aFidgetDueMidWalkWaitsForTheEndOfTheWindowThenReplacesStop() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))  // the window's first Fidget: gaze
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // held mid-walk
    #expect(routine.handle(.finished, at: at(12, 1)) == .fidget(.gaze))  // plays on arrival, in place of the stop
    #expect(routine.handle(.finished, at: at(12, 1, 1)) == .stroll(to: .right))  // heads to other end
}

@Test func aFidgetDueDuringAStopPlaysAtOnceAndPixWalksToTheOtherEnd() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))  // gaze due at 12:01:00
    #expect(routine.handle(.finished, at: at(12, 0, 59) + 0.8) == .stop(at: .left, body: nil))  // 0.2 s before it
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.gaze))
    #expect(routine.handle(.finished, at: at(12, 1, 2)) == .stroll(to: .right))

    var atTheRight = strollingRight(dice: Dice([0.5, 0.9]))  // the window's third Fidget: scratch
    #expect(atTheRight.handle(.finished, at: at(12, 0, 50)) == .stop(at: .right, body: "stretch"))
    #expect(atTheRight.handle(.wake, at: at(12, 1)) == .fidget(.scratch))
    #expect(atTheRight.handle(.finished, at: at(12, 1, 2)) == .stroll(to: .left))
}

/// Strolling right, after the first walk left and the stop at the left end. A Fidget is due at 12:01.
func strollingRight(dice: Dice = Dice([])) -> Routine {
    var routine = started(at: .window, dice: dice)
    routine.handle(.finished, at: at(12))          // left walk finishes -> stop at the left
    routine.handle(.finished, at: at(12, 0, 5))    // stop finishes -> stroll right
    return routine
}

@Test func theStrollsWalksAndStopsKeepTheFidgetDeadline() {
    var routine = started(at: .window)
    let due = at(12, 1)
    #expect(routine.nextWake == due)
    routine.handle(.finished, at: at(12, 0, 30))
    #expect(routine.nextWake == due)  // during the stop
    routine.handle(.finished, at: at(12, 0, 35))
    #expect(routine.nextWake == due)  // and the walk after it
}

@Test func aNewMoodMidWalkRestartsTheFidgetDeadline() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.window, .cheerful)), at: at(12, 0, 40)) == .relook(.cheerful))
    #expect(routine.nextWake == at(12, 1, 40))
}

@Test func aFidgetHeldMidWalkPlaysInPlaceOfTheStopAtTheEndPixReaches() {
    var routine = strollingRight(dice: Dice([0.5, 0.9]))  // the window's third Fidget: scratch
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // never mid-walk
    #expect(routine.handle(.finished, at: at(12, 2)) == .fidget(.scratch))  // no stretch at the right end
    #expect(routine.handle(.finished, at: at(12, 2, 2)) == .stroll(to: .left))
}

@Test func aHeldFidgetPixCannotPlayOnArrivalIsForgottenNotKeptForALaterWalk() {
    var routine = started(at: .window, dice: Dice([0.5, 0, 0]))  // a Fidget is due at 12:01
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // held mid-walk
    routine.handle(.roomChanged(scene(.window, .focused)), at: at(12, 1, 10))  // a Focus session: no Fidgets
    #expect(routine.handle(.finished, at: at(12, 1, 20)) == .stop(at: .left, body: nil, .focused))  // nothing to play
    #expect(routine.handle(.finished, at: at(12, 1, 25)) == .stroll(to: .right, .focused))
    routine.handle(.roomChanged(scene(.window, .content)), at: at(12, 2))  // the next Fidget is due at 12:02:30
    #expect(routine.handle(.finished, at: at(12, 2, 10)) == .stop(at: .right, body: "stretch"))  // not due yet
}

@Test func afterAMomentMidWalkPixKeepsHeadingForTheSameEnd() {
    var routine = strollingRight()
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))
}

@Test func aMomentInterruptsAStopAndPixWalksToTheOtherEnd() {
    var atTheLeft = started(at: .window)
    atTheLeft.handle(.finished, at: at(12, 0, 30))  // stop at the left
    #expect(atTheLeft.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 31)) == .moment(.reaction(.wave)))
    #expect(atTheLeft.handle(.finished, at: at(12, 0, 32)) == .stroll(to: .right))

    var atTheRight = strollingRight()
    atTheRight.handle(.finished, at: at(12, 0, 50))  // stop at the right
    #expect(atTheRight.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 51)) == .moment(.reaction(.wave)))
    #expect(atTheRight.handle(.finished, at: at(12, 0, 52)) == .stroll(to: .left))
}

@Test func aMoodOrHotChangeMidStrollReturnsRelookAndWalkCarriesOn() {
    var routine = started(at: .window, .focused)
    #expect(routine.handle(.roomChanged(scene(.window, .content)), at: at(12, 1)) == .relook(.content))
    // Walk to left end carries on:
    #expect(routine.handle(.finished, at: at(12, 1, 30)) == .stop(at: .left, body: nil))

    // Hot change:
    var hotRoom = scene(.window, .content)
    hotRoom.hot = true
    #expect(routine.handle(.roomChanged(hotRoom), at: at(12, 1, 30)) == .relook(RestLook(spot: .window, mood: .content, hot: true)))
}

@Test func anAgentStartingWorkMidStrollSendsPixWalkingToDesk() {
    var routine = strollingRight()
    var agentRoom = scene(.desk, activity: .coding)
    agentRoom.agentWorking = true
    #expect(routine.handle(.roomChanged(agentRoom), at: at(12, 1)) == .walk(to: .desk))
}

@Test func leavingTheWindowMidStrollAndComingBackStartsLeftAgain() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.desk)), at: at(12, 1)) == .walk(to: .desk))
    routine.handle(.finished, at: at(12, 1))
    routine.handle(.roomChanged(scene(.window)), at: at(12, 2))
    #expect(routine.handle(.finished, at: at(12, 2)) == .stroll(to: .left))
}

@Test func whenTheSceneStartsAgainAtTheWindowTheStrollStartsLeftAgain() {
    var routine = strollingRight()
    routine.handle(.sceneStopped, at: at(12, 1))
    #expect(routine.handle(.sceneStarted(scene(.window)), at: at(12, 2)) == .stroll(to: .left))
}

@Test func switchingBetweenTwoAppsThatKeepPixAtTheWindowLeavesTheWalkAlone() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.window, activity: .other, fps: 10)), at: at(12, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 1)) == .stop(at: .right, body: "stretch"))
}

@Test func restingStepsCarryRestLookMatchingSpotMoodAndHotState() {
    var deskRoutine = Routine(timeZone: utc)
    var deskRoom = scene(.desk, .cheerful)
    deskRoom.hot = true
    let deskStep = deskRoutine.handle(.sceneStarted(deskRoom), at: at(12))
    if case .idle(.desk, let look) = deskStep {
        #expect(look.mood == .cheerful)
        #expect(look.particles == ["steam"])
        #expect(look.faceGlows == true)
        #expect(look.body == "type")
    } else {
        Issue.record("Expected idle with RestLook, got \(String(describing: deskStep))")
    }

    var windowRoutine = Routine(timeZone: utc)
    var windowRoom = scene(.window, .sleepy)
    windowRoom.hot = true
    let strollStep = windowRoutine.handle(.sceneStarted(windowRoom), at: at(12))
    if case .stroll(.left, let look) = strollStep {
        #expect(look.mood == .sleepy)
        #expect(look.particles == ["zzz", "steam"])
        #expect(look.faceGlows == false)
        #expect(look.body == nil)
    } else {
        Issue.record("Expected stroll with RestLook, got \(String(describing: strollStep))")
    }
}

// MARK: - Fidgets

@Test(arguments: [
    (Spot.couch, Mood.content, [Fidget.popcorn]),
    (.musicCorner, .content, [.spin]), (.window, .content, [.gaze, .wave, .scratch]),
    (.desk, .sleepy, [.nod]), (.window, .sleepy, [.nod]), (.call, .content, [.nod]),
])
func fidgetsFitWherePixIsAndHowItFeels(spot: Spot, mood: Mood, bodies: [Fidget]) {
    for (i, body) in bodies.enumerated() {
        let count = bodies.count
        var routine = started(at: spot, mood, dice: Dice([0.5, (Double(i) + 0.5) / Double(count)]))
        if spot == .window {
            #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // held mid-walk
            #expect(routine.handle(.finished, at: at(12, 1)) == .fidget(body))  // held mid-walk, plays on arrival
            #expect(routine.handle(.finished, at: at(12, 1, 1)) == .stroll(to: .right, mood))
        } else {
            #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(body))
            #expect(routine.handle(.finished, at: at(12, 1)) == idling(spot, mood))
        }
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
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.stretch))
}

@Test func aLateWakeStillPlaysTheFidgetAndAStaleOneDoesNothing() {
    var routine = started(at: .desk)
    #expect(routine.handle(.wake, at: at(12, 5)) == .fidget(.stretch))
    #expect(routine.nextWake == nil)
    #expect(routine.handle(.wake, at: at(12, 6)) == nil)
}

@Test(arguments: [0.5, 0.9])
func pixNeverRepeatsAFidgetBackToBack(roll: Double) {
    var routine = started(at: .desk, dice: Dice([0.5, roll, 0.5, roll]))  // the same roll twice
    let first = routine.handle(.wake, at: at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 1, 10)) == idling(.desk))
    let second = routine.handle(.wake, at: at(12, 2, 10))
    #expect(first != nil && second != nil && first != second)
}

// MARK: - The mug

/// Waits for the Fidget to fall due, takes the step Pix asks for, and plays it (and anything that follows) to its end.
func nextDeskStep(_ routine: inout Routine) -> Routine.Step? {
    let step = routine.handle(.wake, at: routine.nextWake!)
    var time = routine.nextWake ?? at(12, 59)
    for _ in 0..<5 {
        time += 1
        if routine.handle(.finished, at: time) == idling(.desk) { break }
    }
    return step
}

@Test func pixStartsWithAnEmptyMugSoItsFirstDeskFidgetIsTheRefill() {
    var routine = started(at: .desk, dice: Dice([0.5, 0]))
    #expect(routine.handle(.wake, at: at(12, 1)) == .errand(.refillMug))
    #expect(routine.handle(.finished, at: at(12, 1, 20)) == .use(.refillMug))
    #expect(routine.handle(.finished, at: at(12, 1, 22)) == .walkBack(to: .desk))
    #expect(routine.handle(.finished, at: at(12, 1, 40)) == idling(.desk))
}

@Test func aRefillCutShortByAMomentLeavesTheMugEmptyAndIsTriedAgain() {
    var routine = started(at: .desk, dice: Dice([0.5, 0, 0.5, 0]))
    #expect(routine.handle(.wake, at: at(12, 1)) == .errand(.refillMug))
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1, 5)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1, 8)) == .walkBack(to: .desk))  // back to the desk, mug still empty
    #expect(routine.handle(.finished, at: at(12, 1, 15)) == idling(.desk))
    #expect(routine.props(at: at(12, 2)).mugSteams == false)
    #expect(routine.handle(.wake, at: routine.nextWake!) == .errand(.refillMug))
}

@Test(arguments: [(16, 59, true), (17, 0, false), (23, 0, false), (5, 59, false), (6, 0, true)])
func aPouredMugSteamsOnlyInCoffeeHoursThenGoesCold(hour: Int, minute: Int, steams: Bool) {
    var routine = started(at: .desk, time: at(12), dice: Dice([0.5, 0]))
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.finished, at: at(12, 1, 20))
    routine.handle(.finished, at: at(12, 1, 22))  // poured: the mug is full
    #expect(routine.props(at: at(hour, minute)).mugSteams == steams)
}

@Test func pixCarriesTheMugFromSettingOffUntilItIsIdleAtTheDeskAgain() {
    var routine = started(at: .desk, dice: Dice([0.5, 0]))
    #expect(routine.props(at: at(12)).mugAway == false)
    routine.handle(.wake, at: at(12, 1))
    #expect(routine.props(at: at(12)).mugAway)  // setting off with it
    routine.handle(.finished, at: at(12, 1, 20))
    #expect(routine.props(at: at(12)).mugAway)  // pouring into it
    routine.handle(.finished, at: at(12, 1, 22))
    #expect(routine.props(at: at(12)).mugAway)  // walking back with it
    routine.handle(.finished, at: at(12, 1, 40))
    #expect(routine.props(at: at(12)).mugAway == false)  // set down at the desk
}

@Test func pixWalksWithTheMugInHandOnlyWhileItCarriesIt() {
    var routine = started(at: .desk, dice: Dice([0.5, 0]))
    #expect(routine.props(at: at(12)).walkBody == "walk")
    routine.handle(.wake, at: at(12, 1))
    #expect(routine.props(at: at(12)).walkBody == "walkmug")
    routine.handle(.finished, at: at(12, 1, 20))
    routine.handle(.finished, at: at(12, 1, 22))
    routine.handle(.finished, at: at(12, 1, 40))
    #expect(routine.props(at: at(12)).walkBody == "walk")
}

@Test func aMomentMidErrandDoesNotPutTheMugDownButLeavingForAnotherSpotDoes() {
    var routine = started(at: .desk, dice: Dice([0.5, 0, 0.5, 0]))
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1, 5))
    #expect(routine.props(at: at(12)).mugAway)
    #expect(routine.handle(.finished, at: at(12, 1, 8)) == .walkBack(to: .desk))
    #expect(routine.props(at: at(12)).mugAway)
    routine.handle(.roomChanged(scene(.couch)), at: at(12, 1, 9))  // an app switch: Pix leaves for the couch
    #expect(routine.props(at: at(12)).mugAway == false)
}

@Test func theMugSteamsOnlyOncePixHasPoured() {
    var routine = started(at: .desk, dice: Dice([0.5, 0]))
    #expect(routine.props(at: at(12, 2)).mugSteams == false)
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.finished, at: at(12, 1, 20))
    #expect(routine.props(at: at(12, 2)).mugSteams == false)  // at the cabinet, not yet poured
    routine.handle(.finished, at: at(12, 1, 22))
    #expect(routine.props(at: at(12, 2)).mugSteams)
}

// Coffee hours: 06:00 to 17:00, so the first desk Fidget (roll 0) is the refill inside them and stretching outside.
@Test(arguments: [(5, 59, 0, false), (6, 0, 0, true), (16, 59, 0, true), (17, 0, 0, false), (23, 0, 0, false)])
func pixDrinksCoffeeOnlyFromSixToFiveInTheEvening(hour: Int, minute: Int, second: Int, coffee: Bool) {
    let wake = at(hour, minute, second)
    var routine = started(at: .desk, time: wake - 60, dice: Dice([0.5, 0]))
    #expect(routine.handle(.wake, at: wake) == (coffee ? .errand(.refillMug) : .fidget(.stretch)))
}

@Test func coffeeHoursFollowTheNewTimeZone() {
    var routine = started(at: .desk, time: at(9, 58, 30), dice: Dice([0.5, 0]))  // 09:58 in UTC: coffee hours
    routine.handle(.timeZoneChanged(TimeZone(secondsFromGMT: 8 * 3600)!), at: at(9, 58, 31))  // 17:58 there
    #expect(routine.handle(.wake, at: at(9, 59, 30)) == .fidget(.stretch))
}

@Test func afterARefillPixSipsThreeTimesBeforeTheNextRefill() {
    var routine = started(at: .desk, dice: Dice(Array(repeating: [0.5, 0.0], count: 9).flatMap { $0 }))
    var seen: [Routine.Step?] = []
    for _ in 0..<8 { seen.append(nextDeskStep(&routine)) }
    #expect(seen == [.errand(.refillMug), .fidget(.sip), .fidget(.stretch), .fidget(.sip), .fidget(.stretch),
                     .fidget(.sip), .errand(.refillMug), .fidget(.sip)])  // the empty mug is refilled at once, then sipped
}

@Test func aSpotWithOneFidgetPlaysItEveryTime() {
    var routine = started(at: .couch, dice: Dice([0.5, 0, 0.5, 0]))
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.popcorn))
    routine.handle(.finished, at: at(12, 1, 10))
    #expect(routine.handle(.wake, at: at(12, 2, 10)) == .fidget(.popcorn))
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

let wateringFromTheDesk = Errand.waterPlant(deskPlant, fromRight: true)  // the plant left of the desk is nearest

func wateringThePlant() -> Routine {
    tending(at: .desk, garden: thirstyGarden())  // the first Fidget slot, at 12:01, goes to Care
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
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .left))
}

// MARK: - The lamp

@Test func theLampIsAsTheHourWantsItWhenTheSceneFirstStarts() {
    #expect(started(at: .desk, time: at(21)).props(at: at(21)).lampLit == true)
    #expect(started(at: .desk, time: at(12)).props(at: at(12)).lampLit == false)
}

@Test func at7pmPixWalksToTheLampAndSwitchesItOn() {
    var routine = started(at: .desk, time: at(18, 59))
    #expect(routine.handle(.minutePassed, at: at(19)) == .errand(.switchLamp))
    #expect(routine.handle(.finished, at: at(19)) == .use(.switchLamp))
    #expect(routine.props(at: at(12)).lampLit == false)
    #expect(routine.handle(.finished, at: at(19)) == .walkBack(to: .desk))
    #expect(routine.props(at: at(12)).lampLit == true)
    #expect(routine.handle(.finished, at: at(19)) == idling(.desk))
}

@Test func at6amPixSwitchesTheLampOff() {
    var routine = started(at: .couch, time: at(5, 59))
    #expect(routine.handle(.minutePassed, at: at(6)) == .errand(.switchLamp))
    routine.handle(.finished, at: at(6))
    routine.handle(.finished, at: at(6))
    #expect(routine.props(at: at(12)).lampLit == false)
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
    #expect(routine.props(at: at(12)).lampLit == true)
}

@Test func aMomentDuringTheLampSwitchLeavesItForTheNextIdle() {
    var routine = started(at: .desk, time: at(18, 59))
    routine.handle(.minutePassed, at: at(19))
    routine.handle(.finished, at: at(19))  // at the lamp, reaching up
    routine.handle(.momentArrived(.reaction(.wave)), at: at(19))
    #expect(routine.props(at: at(12)).lampLit == false)
    #expect(routine.handle(.finished, at: at(19)) == .errand(.switchLamp))
}

@Test func anAgentStartingAndStoppingAtTheDeskRefreshesTheLookWithoutMovingItsFidget() {
    var routine = started(at: .desk)
    let due = routine.nextWake
    var room = scene(.desk)
    room.agentWorking = true
    let working = RestLook(spot: .desk, mood: room.mood, agentWorking: true)
    #expect(routine.handle(.roomChanged(room), at: at(12, 0, 10)) == .idle(.desk, working))
    #expect(routine.nextWake == due)
    room.agentWorking = false
    #expect(routine.handle(.roomChanged(room), at: at(12, 0, 20)) == .idle(.desk, room.mood))
    #expect(routine.nextWake == due)
}

@Test func anAgentChangeDuringAMomentWaitsForItsCompletionThenUsesTheFreshLook() {
    var routine = started(at: .desk)
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 5))
    var room = scene(.desk)
    room.agentWorking = true
    #expect(routine.handle(.roomChanged(room), at: at(12, 0, 10)) == nil)
    #expect(routine.handle(.finished, at: at(12, 0, 15)) == .idle(.desk, RestLook(spot: .desk, mood: room.mood, agentWorking: true)))
}

@Test func anAgentChangeDuringAWalkWaitsForArrival() {
    var routine = started(at: .window)
    var room = scene(.desk)
    #expect(routine.handle(.roomChanged(room), at: at(12)) == .walk(to: .desk))
    room.agentWorking = true
    #expect(routine.handle(.roomChanged(room), at: at(12, 0, 1)) == nil)
    #expect(routine.handle(.finished, at: at(12, 0, 5)) == .idle(.desk, RestLook(spot: .desk, mood: room.mood, agentWorking: true)))
}
