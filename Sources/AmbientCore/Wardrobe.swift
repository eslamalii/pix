import Foundation

extension Hat {
    /// What earns a hat: days together, Pets, Focus sessions finished, or an Occasion spent with the user.
    public enum Requirement: Equatable, Sendable {
        case days(Int), pets(Int), focusSessions(Int), occasion(Occasion)
    }

    public var requirement: Requirement {
        switch self {
        case .cap: .days(3)
        case .beanie: .days(7)
        case .party: .pets(25)
        case .flower: .pets(100)
        case .crown: .days(30)
        case .headband: .focusSessions(10)
        case .witch: .occasion(.halloween)
        case .santa: .occasion(.holidays)
        case .topHat: .occasion(.newYear)
        }
    }

    public func isEarned(by memory: Memory) -> Bool {
        switch requirement {
        case .days(let days): memory.totalDays >= days
        case .pets(let pets): memory.totalPets >= pets
        case .focusSessions(let sessions): memory.totalFocusSessions >= sessions
        case .occasion(let occasion): memory.occasions.contains(occasion)
        }
    }

    /// The hats Pix has earned, in menu order.
    public static func earned(by memory: Memory) -> [Hat] { allCases.filter { $0.isEarned(by: memory) } }

    /// How it's earned, for the menu: "3 days together" or "25 Pets".
    public var howToEarn: String {
        switch requirement {
        case .days(let days): "\(days) days together"
        case .pets(let pets): "\(pets) Pets"
        case .focusSessions(let sessions): "\(sessions) Focus sessions"
        case .occasion(.halloween): "Halloween together"
        case .occasion(.holidays): "the holidays together"
        case .occasion(.newYear): "New Year's Day together"
        }
    }
}

/// The Hats Pix has earned and the one it wears. A hat just earned goes straight on and owes its NEW HAT until the Room
/// shows a quiet moment for it; a hat given back with the Memory comes off.
struct Wardrobe {
    /// Every hat counts as earned (the developer's allHats setting).
    private let allHats: Bool
    private(set) var worn: Hat?
    /// A hat was earned alongside a Greeting, or on the Default bar, and its NEW HAT is still to play.
    private var owed: Hat?

    init(wearing hat: Hat?, memory: Memory, allHats: Bool) {
        self.allHats = allHats
        worn = hat.flatMap { wearable(by: memory).contains($0) ? $0 : nil }
    }

    /// The hats Pix may wear: those it has earned, or all of them with allHats.
    func wearable(by memory: Memory) -> [Hat] { allHats ? Hat.allCases : Hat.earned(by: memory) }

    /// The user chose a hat from the menu, or none.
    mutating func choose(_ hat: Hat?, memory: Memory) {
        if hat.map(wearable(by: memory).contains) ?? true { worn = hat }
    }

    /// An event changed the Memory from `before` to `memory` and would play `moment`: the Moment to play instead, which
    /// is the NEW HAT when one is owed and the Room is showing (`onRoom`).
    mutating func moment(_ moment: Moment?, from before: Memory, to memory: Memory, onRoom: Bool) -> Moment? {
        let earnedBefore = Hat.earned(by: before), earned = Hat.earned(by: memory)
        let newHats = earned.filter { !earnedBefore.contains($0) }
        if let newest = newHats.last { (worn, owed) = (newest, newest) }  // a hat just earned goes straight on
        if let hat = worn, !wearable(by: memory).contains(hat) { worn = nil }  // given back with the Memory
        if let hat = owed, !earned.contains(hat) { owed = nil }
        guard owed != nil, onRoom else { return moment }  // nobody sees it on the Default bar: it waits
        switch moment {
        case .greeting?: return moment  // the Greeting first; NEW HAT follows on the next quiet event
        case .some where newHats.isEmpty: return moment  // a NEW HAT owed from before waits for an event with no Moment of its own
        default:
            // A hat is rare: earning one is the Moment, whatever else was about to play.
            owed = nil
            return .newHat
        }
    }
}
