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

@Test func theStrollStopsAtEachEndTurnLookAroundStandOrStretchThenWalksBack() {
    var routine = started(at: .window)  // strolling left
    // Reaching the left end:
    #expect(routine.handle(.finished, at: at(12, 0, 10)) == .turn(to: .right))
    #expect(routine.nextWake == at(12, 0, 10) + 0.5)  // 0.5s wait
    #expect(routine.handle(.wake, at: at(12, 0, 10) + 0.5) == .lookAround())
    #expect(routine.handle(.finished, at: at(12, 0, 12)) == .stand())
    #expect(routine.nextWake == at(12, 0, 12) + 2.5)  // 2.5s wait
    #expect(routine.handle(.wake, at: at(12, 0, 12) + 2.5) == .stroll(to: .right))

    // Reaching the right end:
    #expect(routine.handle(.finished, at: at(12, 0, 30)) == .turn(to: .left))
    #expect(routine.nextWake == at(12, 0, 30) + 0.5)  // 0.5s wait
    #expect(routine.handle(.wake, at: at(12, 0, 30) + 0.5) == .lookAround())
    #expect(routine.handle(.finished, at: at(12, 0, 32)) == .stretch())
    #expect(routine.handle(.finished, at: at(12, 0, 33)) == .stroll(to: .left))
}

@Test func anEarlyOrStaleWakeDuringTurnOrStandDoesNothing() {
    var routine = started(at: .window)
    routine.handle(.finished, at: at(12, 0, 30))  // turn(to: .right), deadline at(12, 0, 30) + 0.5
    #expect(routine.handle(.wake, at: at(12, 0, 30) + 0.2) == nil)
    #expect(routine.nextWake == at(12, 0, 30) + 0.5)
}

@Test func aFidgetDueMidWalkWaitsForTheEndOfTheWindowThenReplacesStop() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))  // the window's first Fidget: gaze
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // held mid-walk
    #expect(routine.handle(.finished, at: at(12, 1)) == .turn(to: .right))  // turn wait
    #expect(routine.handle(.wake, at: at(12, 1) + 0.5) == .fidget(.gaze))   // held fidget plays in place of stop
    #expect(routine.handle(.finished, at: at(12, 1, 1)) == .stroll(to: .right))  // heads to other end
}

@Test func aFidgetDueDuringTurnWaitIsHeldAndPlaysAfterTurn() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))  // gaze due at 12:01:00
    // Walk left ends at 12:00:59.8, so turn wait is until 12:01:00.3:
    let walkEnd = at(12, 0, 59) + 0.8
    #expect(routine.handle(.finished, at: walkEnd) == .turn(to: .right))
    // Fidget falls due at 12:01:00 during the turn wait:
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // held!
    // Turn wait ends at 12:01:00.3:
    #expect(routine.handle(.wake, at: walkEnd + 0.5) == .fidget(.gaze))  // plays in place of stop!
    #expect(routine.handle(.finished, at: at(12, 1, 2)) == .stroll(to: .right))  // heads to other end
}

@Test func aFidgetDueWhileLookingAroundOrStandingPlaysAtOnce() {
    var routine = started(at: .window, dice: Dice([0.5, 0]))
    routine.handle(.finished, at: at(12, 0, 30))  // turn
    routine.handle(.wake, at: at(12, 0, 30) + 0.5)  // lookAround
    // Fidget due during lookAround:
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.gaze))
    #expect(routine.handle(.finished, at: at(12, 1, 2)) == .stroll(to: .right))

    // Now check during stand:
    var routine2 = started(at: .window, dice: Dice([0.5, 0]))
    routine2.handle(.finished, at: at(12, 0, 30))  // turn
    routine2.handle(.wake, at: at(12, 0, 30) + 0.5)  // lookAround
    routine2.handle(.finished, at: at(12, 0, 32))  // stand
    #expect(routine2.handle(.wake, at: at(12, 1)) == .fidget(.gaze))
    #expect(routine2.handle(.finished, at: at(12, 1, 2)) == .stroll(to: .right))
}

/// Strolling right, after the first walk left and the stop at the left end. A Fidget is due at 12:01.
func strollingRight(dice: Dice = Dice([])) -> Routine {
    var routine = started(at: .window, dice: dice)
    routine.handle(.finished, at: at(12))          // left walk finishes -> turn
    routine.handle(.wake, at: at(12, 0, 1))        // turn finishes -> lookAround
    routine.handle(.finished, at: at(12, 0, 2))    // lookAround finishes -> stand
    routine.handle(.wake, at: at(12, 0, 5))        // stand finishes -> stroll right
    return routine
}

@Test func theStrollsWalksAndStopsKeepTheFidgetDeadline() {
    var routine = started(at: .window)
    let due = routine.nextWake
    #expect(due == at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 0, 30)) == .turn(to: .right))
    // nextWake is min(turnWaitDeadline, fidgetDue) = at(12, 0, 30.5)
    #expect(routine.nextWake == at(12, 0, 30) + 0.5)
    #expect(routine.handle(.wake, at: at(12, 0, 30) + 0.5) == .lookAround())
    // during lookAround, nextWake is fidgetDue
    #expect(routine.nextWake == due)
    #expect(routine.handle(.finished, at: at(12, 0, 32)) == .stand())
    #expect(routine.nextWake == at(12, 0, 32) + 2.5)
    #expect(routine.handle(.wake, at: at(12, 0, 32) + 2.5) == .stroll(to: .right))
    #expect(routine.nextWake == due)
}

@Test func aNewMoodMidWalkRestartsTheFidgetDeadline() {
    var routine = strollingRight()
    #expect(routine.handle(.roomChanged(scene(.window, .cheerful)), at: at(12, 0, 40)) == .relook(.cheerful))
    #expect(routine.nextWake == at(12, 1, 40))
}

@Test func aFidgetHeldMidWalkPlaysInPlaceOfTheStopAtTheEndPixReaches() {
    var routine = strollingRight(dice: Dice([0.5, 0.9]))  // the window's third Fidget: scratch
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // never mid-walk
    #expect(routine.handle(.finished, at: at(12, 2)) == .turn(to: .left))  // walk right ends -> turn to left
    #expect(routine.handle(.wake, at: at(12, 2) + 0.5) == .fidget(.scratch))  // no lookaround or stretch at right end
    #expect(routine.handle(.finished, at: at(12, 2, 2)) == .stroll(to: .left))
}

@Test func afterAMomentMidWalkPixKeepsHeadingForTheSameEnd() {
    var routine = strollingRight()
    #expect(routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1)) == .moment(.reaction(.wave)))
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))
}

@Test func aMomentInterruptsTurnLookAroundOrStandAndStrollResumesAfterIt() {
    // Interrupting turn:
    var r1 = started(at: .window)
    r1.handle(.finished, at: at(12, 0, 30))  // in turn(to: .right)
    #expect(r1.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 30)) == .moment(.reaction(.wave)))
    #expect(r1.handle(.finished, at: at(12, 0, 31)) == .stroll(to: .right))

    // Interrupting lookAround:
    var r2 = started(at: .window)
    r2.handle(.finished, at: at(12, 0, 30))
    r2.handle(.wake, at: at(12, 0, 30) + 0.5)  // in lookAround
    #expect(r2.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 31)) == .moment(.reaction(.wave)))
    #expect(r2.handle(.finished, at: at(12, 0, 32)) == .stroll(to: .right))

    // Interrupting stand:
    var r3 = started(at: .window)
    r3.handle(.finished, at: at(12, 0, 30))
    r3.handle(.wake, at: at(12, 0, 30) + 0.5)
    r3.handle(.finished, at: at(12, 0, 32))  // in stand
    #expect(r3.handle(.momentArrived(.reaction(.wave)), at: at(12, 0, 33)) == .moment(.reaction(.wave)))
    #expect(r3.handle(.finished, at: at(12, 0, 34)) == .stroll(to: .right))
}

@Test func aMoodOrHotChangeMidStrollReturnsRelookAndWalkCarriesOn() {
    var routine = started(at: .window, .focused)
    #expect(routine.handle(.roomChanged(scene(.window, .content)), at: at(12, 1)) == .relook(.content))
    // Walk to left end carries on:
    #expect(routine.handle(.finished, at: at(12, 1, 30)) == .turn(to: .right))

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
    #expect(routine.handle(.finished, at: at(12, 1)) == .turn(to: .left))
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
            #expect(routine.handle(.finished, at: at(12, 1)) == .turn(to: .right, mood))
            #expect(routine.handle(.wake, at: at(12, 1) + 0.5) == .fidget(body))
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
    #expect(routine.handle(.wake, at: at(12, 1)) == .fidget(.lookaround))
}

@Test func aLateWakeStillPlaysTheFidgetAndAStaleOneDoesNothing() {
    var routine = started(at: .desk)
    #expect(routine.handle(.wake, at: at(12, 5)) == .fidget(.lookaround))
    #expect(routine.nextWake == nil)
    #expect(routine.handle(.wake, at: at(12, 6)) == nil)
}

@Test(arguments: [0.3, 0.6])
func pixNeverRepeatsAFidgetBackToBack(roll: Double) {
    var routine = started(at: .desk, dice: Dice([0.5, roll, 0.5, roll]))  // the same roll twice
    let first = routine.handle(.wake, at: at(12, 1))
    #expect(routine.handle(.finished, at: at(12, 1, 10)) == idling(.desk))
    let second = routine.handle(.wake, at: at(12, 2, 10))
    #expect(first != nil && second != nil && first != second)
}

@Test func wateringThePlantIsAFidgetSoItDoesNotRepeatEither() {
    var routine = started(at: .desk, dice: Dice([0.5, 0.99, 0.5, 0.99]))  // the desk's last choice: water
    guard case .errand(.waterPlant)? = routine.handle(.wake, at: at(12, 1)) else { Issue.record("no water errand"); return }
    routine.handle(.finished, at: at(12, 1, 5))  // use
    routine.handle(.finished, at: at(12, 1, 10))  // walk back
    #expect(routine.handle(.finished, at: at(12, 1, 15)) == idling(.desk))
    guard case .fidget? = routine.handle(.wake, at: at(12, 2, 15)) else { Issue.record("repeated the water errand"); return }
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
    #expect(routine.mugFull == false)
    #expect(routine.handle(.wake, at: routine.nextWake!) == .errand(.refillMug))
}

@Test func theMugIsFullOnlyOncePixHasPoured() {
    var routine = started(at: .desk, dice: Dice([0.5, 0]))
    #expect(routine.mugFull == false)
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.finished, at: at(12, 1, 20))
    #expect(routine.mugFull == false)  // at the cabinet, not yet poured
    routine.handle(.finished, at: at(12, 1, 22))
    #expect(routine.mugFull)
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
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .left))
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
