import AppKit

/// The view coalesces layout changes and waits briefly to distinguish a tap from a Pet.
/// Controlled timing can deliver cancelled work; the view still decides whether it is current.
@MainActor
struct PixViewTiming {
    var refresh: (@escaping @MainActor () -> Void) -> Void
    var after: (Double, @escaping @MainActor () -> Void) -> (() -> Void)

    static var live: PixViewTiming {
        PixViewTiming(refresh: { work in DispatchQueue.main.async { work() } }, after: { seconds, work in
            let task = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                work()
            }
            return { task.cancel() }
        })
    }
}
