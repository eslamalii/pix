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

    /// Plants the Garden hasn't seen before start freshly watered.
    public mutating func adopt(_ plants: [Plant], at time: Date, random: () -> Double) {
        for plant in plants where thirstyAt[plant] == nil { watered(plant, at: time, random: random) }
    }

    public func thirsty(at time: Date) -> [Plant] { thirstyAt.filter { $0.value <= time }.map(\.key) }

    /// Pix watered the plant: it turns thirsty again after a while.
    public mutating func watered(_ plant: Plant, at time: Date, random: () -> Double) {
        let range = Self.thirstAfter
        thirstyAt[plant] = time.addingTimeInterval(range.lowerBound + random() * (range.upperBound - range.lowerBound))
    }
}
