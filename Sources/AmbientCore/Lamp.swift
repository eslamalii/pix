import Foundation

/// The lamp on the desk side: the hour wants it lit from 19:00, at dusk, until 06:00. Pix switches it, so when the hour
/// turns it stays as it was until Pix gets to it.
struct Lamp {
    private static let onFrom = 19, onUntil = 6  // hours, local time

    /// Nil until the scene first starts, when it takes the hour's state.
    private var on: Bool?

    var lit: Bool { on == true }

    /// The scene started: the first time, the lamp is already as the hour wants it.
    mutating func found(atHour hour: Int) { if on == nil { on = Self.wanted(atHour: hour) } }

    /// It isn't as the hour wants it.
    func needsSwitching(atHour hour: Int) -> Bool { on.map { $0 != Self.wanted(atHour: hour) } ?? false }

    /// Pix switched it to how the hour wants it.
    mutating func switched(atHour hour: Int) { on = Self.wanted(atHour: hour) }

    private static func wanted(atHour hour: Int) -> Bool { hour >= onFrom || hour < onUntil }
}
