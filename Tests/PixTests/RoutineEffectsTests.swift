import Foundation
import Testing
import AmbientCore
@testable import Pix

@MainActor
private final class RoutineChecks {
    var time = Date(timeIntervalSince1970: 12 * 3600)
    var timeReads = 0
    var wakes: [(deadline: Date, work: @MainActor () -> Void)] = []
    var cancellations = 0
    var saves: [Garden] = []

    var effects: RoutineEffects {
        RoutineEffects(now: {
            self.timeReads += 1
            return self.time
        }, wake: { deadline, work in
            self.wakes.append((deadline, work))
            return { self.cancellations += 1 }
        }, saveGarden: { self.saves.append($0) })
    }

    func runner(garden: Garden = Garden()) -> RoutineRunner {
        let runner = RoutineRunner(routine: Routine(timeZone: TimeZone(secondsFromGMT: 0)!, random: { 0 }, garden: garden, thirstRandom: { 0 }),
                effects: effects)
        runner.onWake = { [weak runner] in _ = runner?.handle(.wake) }
        return runner
    }
}

@MainActor
@Test func supersededAndStoppedWakeCallbacksCannotReachRoutine() throws {
    let checks = RoutineChecks()
    let runner = checks.runner()
    let room = Room(spot: .window, activity: .other, mood: .content, fps: 12)
    _ = runner.handle(.sceneStarted(room))
    let first = try #require(checks.wakes.first)
    #expect(first.deadline == checks.time + 30)
    _ = runner.handle(.minutePassed)
    #expect(checks.cancellations == 1)
    checks.time = first.deadline
    let reads = checks.timeReads
    first.work() // Deliberately deliver despite cancellation.
    #expect(checks.timeReads == reads)
    let current = try #require(checks.wakes.last)
    current.work()
    #expect(checks.timeReads == reads + 1)
    // A due wake during a Stroll is held for arrival, without emitting another step.
    #expect(runner.handle(.finished).step == .fidget(.gaze))
    _ = runner.handle(.finished)
    let beforeStop = try #require(checks.wakes.last)
    _ = runner.handle(.sceneStopped)
    let afterStop = checks.timeReads
    beforeStop.work()
    #expect(checks.timeReads == afterStop)
}

@MainActor
@Test func nilStepRefreshesPropsUsingOneEventTimeAndDoesNotSaveUnchangedGarden() {
    let checks = RoutineChecks()
    let runner = checks.runner()
    let room = Room(spot: .desk, activity: .coding, mood: .content, fps: 12)
    _ = runner.handle(.sceneStarted(room))
    #expect(checks.saves.count == 1) // Newly adopted plants are kept.
    let reads = checks.timeReads
    checks.time += 3 * 3600
    #expect(runner.handle(.minutePassed).step == nil)
    #expect(checks.timeReads == reads + 1)
    #expect(runner.props.thirstyPlants == Set(Art.plantProps.map(Plant.init)))
    #expect(checks.saves.count == 1)
}

@MainActor
@Test func completingCareSavesGardenOnceAndRestoresItAcrossRunners() {
    let checks = RoutineChecks()
    var garden = Garden()
    garden.adopt(Art.plantProps.map(Plant.init), at: checks.time - 4 * 3600, random: { 0 })
    let runner = checks.runner(garden: garden)
    _ = runner.handle(.sceneStarted(Room(spot: .desk, activity: .coding, mood: .content, fps: 12)))
    #expect(checks.saves.isEmpty)
    checks.time += 30
    let plant = Plant(strip: "desk", x: 404)
    #expect(runner.handle(.wake).step == .errand(.waterPlant(plant, fromRight: true)))
    _ = runner.handle(.finished) // Arrive at the plant.
    #expect(checks.saves.isEmpty)
    _ = runner.handle(.finished) // Water it.
    #expect(checks.saves.count == 1)
    #expect(!runner.props.thirstyPlants.contains(plant))
    _ = runner.handle(.finished) // Return home.
    #expect(checks.saves.count == 1)
    let restored = checks.runner(garden: checks.saves[0])
    #expect(!restored.props.thirstyPlants.contains(plant))
}
