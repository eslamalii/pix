import AppKit

/// The two ways playback waits: finite Core Animation transactions and delayed Stroll/Pastime beats.
/// Tests can deliver obsolete callbacks deliberately; Playback still owns whether they are valid.
@MainActor
struct PlaybackTiming {
    var transaction: @MainActor (_ animations: () -> Void, _ completion: @escaping @MainActor () -> Void) -> Void
    var after: @MainActor (_ seconds: Double, _ work: @escaping @MainActor () -> Void) -> (() -> Void)

    static var live: PlaybackTiming {
        PlaybackTiming(
            transaction: { animations, completion in
                CATransaction.begin()
                CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion() } }
                animations()
                CATransaction.commit()
            },
            after: { seconds, work in
                let task = Task { @MainActor in
                    do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                    work()
                }
                return { task.cancel() }
            }
        )
    }
}
