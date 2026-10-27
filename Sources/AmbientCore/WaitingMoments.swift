import Foundation

/// The Moments waiting for Pix to be free: before the scene starts, during a walk to a Spot, a Pastime or a Greeting.
/// A Greeting holds the front until it has played, since the user can't ask for it again; behind it only the latest
/// other Moment waits, as a newer Moment replaces one still playing.
struct WaitingMoments {
    private var greeting: Moment?
    private var latest: Moment?

    /// What Pix was doing while the user was Away, when the Greeting waiting at the front comes after one.
    var pastime: Pastime? {
        guard case .greeting(_, let pastime)? = greeting else { return nil }
        return pastime
    }

    mutating func add(_ moment: Moment) {
        if case .greeting = moment { greeting = moment } else { latest = moment }
    }

    /// The Moment to play now, Greeting first, taken off the queue.
    mutating func next() -> Moment? {
        defer { if greeting != nil { greeting = nil } else { latest = nil } }
        return greeting ?? latest
    }

    mutating func drop() { (greeting, latest) = (nil, nil) }
}
