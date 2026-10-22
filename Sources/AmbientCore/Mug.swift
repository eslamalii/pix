import Foundation

/// The mug on the desk. It starts empty at launch, holds three sips once filled, and Pix drinks from it only in coffee
/// hours: a mug left over in the evening goes cold. The Routine tells it each step it starts, so it knows when it's in hand.
struct Mug {
    private static let sips = 3
    private static let coffeeFrom = 6, coffeeUntil = 17  // hours, local time

    private var sipsLeft = 0
    /// Pix has the mug in hand: from setting off on the refill until it's idle again (or leaves for another Spot).
    private(set) var inHand = false

    /// Coffee in it, in coffee hours.
    func hot(atHour hour: Int) -> Bool { sipsLeft > 0 && Self.coffeeHours(hour) }

    /// The desk's coffee Fidget at `hour`: a sip from a full mug, the refill of an empty one, none out of coffee hours.
    func fidget(atHour hour: Int) -> Fidget? { Self.coffeeHours(hour) ? (sipsLeft > 0 ? .sip : .refill) : nil }

    mutating func started(_ step: Routine.Step) {
        switch step {
        case .errand(.refillMug), .pastime(.coffee): inHand = true
        case .walk, .idle: inHand = false
        default: break
        }
    }

    /// Full again: after the refill, still in hand; after the coffee Pastime, in hand only if Pix takes it to the desk.
    mutating func filled(inHand: Bool) { (sipsLeft, self.inHand) = (Self.sips, inHand) }

    mutating func sipped() { sipsLeft -= 1 }

    private static func coffeeHours(_ hour: Int) -> Bool { (coffeeFrom..<coffeeUntil).contains(hour) }
}
