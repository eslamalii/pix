import Foundation
import AmbientCore

/// Time and side effects used by RoomComposition.
/// Scheduling returns cancellation; the composition also rejects callbacks from superseded deadlines.
@MainActor
struct RoutineEffects {
    var now: () -> Date = { Date() }
    var wake: (_ deadline: Date, _ work: @escaping @MainActor () -> Void) -> (() -> Void) = { deadline, work in
        let task = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
            work()
        }
        return { task.cancel() }
    }
    /// What the Routine keeps between launches; the app wires the real write, so by default nothing is saved.
    var save: (Routine.Saved) -> Void = { _ in }
}
