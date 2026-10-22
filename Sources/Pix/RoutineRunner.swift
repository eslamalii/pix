import Foundation
import AmbientCore

/// Delivers Routine events with one time observation and owns their wake and persistence lifetime.
@MainActor
final class RoutineRunner {
    struct Update {
        let time: Date
        let props: Props
        let step: Routine.Step?
    }

    private var routine: Routine
    private let effects: RoutineEffects
    private var savedGarden: Garden
    private var cancelWake: (() -> Void)?
    private var generation = 0
    private(set) var props: Props
    var lastSpot: Spot? { routine.lastSpot }
    var onWake: () -> Void = {}

    init(routine: Routine, effects: RoutineEffects) {
        self.routine = routine
        self.effects = effects
        savedGarden = routine.garden
        props = routine.props(at: effects.now())
    }

    func handle(_ event: Routine.Event) -> Update {
        let time = effects.now()
        let step = routine.handle(event, at: time)
        props = routine.props(at: time)
        cancelWake?()
        cancelWake = nil
        generation += 1
        let mine = generation
        if let deadline = routine.nextWake {
            cancelWake = effects.wake(deadline) { [weak self] in
                guard let self, self.generation == mine else { return }
                self.onWake()
            }
        }
        if routine.garden != savedGarden {
            effects.saveGarden(routine.garden)
            savedGarden = routine.garden
        }
        return Update(time: time, props: props, step: step)
    }
}
