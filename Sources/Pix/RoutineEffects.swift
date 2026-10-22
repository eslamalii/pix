import Foundation
import AmbientCore

/// Time and side effects used by RoutineRunner.
/// Scheduling returns cancellation; the runner also rejects callbacks from superseded deadlines.
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
    var saveGarden: (Garden) -> Void = { Settings.garden = $0 }
}
