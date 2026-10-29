import Foundation

/// One plant in the Room, found by its strip and its left edge within it.
public struct Plant: Hashable, Codable, Sendable {
    public let strip: String
    public let x: Int
    public init(strip: String, x: Int) { (self.strip, self.x) = (strip, x) }
    public init(_ prop: Art.Prop) { self.init(strip: prop.strip, x: prop.x) }

    /// Where the plant's middle is within its strip.
    var middle: Int { x + Int(Art.plant.width) / 2 }
}

/// Which plants are thirsty. Thirst is the Room's first Need.
public struct Garden: Codable, Equatable, Sendable {
    /// A watered plant turns thirsty this long after, somewhere in the range.
    static let thirstAfter: ClosedRange<TimeInterval> = (3 * 3600)...(6 * 3600)

    /// When each plant turns (or turned) thirsty.
    private var thirstyAt: [Plant: Date] = [:]

    public init() {}

    /// The Room's plants: ones the Garden hasn't seen before start freshly watered, and ones it no longer has are forgotten.
    public mutating func adopt(_ plants: [Plant], at time: Date, random: () -> Double) {
        thirstyAt = thirstyAt.filter { plants.contains($0.key) }
        for plant in plants where thirstyAt[plant] == nil { watered(plant, at: time, random: random) }
    }

    public func thirsty(at time: Date) -> [Plant] { thirstyAt.filter { $0.value <= time }.map(\.key) }

    /// The thirsty plant on `strip` whose middle is nearest `x` (along the strip), if any.
    func nearestThirsty(on strip: String, to x: Int, at time: Date) -> Plant? {
        thirsty(at: time).filter { $0.strip == strip }.min { abs($0.middle - x) < abs($1.middle - x) }
    }

    /// Pix watered the plant: it turns thirsty again after a while.
    public mutating func watered(_ plant: Plant, at time: Date, random: () -> Double) {
        let range = Self.thirstAfter
        thirstyAt[plant] = time.addingTimeInterval(range.lowerBound + random() * (range.upperBound - range.lowerBound))
    }
}
