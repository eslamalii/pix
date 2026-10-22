import Foundation

/// What Pix remembers of the user's days, kept only on this Mac: the days it saw them, when they first arrived on
/// weekdays, how many Pets each day got, how many Focus sessions they finished, and which Occasions they spent
/// together. Days are "yyyy-MM-dd" in the user's time zone. Nothing else.
public struct Memory: Codable, Equatable, Sendable {
    /// The days Pix saw the user, oldest first.
    public private(set) var days: [String] = []
    /// Weekday → minutes after midnight of the day's first arrival.
    public private(set) var arrivals: [String: Int] = [:]
    /// Day → Pets.
    public private(set) var pets: [String: Int] = [:]
    /// Days together and Pets, ever: what earns Pix its hats.
    public private(set) var totalDays = 0
    public private(set) var totalPets = 0
    /// Focus sessions that ran to the end, ever.
    public private(set) var totalFocusSessions = 0
    /// The Occasions Pix spent with the user, ever: they earn Pix its Occasion hats.
    public private(set) var occasions: Set<Occasion> = []

    public init() {}

    /// A Memory saved before a field existed still reads, with that field starting from nothing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([String].self, forKey: .days) ?? []
        arrivals = try c.decodeIfPresent([String: Int].self, forKey: .arrivals) ?? [:]
        pets = try c.decodeIfPresent([String: Int].self, forKey: .pets) ?? [:]
        totalDays = try c.decodeIfPresent(Int.self, forKey: .totalDays) ?? days.count
        totalPets = try c.decodeIfPresent(Int.self, forKey: .totalPets) ?? pets.values.reduce(0, +)
        totalFocusSessions = try c.decodeIfPresent(Int.self, forKey: .totalFocusSessions) ?? 0
        occasions = try c.decodeIfPresent(Set<Occasion>.self, forKey: .occasions) ?? []
    }

    static let keepDays = 60, keepArrivals = 20, keepPets = 14
    static let backAfterDays = 4      // away this many days or more earns a "back" Greeting (Friday to Monday doesn't)
    static let usualAfter = 5         // weekday arrivals needed before Pix knows when the user usually arrives
    static let earlyBy = 45           // minutes before the usual arrival that count as early
    static let manyPets = 5           // Pets in a day that make the next morning's Greeting cheerful

    /// What makes a first arrival special: back after days away, early, the weekend, or after a day of Pets.
    private func specialGreeting(at time: Date, calendar: Calendar) -> Greeting? {
        if let last = days.last, let gap = Self.days(from: last, to: time, in: calendar), gap >= Self.backAfterDays { return .missedYou }
        let weekend = calendar.isDateInWeekend(time)
        if !weekend, let usual = usualArrival, Self.minutes(time, in: calendar) <= usual - Self.earlyBy { return .early }
        if weekend { return .weekend }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: time), pets[Self.day(yesterday, in: calendar), default: 0] >= Self.manyPets {
            return .cheerful
        }
        return nil
    }

    /// The median of the recent weekday arrivals, in minutes after midnight; nil until there are enough of them.
    public var usualArrival: Int? {
        guard arrivals.count >= Self.usualAfter else { return nil }
        return arrivals.values.sorted()[arrivals.count / 2]
    }

    /// Notes that the user is here today. True the first time today.
    @discardableResult
    public mutating func saw(at time: Date, calendar: Calendar) -> Bool {
        if let occasion = Occasion(on: time, calendar: calendar) { occasions.insert(occasion) }
        let today = Self.day(time, in: calendar)
        guard days.last != today else { return false }
        days = Array((days + [today]).suffix(Self.keepDays))
        totalDays += 1
        return true
    }

    /// The user arrived and Pix greets them. The day's first arrival may be special (an Occasion first, then what Pix
    /// remembers of the days before) and, on a weekday, notes its time; nil after that, or when nothing is special.
    @discardableResult
    public mutating func arrive(at time: Date, calendar: Calendar) -> Greeting? {
        let special = Occasion(on: time, calendar: calendar)?.greeting ?? specialGreeting(at: time, calendar: calendar)
        guard saw(at: time, calendar: calendar) else { return nil }  // read before it's remembered: today isn't new after
        if !calendar.isDateInWeekend(time) {
            arrivals[Self.day(time, in: calendar)] = Self.minutes(time, in: calendar)
            arrivals = Self.latest(Self.keepArrivals, of: arrivals)
        }
        return special
    }

    /// A Focus session ran to the end (one stopped early doesn't count).
    public mutating func finishedFocus() { totalFocusSessions += 1 }

    public mutating func petted(at time: Date, calendar: Calendar) {
        pets[Self.day(time, in: calendar), default: 0] += 1
        totalPets += 1
        pets = Self.latest(Self.keepPets, of: pets)
    }

    // MARK: - Days

    static func day(_ time: Date, in calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: time)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func minutes(_ time: Date, in calendar: Calendar) -> Int {
        calendar.component(.hour, from: time) * 60 + calendar.component(.minute, from: time)
    }

    /// Whole days from a remembered day to the day of `time`.
    static func days(from day: String, to time: Date, in calendar: Calendar) -> Int? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: time)).day
    }

    /// The `count` latest days of a by-day record ("yyyy-MM-dd" sorts by date).
    private static func latest(_ count: Int, of record: [String: Int]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: record.sorted { $0.key < $1.key }.suffix(count).map { ($0.key, $0.value) })
    }
}

/// A hat Pix earns by spending time with the user, worn by choice from the menu. Nothing to buy or trade.
public enum Hat: String, CaseIterable, Sendable {
    // Only ever add hats at the end: skins draw them by position (see Art.hats).
    case cap, beanie, party, flower, crown, headband, witch, santa, topHat

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
