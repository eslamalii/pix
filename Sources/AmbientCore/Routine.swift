import Foundation


/// A Fidget that uses a Prop: Pix walks to it, uses it, and walks back to its Spot.
public enum Errand: Equatable, Sendable {
    case switchLamp
    /// The desk-side plant whose left edge is `at`, approached from its right or its left.
    case waterPlant(at: Int, fromRight: Bool)

    /// The body Pix plays at the Prop.
    public var body: String {
        switch self {
        case .switchLamp: "switch"
        case .waterPlant: "water"
        }
    }
}

/// The two ends of the window that Pix strolls between.
public enum WindowEnd: Sendable {
    case left, right

    var other: WindowEnd { self == .left ? .right : .left }

    /// What Pix does on reaching the end, after looking around: stretch at the right, stand at the left.
    var stopBody: String? { self == .right ? "stretch" : nil }
}

/// What Pix does next with its body in the Room. The view tells it what happened and performs the step it asks for;
/// it decides in Spots and Props, never in screen points.
public struct Routine {
    public enum Event: Sendable {
        /// The scene is on the Touch Bar, showing this Room.
        case sceneStarted(Room)
        case roomChanged(Room)
        case momentArrived(Moment)
        /// The step the Routine last asked for played to its end.
        case finished
        case fidgetDue
        case minutePassed
        /// macOS moved to another time zone: the lamp follows the new hour.
        case timeZoneChanged(TimeZone)
        /// The scene left the Touch Bar (the Default bar, hidden, or rebuilt at a new size).
        case sceneStopped
    }

    public enum Step: Equatable, Sendable {
        /// Walk to a Spot from wherever Pix is, scrolling the Room if it's on another strip.
        case walk(to: Spot)
        /// Rest at the Spot in the Mood; a Fidget is due after `fidgetIn` seconds (nil: none).
        case idle(Spot, Mood, fidgetIn: Double?)
        case moment(Moment)
        /// A Fidget body, played once.
        case fidget(String)
        /// An Errand's first leg: walk to the Prop.
        case errand(Errand)
        /// At the Prop: use it.
        case use(Errand)
        /// Walk back to the Spot from an Errand, or from wherever a Moment cut one short.
        case walkBack(to: Spot)
        /// Arriving in the music corner: drop the needle on the record.
        case dropNeedle
        /// The Stroll: walk to an end of the window.
        case stroll(to: WindowEnd)
        /// The Stroll: at an end of the window, look around, then play `body` (nil: stand a while).
        case stopAt(WindowEnd, body: String?)
    }

    /// Where Pix is, as far as the Routine knows.
    private enum Place: Equatable {
        case spot(Spot)
        case prop
        /// A walk was replaced before it finished.
        case onTheWay
    }

    private static let lampOnFrom = 19, lampOnUntil = 6  // hours, local time

    private var calendar: Calendar
    private let random: () -> Double
    private var room: Room?
    private var running = false
    private var current: Step?
    private var place: Place?
    private var waiting: Moment?
    private var needleDown = false
    private var lamp: Bool?  // nil until the scene first starts, when it takes the hour's state
    /// The end of the window the Stroll heads for next.
    private var heading = WindowEnd.left
    /// The Stroll's walk or stop the view is performing. A new idle at the window leaves it running.
    private var leg: Step?
    /// A Fidget fell due mid-walk: it plays when Pix reaches the end.
    private var fidgetHeld = false

    /// Where Pix was last seen: the scene starts with Pix there, and it walks into view if the Spot changed.
    public private(set) var lastSpot: Spot?

    public var lampLit: Bool { lamp == true }

    /// A Stroll walk or stop is underway: an idle at the window sets Pix's Look and leaves it running. Otherwise the
    /// idle reports finished and the Stroll starts.
    public var strolling: Bool { leg != nil }

    /// `random` returns a number in 0..<1; tests pass fixed ones.
    public init(timeZone: TimeZone, random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.random = random
    }

    @discardableResult
    public mutating func handle(_ event: Event, at time: Date) -> Step? {
        switch event {
        case .sceneStarted(let room):
            self.room = room
            running = true
            if lamp == nil { lamp = lampWanted(at: time) }
            let from = lastSpot ?? room.spot
            (place, lastSpot) = (.spot(from), room.spot)
            return from == room.spot ? settle(at: time) : walk(to: room.spot)

        case .sceneStopped:
            (running, current, waiting) = (false, nil, nil)
            (leg, fidgetHeld, heading) = (nil, false, .left)  // the scene starts with Pix at its Spot
            return nil

        case .roomChanged(let new):
            let old = room
            room = new
            guard running else { return nil }
            if new.spot != old?.spot {
                lastSpot = new.spot
                // Two Spots in one place (the desk and the call): Pix stays put and settles into the new one.
                if let old, Art.spot(old.spot) == Art.spot(new.spot), place == .spot(old.spot) {
                    place = .spot(new.spot)
                    if case .idle = current { return settle(at: time) }
                    return nil
                }
                return walk(to: new.spot)
            }
            switch current {
            case .idle?, .stroll?, .stopAt?: if new.mood != old?.mood { return settle(at: time) }
            default: break
            }
            return nil  // the Activity or frame rate alone changes nothing Pix does

        case .momentArrived(let moment):
            if !running { waiting = moment; return nil }
            if case .walk = current { waiting = moment; return nil }  // it plays on arrival
            return start(.moment(moment))

        case .finished:
            guard running, let step = current else { return nil }
            switch step {
            case .walk(let spot), .walkBack(let spot):
                place = .spot(spot)
            case .errand(let errand):
                place = .prop
                return start(.use(errand))
            case .use(let errand):
                if errand == .switchLamp { lamp = lampWanted(at: time) }
                return start(.walkBack(to: room?.spot ?? .desk))
            case .idle(.window, _, _), .stroll, .stopAt:
                return nextStrollStep()  // resting at the window is strolling
            case .idle, .moment, .fidget, .dropNeedle:
                break
            }
            return settle(at: time)

        case .fidgetDue:
            guard running else { return nil }
            if case .stroll? = leg {
                fidgetHeld = true  // never mid-walk
                return nil
            }
            switch current {
            case .idle?, .stopAt?:
                return fidget()
            default:
                return nil
            }

        case .timeZoneChanged(let zone):
            calendar.timeZone = zone
            return nil

        case .minutePassed:
            guard running, case .idle = current, lampNeedsSwitching(at: time) else { return nil }
            return start(.errand(.switchLamp))
        }
    }

    // MARK: - Deciding

    /// What Pix does when nothing else is going on: a waiting Moment, the lamp, the way home, the needle, or rest.
    private mutating func settle(at time: Date) -> Step? {
        guard let room else { return nil }
        if let moment = waiting {
            waiting = nil
            return start(.moment(moment))
        }
        if lampNeedsSwitching(at: time) { return start(.errand(.switchLamp)) }
        // A Moment cut an Errand short: walk back first. At the window, anywhere is part of the stroll.
        if room.spot != .window && place != .spot(room.spot) { return start(.walkBack(to: room.spot)) }
        if room.spot == .musicCorner && !needleDown {  // part of arriving, not a Moment
            needleDown = true
            return start(.dropNeedle)
        }
        let fidgetIn = room.mood == .focused || Self.fidgets(for: room).isEmpty ? nil : 30 + random() * 60
        return start(.idle(room.spot, room.mood, fidgetIn: fidgetIn))
    }

    private mutating func walk(to spot: Spot) -> Step {
        (needleDown, heading) = (false, .left)  // arriving at the window, the Stroll starts left
        return start(.walk(to: spot))
    }

    /// The Stroll's next walk or stop: a walk ended at an end, so Pix stops there (or plays the Fidget it held);
    /// otherwise it walks to the end it's heading for.
    private mutating func nextStrollStep() -> Step {
        if case .stroll(let end)? = leg {
            heading = end.other
            if fidgetHeld, let fidget = fidget() { return fidget }
            return start(.stopAt(end, body: end.stopBody))
        }
        return start(.stroll(to: heading))
    }

    /// A Fidget that fits where Pix is and how it feels, if any.
    private mutating func fidget() -> Step? {
        guard let room, room.mood != .focused else { return nil }
        let choices = Self.fidgets(for: room)
        guard !choices.isEmpty else { return nil }
        let choice = choices[min(Int(random() * Double(choices.count)), choices.count - 1)]
        return choice == "water" ? start(.errand(nearestPlant(to: room.spot))) : start(.fidget(choice))
    }

    private mutating func start(_ step: Step) -> Step {
        current = step
        switch step {
        case .stroll, .stopAt: (leg, fidgetHeld) = (step, false)
        case .idle(.window, _, _): break  // the walk or stop carries on, and a held Fidget still waits for its end
        default: (leg, fidgetHeld) = (nil, false)
        }
        switch step {
        case .walk, .errand, .walkBack: place = .onTheWay  // until it finishes
        default: break
        }
        return step
    }

    /// The Fidgets that fit where Pix is and how it feels. "water" is the plant Errand.
    static func fidgets(for room: Room) -> [String] {
        if room.mood == .sleepy { return room.spot == .couch || room.spot == .call ? [] : ["nod"] }  // asleep on the couch, awake on a call: none
        return switch room.spot {
        case .desk: ["sip", "stretch", "lookaround", "water"]
        case .call: ["nod"]
        case .couch: ["popcorn"]
        case .musicCorner: ["spin"]
        case .window: ["gaze", "wave", "scratch"]
        }
    }

    /// The desk-side plant nearest the Spot, approached from Pix's side.
    private func nearestPlant(to spot: Spot) -> Errand {
        let here = Art.spot(spot).x, half = Int(Art.plant.width) / 2
        let plants = Art.props.filter { $0.name == "plant" && $0.strip == "desk" }.map(\.x)
        let plant = plants.min { abs($0 + half - here) < abs($1 + half - here) } ?? 0
        return .waterPlant(at: plant, fromRight: here > plant + half)
    }

    private func lampWanted(at time: Date) -> Bool {
        let hour = calendar.component(.hour, from: time)
        return hour >= Self.lampOnFrom || hour < Self.lampOnUntil
    }

    /// The lamp isn't as the hour wants it, and Pix is on the desk side to do something about it.
    private func lampNeedsSwitching(at time: Date) -> Bool {
        guard let lamp, let room, room.spot != .window else { return false }
        return lamp != lampWanted(at: time)
    }
}
