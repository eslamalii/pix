import Foundation
import Testing
import AmbientCore

/// Halloween 2026 (a Saturday) at hh:mm UTC: `at` counts from Monday 2026-10-12.
func halloween(_ h: Int, _ m: Int = 0, _ s: Int = 0) -> Date { at(h, m, s).addingTimeInterval(19 * 86400) }
/// The next Occasion after it, Christmas Eve.
func christmasEve(_ h: Int) -> Date { at(h).addingTimeInterval(73 * 86400) }

private func room(_ spot: Spot, _ mood: Mood = .content, focusing: Bool = false, activity: Activity? = nil) -> Room {
    var room = scene(spot, mood, activity: activity)
    room.focusing = focusing
    return room
}

/// A Routine with the scene started on Halloween at noon at `spot`, and the step it asked for.
private func opened(_ spot: Spot = .desk, _ mood: Mood = .content, focusing: Bool = false, activity: Activity? = nil,
                    dice: Dice = Dice([]), greeting: Bool = false) -> (routine: Routine, first: Routine.Step?) {
    var routine = Routine(timeZone: utc, random: dice.roll)
    if greeting { routine.handle(.momentArrived(.greeting(.halloween)), at: halloween(12)) }
    let first = routine.handle(.sceneStarted(room(spot, mood, focusing: focusing, activity: activity)), at: halloween(12))
    return (routine, first)
}

/// Finishes the Step the Routine is on, as the view would, until it starts `.placeOccasionProp(perch)`.
private func tour(_ routine: inout Routine, upTo perch: Int) {
    for n in 0..<perch {
        routine.handle(.finished, at: halloween(12, 1))  // walk
        routine.handle(.finished, at: halloween(12, 1))  // place n
    }
    routine.handle(.finished, at: halloween(12, 1))
}

@Test func onAnOccasionAfterTheGreetingPixTouredTheFourPerchesThenGoesHome() {
    var (routine, first) = opened(greeting: true)
    #expect(first == .moment(.greeting(.halloween)))
    #expect(routine.props(at: halloween(12)).occasionPropsShown == 0)
    #expect(routine.handle(.finished, at: halloween(12, 0, 5)) == .tourWalk(perch: 0))
    for perch in 0..<4 {
        #expect(routine.handle(.finished, at: halloween(12, 1)) == .placeOccasionProp(perch: perch))
        #expect(routine.props(at: halloween(12, 1)).occasionPropsShown == perch)
        let next = routine.handle(.finished, at: halloween(12, 1))
        #expect(routine.props(at: halloween(12, 1)).occasionPropsShown == perch + 1)
        if perch < 3 { #expect(next == .tourWalk(perch: perch + 1)) } else { #expect(next == .walkBack(to: .desk)) }
    }
    #expect(routine.handle(.finished, at: halloween(12, 2)) == idling(.desk))
}

@Test func withNoGreetingWaitingPixToursAsSoonAsItIsFree() {
    #expect(opened().first == .tourWalk(perch: 0))
}

@Test func onAnOrdinaryDayPixDoesNotTour() {
    var routine = started(at: .desk)
    #expect(routine.props(at: at(12)).occasion == nil)
    #expect(routine.handle(.minutePassed, at: at(12, 1)) == nil)
    #expect(routine.props(at: at(12)).occasionPropsShown == 0)
}

@Test func theOccasionComesFromTheRoutinesOwnCalendar() {
    var routine = Routine(timeZone: TimeZone(identifier: "Pacific/Auckland")!, random: Dice([]).roll)
    // 2026-10-30 12:00 UTC is 01:00 on the 31st in Auckland.
    let time = halloween(12).addingTimeInterval(-86400)
    #expect(routine.handle(.sceneStarted(room(.desk)), at: time) == .tourWalk(perch: 0))
    #expect(routine.props(at: time).occasion == .halloween)
}

@Test func nothingToursDuringAFocusSessionButItStartsTheMomentItEnds() {
    var (routine, first) = opened(.desk, .focused, focusing: true)
    #expect(first == idling(.desk, .focused))
    #expect(routine.handle(.minutePassed, at: halloween(12, 1)) == nil)
    #expect(routine.handle(.roomChanged(room(.desk, .content, focusing: false)), at: halloween(12, 25)) == .tourWalk(perch: 0))
}

@Test func nothingToursDuringAMeeting() {
    var (routine, first) = opened(.call)
    #expect(first == idling(.call))
    #expect(routine.handle(.minutePassed, at: halloween(12, 1)) == nil)
    #expect(routine.handle(.minutePassed, at: halloween(12, 2)) == nil)
}

@Test func aSleepyPixStillTours() {
    #expect(opened(.desk, .sleepy).first == .tourWalk(perch: 0))
}

@Test func aHotMacDoesNotStopTheTourEither() {
    var hot = room(.desk, .grumpy)
    hot.hot = true
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    #expect(routine.handle(.sceneStarted(hot), at: halloween(12)) == .tourWalk(perch: 0))
}

@Test func aMomentMidTourWaitsAndPlaysAfterThe4thPerch() {
    var (routine, _) = opened()
    #expect(routine.handle(.momentArrived(.reaction(.pet)), at: halloween(12, 1)) == nil)
    tour(&routine, upTo: 3)  // now at the 4th place step
    #expect(routine.handle(.finished, at: halloween(12, 2)) == .moment(.reaction(.pet)))
    #expect(routine.handle(.finished, at: halloween(12, 3)) == .walkBack(to: .desk))
}

@Test func anAppSwitchMidTourDoesNotWalkAndPixGoesToTheNewSpotWhenItIsDone() {
    var (routine, _) = opened()
    #expect(routine.handle(.roomChanged(room(.couch)), at: halloween(12, 1)) == nil)
    #expect(routine.lastSpot == .couch)
    tour(&routine, upTo: 3)
    #expect(routine.handle(.finished, at: halloween(12, 2)) == .walkBack(to: .couch))
    #expect(routine.handle(.finished, at: halloween(12, 3)) == idling(.couch))
}

@Test func aNewMoodMidTourChangesNothing() {
    var (routine, _) = opened()
    #expect(routine.handle(.roomChanged(room(.desk, .grumpy)), at: halloween(12, 1)) == nil)
}

@Test func aMugInHandWhenTheTourStartsStaysAtTheDesk() {
    // A refill starts while a Focus session runs; the session ends mid-errand, and the tour starts on its way home.
    var (routine, _) = opened(.desk, .content, focusing: true, dice: Dice([0.5, 0]))
    #expect(routine.handle(.wake, at: halloween(12, 1)) == .errand(.refillMug))
    #expect(routine.props(at: halloween(12, 1)).walkBody == "walkmug")
    routine.handle(.roomChanged(room(.desk, .content, focusing: false)), at: halloween(12, 1, 10))
    #expect(routine.handle(.finished, at: halloween(12, 1, 20)) == .use(.refillMug))
    #expect(routine.handle(.finished, at: halloween(12, 1, 22)) == .walkBack(to: .desk))
    #expect(routine.handle(.finished, at: halloween(12, 1, 40)) == .tourWalk(perch: 0))
    #expect(routine.props(at: halloween(12, 1, 40)).walkBody == "walk")
    #expect(routine.props(at: halloween(12, 1, 40)).mugAway == false)
}

@Test func nothingWakesOrChecksTheClockMidTour() {
    var (routine, _) = opened(dice: Dice([0.5, 0]))
    #expect(routine.nextWake == nil)
    for step in 0..<8 {
        #expect(routine.handle(.wake, at: halloween(13, step)) == nil)
        #expect(routine.handle(.minutePassed, at: halloween(13, step)) == nil)
        routine.handle(.finished, at: halloween(13, step))
    }
}

@Test func theShownPropsCountUpAndAreAllShownAfterTheSceneRestartsMidTour() {
    var (routine, _) = opened()
    tour(&routine, upTo: 1)  // place 1 is playing, place 0 is done
    #expect(routine.props(at: halloween(12, 1)).occasionPropsShown == 1)
    routine.handle(.finished, at: halloween(12, 1))  // on to the walk to Perch 2
    routine.handle(.sceneStopped, at: halloween(12, 2))
    #expect(routine.props(at: halloween(12, 2)).occasionPropsShown == 4)
    #expect(routine.handle(.sceneStarted(room(.desk)), at: halloween(12, 3)) == idling(.desk))  // no second tour
    #expect(routine.props(at: halloween(12, 3)).occasionPropsShown == 4)
    #expect(routine.props(at: halloween(12, 3)).occasion == .halloween)
}

@Test func oncePlacedThereIsNoSecondTourTheSameDayButThereIsOnTheNextOccasion() {
    var (routine, _) = opened()
    tour(&routine, upTo: 3)
    routine.handle(.finished, at: halloween(12, 2))  // place 3
    routine.handle(.finished, at: halloween(12, 3))  // walk home
    #expect(routine.handle(.minutePassed, at: halloween(12, 4)) == nil)
    #expect(routine.handle(.roomChanged(room(.desk, .grumpy)), at: halloween(12, 5)) == .relook(.grumpy, at: .desk))
    #expect(routine.props(at: christmasEve(12)).occasionPropsShown == 0)
    #expect(routine.handle(.minutePassed, at: christmasEve(12)) == .tourWalk(perch: 0))
    #expect(routine.props(at: christmasEve(12)).occasion == .holidays)
}

// MARK: - Crossing midnight mid-tour

private func midnight(_ base: Date, _ seconds: Int) -> Date { base.addingTimeInterval(Double(seconds)) }

@Test func aTourStartedBeforeMidnightOnTheEveKeepsPlacingVisiblyThenTheNextDaysTourStartsFromNothing() {
    let eve = christmasEve(0)
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    let start = midnight(eve, 23 * 3600 + 59 * 60)
    #expect(routine.handle(.sceneStarted(room(.desk)), at: start) == .tourWalk(perch: 0))
    var time = start
    for perch in 0..<4 {
        time += 20  // crosses into the 25th after the first Perch's walk
        #expect(routine.handle(.finished, at: time) == .placeOccasionProp(perch: perch))
        #expect(routine.props(at: time).occasionPropsShown == perch)
        time += 20
        let next = routine.handle(.finished, at: time)
        if perch < 3 {
            #expect(routine.props(at: time).occasionPropsShown == perch + 1)
            #expect(next == .tourWalk(perch: perch + 1))
        } else {
            #expect(next == .tourWalk(perch: 0))  // the 25th is an Occasion too: its own tour, from nothing
            #expect(routine.props(at: time).occasionPropsShown == 0)
        }
    }
    #expect(time >= midnight(eve, 86400))
}

@Test func aTourStartedBeforeMidnightOnHalloweenShowsNothingOnceNovemberBeginsAndDoesNotTourAgain() {
    let day = halloween(0)
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    let start = midnight(day, 23 * 3600 + 59 * 60)
    #expect(routine.handle(.sceneStarted(room(.desk)), at: start) == .tourWalk(perch: 0))
    var time = start
    for perch in 0..<4 {
        time += 20
        #expect(routine.handle(.finished, at: time) == .placeOccasionProp(perch: perch))
        time += 20
        let next = routine.handle(.finished, at: time)
        #expect(routine.props(at: time).occasion == (time < midnight(day, 86400) ? .halloween : nil))
        if time >= midnight(day, 86400) { #expect(routine.props(at: time).occasionPropsShown == 0) }
        #expect(next == (perch < 3 ? .tourWalk(perch: perch + 1) : .walkBack(to: .desk)))
    }
}

// MARK: - The tour comes before the lamp and waits for a meeting to end

@Test func atDuskTheTourComesBeforeTheLampTheGreetingLeftToSwitch() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    routine.handle(.momentArrived(.greeting(.halloween)), at: halloween(18, 59))
    #expect(routine.handle(.sceneStarted(room(.desk)), at: halloween(18, 59)) == .moment(.greeting(.halloween)))
    #expect(routine.handle(.finished, at: halloween(19, 0, 10)) == .tourWalk(perch: 0))  // the lamp is wanted lit now
    for perch in 0..<4 {
        #expect(routine.handle(.finished, at: halloween(19, 1)) == .placeOccasionProp(perch: perch))
        let next = routine.handle(.finished, at: halloween(19, 1))
        #expect(next == (perch < 3 ? .tourWalk(perch: perch + 1) : .errand(.switchLamp)))
    }
}

@Test func aMinuteTickMidTourDoesNotSwitchTheLampWhichFollowsTheTour() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll)
    #expect(routine.handle(.sceneStarted(room(.desk)), at: halloween(18, 59)) == .tourWalk(perch: 0))
    #expect(routine.handle(.minutePassed, at: halloween(19, 0)) == nil)
    for perch in 0..<4 {
        #expect(routine.handle(.finished, at: halloween(19, 1)) == .placeOccasionProp(perch: perch))
        #expect(routine.handle(.minutePassed, at: halloween(19, 1, 30)) == nil)
        let next = routine.handle(.finished, at: halloween(19, 2))
        #expect(next == (perch < 3 ? .tourWalk(perch: perch + 1) : .errand(.switchLamp)))
    }
}

@Test func aFirstSightingInAMeetingDoesNotTourButTheMeetingEndingStartsIt() {
    var (routine, first) = opened(.call)
    #expect(first == idling(.call))
    #expect(routine.handle(.roomChanged(room(.desk)), at: halloween(12, 30)) == .tourWalk(perch: 0))  // the call and the desk are one place: Pix stays put
}

@Test func relaunchingMidTourOpensWithAllFourPropsAndNoSecondTour() {
    var (routine, _) = opened()
    routine.handle(.finished, at: halloween(12, 1))  // placing the first Prop
    routine.handle(.sceneStopped, at: halloween(12, 2))
    var fresh = Routine(timeZone: utc, random: Dice([]).roll, saved: routine.saved)
    let first = fresh.handle(.sceneStarted(room(.desk)), at: halloween(13))
    #expect(first == idling(.desk))
    #expect(fresh.props(at: halloween(13)).occasionPropsShown == Art.perches.count)
    #expect(fresh.handle(.minutePassed, at: halloween(13, 1)) == nil)
}

@Test func aSavedDayThatIsNotTodayToursAgainOnLaunch() {
    var yesterday = Routine(timeZone: utc, random: Dice([]).roll)
    yesterday.handle(.sceneStarted(room(.desk)), at: christmasEve(12))
    #expect(yesterday.saved.occasionPropsPlacedOn != nil)
    var next = Routine(timeZone: utc, random: Dice([]).roll, saved: yesterday.saved)
    let christmas = christmasEve(12).addingTimeInterval(86400)
    let first = next.handle(.sceneStarted(room(.desk)), at: christmas)
    #expect(first == .tourWalk(perch: 0))
    #expect(next.props(at: christmas).occasionPropsShown == 0)
}
