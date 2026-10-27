import Foundation
import Testing
import AmbientCore

let tenMinutes = 600.0, anHour = 3600.0

/// (hour, minute, how long away in seconds, what Pix was found doing)
let pastimeCases: [(Int, Int, Double, Pastime)] = [
    (22, 59, tenMinutes, .gaze), (23, 0, tenMinutes, .doze),  // night begins at 23:00
    (4, 59, tenMinutes, .doze), (5, 0, tenMinutes, .gaze),    // and ends at 05:00
    (5, 59, tenMinutes, .gaze), (6, 0, tenMinutes, .coffee),  // the morning begins at 06:00
    (9, 59, tenMinutes, .coffee), (10, 0, tenMinutes, .gaze), // and ends at 10:00
    (8, 0, 60 * anHour, .coffee),                             // up for the morning's coffee, however long it was away
    (3, 0, 60 * anHour, .doze),                               // back in the night
    (14, 0, 2 * anHour - 1, .gaze), (14, 0, 2 * anHour, .doze),  // a long absence dozes
    (14, 0, 0, .gaze),                                        // a relaunch with no time away
]

@Test(arguments: pastimeCases)
func pixIsFoundDoingWhatTheTimeOfDayAndTheAbsenceSuggest(hour: Int, minute: Int, away: Double, found: Pastime) {
    #expect(Pastime.found(awayFor: away, at: at(hour, minute), calendar: enUS) == found)
}

// MARK: - Found in the Routine

/// A Routine whose Greeting, after the Pastime, arrives before the scene does, and then the scene starts at `spot`.
func returning(to spot: Spot, after pastime: Pastime, greeting: Greeting = .hello, time: Date = at(12)) -> (routine: Routine, first: Routine.Step?) {
    var routine = Routine(timeZone: utc, random: Dice([]).roll, garden: Garden(), thirstRandom: { 0 })
    routine.handle(.momentArrived(.greeting(greeting, after: pastime)), at: time)
    let first = routine.handle(.sceneStarted(scene(spot)), at: time)
    return (routine, first)
}

@Test func pixDozesThenGreetsYouAndStaysWhenTheCouchIsWhereItBelongs() {
    var (routine, first) = returning(to: .couch, after: .doze, greeting: .sleepy)
    #expect(first == .pastime(.doze))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.sleepy, after: .doze)))
    #expect(routine.handle(.finished, at: at(12)) == idling(.couch))
}

@Test(arguments: [Pastime.doze, .gaze])
func afterTheGreetingPixWalksToItsSpotWhenThatIsElsewhere(pastime: Pastime) {
    var (routine, first) = returning(to: .desk, after: pastime)
    #expect(first == .pastime(pastime))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.hello, after: pastime)))
    #expect(routine.handle(.finished, at: at(12)) == .walk(to: .desk))  // the walk between Spots, scrolling the Room if need be
    #expect(routine.handle(.finished, at: at(12)) == idling(.desk))
    #expect(routine.nextWake != nil)  // the Fidgets carry on from here
}

@Test func gazingOutOfTheWindowIsFollowedByTheStrollWhenTheWindowIsWhereItBelongs() {
    var (routine, first) = returning(to: .window, after: .gaze)
    #expect(first == .pastime(.gaze))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.hello, after: .gaze)))
    #expect(routine.handle(.finished, at: at(12)) == .stroll(to: .left))
}

@Test(arguments: [Pastime.doze, .coffee])
func fromAnotherStripPixWalksToTheWindowBeforeItStrolls(pastime: Pastime) {
    var (routine, _) = returning(to: .window, after: pastime, time: at(8))
    #expect(routine.handle(.finished, at: at(8)) == .moment(.greeting(.hello, after: pastime)))  // the Pastime is over
    #expect(routine.handle(.finished, at: at(8)) == .walk(to: .window))  // the Greeting is over: scroll to the window strip
    #expect(routine.handle(.finished, at: at(8)) == .stroll(to: .left))  // arrived: the Stroll starts at the left
}

@Test func theCoffeePastimeFillsTheMugAndPixCarriesItToTheDesk() {
    let morning = at(8)
    var (routine, first) = returning(to: .desk, after: .coffee, time: morning)
    #expect(first == .pastime(.coffee))
    #expect(routine.props(at: morning).mugAway)  // the mug is in hand at the machine
    #expect(routine.handle(.finished, at: morning) == .moment(.greeting(.hello, after: .coffee)))
    #expect(routine.handle(.finished, at: morning) == .walkBack(to: .desk))
    #expect(routine.props(at: morning).walkBody == "walkmug")
    #expect(routine.handle(.finished, at: morning) == idling(.desk))
    #expect(routine.props(at: morning).mugAway == false)
    #expect(routine.props(at: morning).mugSteams)  // a full mug, set down on the desk
}

@Test func awayFromTheDeskTheCoffeeMugIsSetDownFilledNotCarried() {
    let morning = at(8)
    var (routine, _) = returning(to: .window, after: .coffee, time: morning)
    routine.handle(.finished, at: morning)
    #expect(routine.props(at: morning).mugAway == false)
    #expect(routine.props(at: morning).mugSteams == false)  // left on the desk, with nobody beside it
    #expect(routine.handle(.finished, at: morning) == .walk(to: .window))
    routine.handle(.finished, at: morning)  // the Stroll starts
    #expect(routine.handle(.roomChanged(scene(.desk)), at: morning) == .walk(to: .desk))
    routine.handle(.finished, at: morning)
    #expect(routine.props(at: morning).mugSteams)  // back at the desk, the mug is full
}

@Test func theCoffeePastimeLeadsToTheCouchAsAWalkBetweenSpotsWithoutTheMug() {
    var (routine, _) = returning(to: .couch, after: .coffee, time: at(8))
    routine.handle(.finished, at: at(8))  // the Pastime
    #expect(routine.handle(.finished, at: at(8)) == .walk(to: .couch))  // the Greeting is over
    #expect(routine.props(at: at(8)).mugAway == false)
}

@Test func aPastimeIsOnlyFoundWhenTheSceneIsJustStarting() {
    var routine = started(at: .desk)  // the scene is already running and settled
    #expect(routine.handle(.momentArrived(.greeting(.hello, after: .doze)), at: at(12, 1)) == .moment(.greeting(.hello, after: .doze)))
}

@Test func aMomentThatArrivesDuringThePastimeWaitsForTheGreetingAndPlaysAfterIt() {
    var (routine, first) = returning(to: .couch, after: .doze, greeting: .sleepy)
    #expect(first == .pastime(.doze))
    #expect(routine.handle(.momentArrived(.newHat), at: at(12)) == nil)  // the Pastime isn't cut short
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.sleepy, after: .doze)))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.newHat))
    #expect(routine.handle(.finished, at: at(12)) == idling(.couch))
}

@Test func aGreetingAfterAPastimeIsNotReplacedByAMomentThatArrivesBeforeTheScene() {
    var routine = Routine(timeZone: utc, random: Dice([]).roll, garden: Garden(), thirstRandom: { 0 })
    routine.handle(.momentArrived(.greeting(.sleepy, after: .doze)), at: at(12))
    routine.handle(.momentArrived(.agentAsks), at: at(12))  // say, an Agent's hook launched Pix
    #expect(routine.handle(.sceneStarted(scene(.couch)), at: at(12)) == .pastime(.doze))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.sleepy, after: .doze)))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.agentAsks))
    #expect(routine.handle(.finished, at: at(12)) == idling(.couch))
}

@Test func ofTheMomentsThatArriveDuringThePastimeOnlyTheLatestFollowsTheGreeting() {
    var (routine, _) = returning(to: .couch, after: .doze, greeting: .sleepy)
    routine.handle(.momentArrived(.newHat), at: at(12))
    routine.handle(.momentArrived(.agentDone), at: at(12))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.greeting(.sleepy, after: .doze)))
    #expect(routine.handle(.finished, at: at(12)) == .moment(.agentDone))
    #expect(routine.handle(.finished, at: at(12)) == idling(.couch))
}

@Test func aCoffeePastimeThatAMomentArrivesDuringStillFillsTheMug() {
    var (routine, _) = returning(to: .desk, after: .coffee, time: at(8))
    routine.handle(.momentArrived(.newHat), at: at(8))
    routine.handle(.finished, at: at(8))  // the Pastime
    routine.handle(.finished, at: at(8))  // the Greeting
    routine.handle(.finished, at: at(8))  // NEW HAT
    #expect(routine.handle(.finished, at: at(8)) == idling(.desk))  // carried back and set down
    #expect(routine.props(at: at(8)).mugSteams)
}
