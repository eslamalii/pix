import Foundation

/// What Pix was doing on its own while the user was Away, caught for a moment when they come back.
public enum Pastime: String, Sendable, CaseIterable {
    case doze, coffee, gaze

    /// The body Pix plays while it is found: sitting on the couch, pouring, gazing.
    public var body: String {
        switch self {
        case .doze: "couch"
        case .coffee: "pour"
        case .gaze: "gaze"
        }
    }

    /// The Spot whose part of the Room Pix is found in: the couch, the desk (the coffee machine stands beside it), the window.
    public var spot: Spot {
        switch self {
        case .doze: .couch
        case .coffee: .desk
        case .gaze: .window
        }
    }

    /// What Pix is found doing: dozing at night; making the morning's coffee; dozing too after a long absence; else
    /// gazing out of the window.
    public static func found(awayFor away: TimeInterval, at time: Date, calendar: Calendar) -> Pastime {
        let hour = calendar.component(.hour, from: time)
        if hour >= Rules.sleepyFrom || hour < Rules.sleepyUntil { return .doze }
        if (Rules.cheerfulFrom..<Rules.cheerfulUntil).contains(hour) { return .coffee }
        return away >= Rules.dozesAfter ? .doze : .gaze
    }
}
