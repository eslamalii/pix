import Foundation

/// When the next Fidget falls due. The Routine tells it each step it starts and each time Pix settles; the Stroll and a
/// refreshed idle keep the deadline, anything else drops it. A Fidget that falls due mid-walk waits for the walk's end.
struct FidgetClock {
    private let random: () -> Double
    /// When the next Fidget falls due; nil for none.
    private(set) var due: Date?
    /// A Fidget fell due mid-walk: it plays when Pix reaches the end, or never.
    private var held = false

    /// `random` is the Routine's own dice, so its rolls keep their order.
    init(random: @escaping () -> Double) { self.random = random }

    /// Pix settled: the next Fidget falls due 30 to 90 seconds on, or never when none `fits` (focused, or none here).
    mutating func rest(at time: Date, fits: Bool) {
        due = fits ? time + 30 + random() * 60 : nil
    }

    mutating func started(_ step: Routine.Step) {
        switch step {
        case .stroll, .stop: break  // the Stroll carries the deadline, and a held Fidget, on
        case .idle: held = false
        default: (held, due) = (false, nil)
        }
    }

    /// `wake` came during `step`: true when a Fidget plays now. Mid-walk a due Fidget is held for the walk's end instead.
    mutating func wake(at time: Date, during step: Routine.Step?) -> Bool {
        guard let due, time >= due else { return false }
        self.due = nil
        switch step {
        case .stroll?:
            held = true
            return false
        case .stop?, .idle?: return true
        default: return false
        }
    }

    /// The Stroll's walk ended: true when a Fidget fell due on the way. It plays now or never.
    mutating func walkEnded() -> Bool {
        defer { held = false }
        return held
    }

    mutating func stop() { (due, held) = (nil, false) }
}
