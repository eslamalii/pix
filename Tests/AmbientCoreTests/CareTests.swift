import Foundation
import Testing
import AmbientCore

/// A Garden whose plants have all been thirsty since 03:00.
func thirstyGarden(_ plants: [Plant] = allPlants) -> Garden {
    var garden = Garden()
    garden.adopt(plants, at: at(0), random: { 0 })
    return garden
}

/// A Routine with its scene started at `spot`, at noon, with the Garden as given. The first Fidget falls due at 12:01.
func tending(at spot: Spot, _ mood: Mood = .content, garden: Garden, time: Date = at(12), dice: Dice = Dice([])) -> Routine {
    var routine = Routine(timeZone: utc, random: dice.roll, garden: garden, thirstRandom: { 0 })
    routine.handle(.sceneStarted(scene(spot, mood)), at: time)
    return routine
}

// MARK: - Care at the desk

@Test func pixWatersAThirstyPlantAtItsNextFidgetSlot() {
    var routine = tending(at: .desk, garden: thirstyGarden())
    #expect(routine.handle(.wake, at: at(12, 1)) == .errand(.waterPlant(deskPlant)))
}

/// Plays the Errand Pix was just asked for to its end: out, use, back.
func playErrand(_ routine: inout Routine, at time: Date) {
    routine.handle(.finished, at: time)  // out, at the plant
    routine.handle(.finished, at: time)  // used it
    routine.handle(.finished, at: time)  // back at the Spot
}

@Test func careGoesToTheNearestThirstyPlantFirstOneAtATimeAndThenTheFidgetsReturn() {
    var routine = tending(at: .desk, garden: thirstyGarden())
    #expect(routine.handle(.wake, at: at(12, 1)) == .errand(.waterPlant(deskPlant)))
    playErrand(&routine, at: at(12, 1))
    #expect(routine.props(at: at(12, 1)).thirstyPlants == [otherDeskPlant, windowPlant])
    #expect(routine.handle(.wake, at: routine.nextWake!) == .errand(.waterPlant(otherDeskPlant)))
    playErrand(&routine, at: at(12, 3))
    #expect(routine.props(at: at(12, 3)).thirstyPlants == [windowPlant])  // not on the desk's strip: left for the window
    guard case .fidget? = routine.handle(.wake, at: routine.nextWake!) else { Issue.record("no ordinary Fidget"); return }
}

@Test func aPlantThatIsNotThirstyIsNeverWatered() {
    var routine = tending(at: .desk, garden: Garden())  // adopted at noon: thirsty from 15:00 at the earliest
    for _ in 0..<5 {
        let step = routine.handle(.wake, at: routine.nextWake!)
        if case .errand(.waterPlant)? = step { Issue.record("watered a plant that wasn't thirsty") }
        routine.handle(.finished, at: at(12, 1))
        routine.handle(.finished, at: at(12, 1))
        routine.handle(.finished, at: at(12, 1))
    }
}

@Test func aCutShortWateringLeavesThePlantThirsty() {
    var routine = tending(at: .desk, garden: thirstyGarden([deskPlant]))
    routine.handle(.wake, at: at(12, 1))
    routine.handle(.finished, at: at(12, 1))  // at the plant
    routine.handle(.momentArrived(.reaction(.wave)), at: at(12, 1))  // before using the can
    routine.handle(.finished, at: at(12, 1))  // wave done: walk back
    routine.handle(.finished, at: at(12, 1))  // home
    #expect(routine.props(at: at(12, 1)).thirstyPlants == [deskPlant])
    #expect(routine.handle(.wake, at: routine.nextWake!) == .errand(.waterPlant(deskPlant)))  // tried again
}

@Test(arguments: [Mood.focused, .sleepy])
func pixDoesNotTendThePlantsWhileFocusedOrSleepy(mood: Mood) {
    var routine = tending(at: .desk, mood, garden: thirstyGarden())
    let step = routine.handle(.wake, at: at(12, 1))
    if case .errand(.waterPlant)? = step { Issue.record("watered while \(mood)") }
}

@Test(arguments: [(Spot.call, Routine.Step.fidget(.nod)), (.couch, .fidget(.popcorn))])
func pixDoesNotLeaveTheCallOrTheCouchToTendThePlants(spot: Spot, fidget: Routine.Step) {
    var routine = tending(at: spot, garden: thirstyGarden())
    #expect(routine.handle(.wake, at: at(12, 1)) == fidget)
}

@Test func pixDoesNotLeaveTheMusicCornerToTendThePlants() {
    var routine = tending(at: .musicCorner, garden: thirstyGarden())
    routine.handle(.finished, at: at(12))  // the needle drops on arriving
    #expect(routine.handle(.wake, at: routine.nextWake!) == .fidget(.spin))
}

// MARK: - Only its own strip

@Test func atTheDeskPixIgnoresAThirstyPlantInTheWindow() {
    var routine = tending(at: .desk, garden: thirstyGarden([windowPlant]))
    let step = routine.handle(.wake, at: at(12, 1))
    if case .errand(.waterPlant)? = step { Issue.record("crossed the Room to water") }
}

@Test func atTheWindowPixIgnoresThirstyPlantsOnTheDesk() {
    var routine = tending(at: .window, garden: thirstyGarden([deskPlant, otherDeskPlant]))
    routine.handle(.wake, at: at(12, 1))
    let step = routine.handle(.finished, at: at(12, 1))  // the Stroll's first walk ends
    if case .errand(.waterPlant)? = step { Issue.record("crossed the Room to water") }
}

// MARK: - The window plant

@Test func strollingAtTheWindowPixWatersTheWindowPlantWhereItStops() {
    var routine = tending(at: .window, garden: thirstyGarden([windowPlant]))
    #expect(routine.handle(.wake, at: at(12, 1)) == nil)  // mid-walk to the left end: the Fidget waits
    #expect(routine.handle(.finished, at: at(12, 1)) == .errand(.waterPlant(windowPlant)))
    #expect(routine.handle(.finished, at: at(12, 1)) == .use(.waterPlant(windowPlant)))
    #expect(routine.props(at: at(12, 1)).thirstyPlants == [windowPlant])
    #expect(routine.handle(.finished, at: at(12, 1)) == .stroll(to: .right))  // on from the plant, not back to the middle first
    #expect(routine.props(at: at(12, 1)).thirstyPlants.isEmpty)
}

@Test func leavingForAnotherSpotMidCareLeavesThePlantThirsty() {
    var routine = tending(at: .desk, garden: thirstyGarden([deskPlant]))
    routine.handle(.wake, at: at(12, 1))
    #expect(routine.handle(.roomChanged(scene(.window)), at: at(12, 1)) == .walk(to: .window))
    #expect(routine.props(at: at(12, 1)).thirstyPlants == [deskPlant])
}
