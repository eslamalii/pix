import Foundation


/// A Fidget that uses a Prop: Pix walks to it, uses it, and walks back to its Spot.
public enum Errand: Equatable, Sendable {
    case switchLamp
    /// The desk-side plant whose left edge is `at`, approached from its right or its left.
    case waterPlant(at: Int, fromRight: Bool)
    /// The coffee at the cabinet: Pix pours a fresh mug.
    case refillMug

    /// The body Pix plays at the Prop.
    public var body: String {
        switch self {
        case .switchLamp: "switch"
        case .waterPlant: "water"
        case .refillMug: "pour"
        }
    }
}

/// Something Pix does now and then while idling: plays the body sheet named by its raw value, or, for water, runs the
/// plant Errand, or, for refill, the mug Errand.
public enum Fidget: String, CaseIterable, Sendable {
    case sip, stretch, lookaround, nod, popcorn, spin, gaze, wave, scratch, water, refill
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
        /// `nextWake` came: a wake before it changes nothing.
        case wake
        case minutePassed
        /// macOS moved to another time zone: the lamp follows the new hour.
        case timeZoneChanged(TimeZone)
        /// The scene left the Touch Bar (the Default bar, hidden, or rebuilt at a new size).
        case sceneStopped
    }

    public enum Step: Equatable, Sendable {
        /// Walk to a Spot from wherever Pix is, scrolling the Room if it's on another strip.
        case walk(to: Spot)
        /// Rest at the Spot in the Look.
        case idle(Spot, RestLook)
        case moment(Moment)
        /// A Fidget's body, played once.
        case fidget(Fidget)
        /// An Errand's first leg: walk to the Prop.
        case errand(Errand)
        /// At the Prop: use it.
        case use(Errand)
        /// Walk back to the Spot from an Errand, or from wherever a Moment cut one short.
        case walkBack(to: Spot)
        /// Arriving in the music corner: drop the needle on the record.
        case dropNeedle
        /// The Stroll: walk to an end of the window.
        case stroll(to: WindowEnd, RestLook)
        /// The Stroll: pause for a beat before turning toward the other end (0.5 s wait on wake).
        case turn(to: WindowEnd, RestLook)
        /// The Stroll: look around at an end of the window (1.5 s animation on finished).
        case lookAround(RestLook)
        /// The Stroll: stand a while at the left end of the window (2.5 s wait on wake).
        case stand(RestLook)
        /// The Stroll: stretch at the right end of the window (animation on finished).
        case stretch(RestLook)
        /// Mid-Stroll Look update: face and particles change without interrupting motion.
        case relook(RestLook)

        public static func idle(_ spot: Spot, _ mood: Mood) -> Step {
            .idle(spot, RestLook(spot: spot, mood: mood))
        }
        public static func stroll(to end: WindowEnd, _ mood: Mood = .content) -> Step {
            .stroll(to: end, RestLook(spot: .window, mood: mood))
        }
        public static func turn(to end: WindowEnd, _ mood: Mood = .content) -> Step {
            .turn(to: end, RestLook(spot: .window, mood: mood))
        }
        public static func lookAround(_ mood: Mood = .content) -> Step {
            .lookAround(RestLook(spot: .window, mood: mood))
        }
        public static func stand(_ mood: Mood = .content) -> Step {
            .stand(RestLook(spot: .window, mood: mood))
        }
        public static func stretch(_ mood: Mood = .content) -> Step {
            .stretch(RestLook(spot: .window, mood: mood))
        }
        public static func relook(_ mood: Mood) -> Step {
            .relook(RestLook(spot: .window, mood: mood))
        }
    }

    /// Where Pix is, as far as the Routine knows.
    private enum Place: Equatable {
        case spot(Spot)
        case prop
        /// A walk was replaced before it finished.
        case onTheWay
    }

    private static let mugSips = 3  // sips in a full mug
    private static let coffeeFrom = 6, coffeeUntil = 17  // hours, local time
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
    /// Which end Pix reached on its stroll walk.
    private var reachedEnd: WindowEnd?
    /// A Fidget fell due mid-walk or during turn: it plays when Pix reaches the end.
    private var fidgetHeld = false
    /// When the next Fidget falls due: set by an idle or settling at the window, kept by the Stroll's steps, cleared by anything else.
    private var fidgetDue: Date?
    /// Sips left in the mug: it starts empty at launch, so the first desk Fidget is the refill.
    private var sipsLeft = 0
    /// The Fidget Pix played last, so it doesn't play it twice in a row.
    private var lastFidget: Fidget?
    /// When the current wait step (turn 0.5s or stand 2.5s) ends.
    private var waitDeadline: Date?

    /// Where Pix was last seen: the scene starts with Pix there, and it walks into view if the Spot changed.
    public private(set) var lastSpot: Spot?

    public var lampLit: Bool { lamp == true }
    /// The mug on the desk has coffee in it (and steams).
    public var mugFull: Bool { sipsLeft > 0 }

    /// When the view should send `wake` (nil: no need).
    public var nextWake: Date? {
        switch (waitDeadline, fidgetDue) {
        case let (w?, f?): min(w, f)
        case let (w?, nil): w
        case let (nil, f?): f
        case (nil, nil): nil
        }
    }

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
            (heading, reachedEnd, waitDeadline) = (.left, nil, nil)
            return from == room.spot ? settle(at: time) : walk(to: room.spot)

        case .sceneStopped:
            (running, current, waiting) = (false, nil, nil)
            (heading, reachedEnd, fidgetHeld, fidgetDue, waitDeadline) = (.left, nil, false, nil, nil)
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
            if new.spot == .window {
                let moodChanged = new.mood != old?.mood
                let hotChanged = new.hot != old?.hot
                if moodChanged {
                    fidgetDue = new.mood == .focused || Self.fidgets(for: new, sipsLeft: sipsLeft, coffee: true).isEmpty ? nil : time + 30 + random() * 60
                }
                if isStrolling && (moodChanged || hotChanged) {
                    return .relook(restLook())
                }
                return nil
            }
            switch current {
            case .idle?:
                if new.mood != old?.mood || new.hot != old?.hot { return settle(at: time) }
            default: break
            }
            return nil  // the Activity or frame rate alone changes nothing Pix does

        case .momentArrived(let moment):
            if !running { waiting = moment; return nil }
            if case .walk = current { waiting = moment; return nil }  // it plays on arrival
            waitDeadline = nil
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
                if errand == .refillMug { sipsLeft = Self.mugSips }
                return start(.walkBack(to: room?.spot ?? .desk))
            case .stroll(let end, _):
                reachedEnd = end
                heading = end.other
                waitDeadline = time + 0.5
                return start(.turn(to: end.other, restLook()))
            case .lookAround:
                if reachedEnd == .right {
                    return start(.stretch(restLook()))
                } else {
                    waitDeadline = time + 2.5
                    return start(.stand(restLook()))
                }
            case .stretch:
                return nextStrollStep()
            case .idle, .moment, .fidget, .dropNeedle:
                break
            case .turn, .stand, .relook:
                break
            }
            return settle(at: time)

        case .wake:
            guard running, let wakeTime = nextWake, time >= wakeTime else { return nil }
            let fidgetTime = fidgetDue.map { time >= $0 } == true
            if fidgetTime {
                fidgetDue = nil
            }
            switch current {
            case .stroll:
                if fidgetTime { fidgetHeld = true }
                return nil

            case .turn:
                if fidgetTime { fidgetHeld = true }
                guard let deadline = waitDeadline, time >= deadline else { return nil }
                waitDeadline = nil
                if fidgetHeld, let fidget = fidget(at: time) {
                    fidgetHeld = false
                    return fidget
                }
                return start(.lookAround(restLook()))

            case .lookAround:
                if fidgetTime, let fidget = fidget(at: time) {
                    return fidget
                }
                return nil

            case .stand:
                if fidgetTime, let fidget = fidget(at: time) {
                    waitDeadline = nil
                    return fidget
                }
                guard let deadline = waitDeadline, time >= deadline else { return nil }
                waitDeadline = nil
                return nextStrollStep()

            case .idle:
                if fidgetTime { return fidget(at: time) }
                return nil

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

    private var isStrolling: Bool {
        switch current {
        case .stroll, .turn, .lookAround, .stand, .stretch: true
        default: false
        }
    }

    private func restLook() -> RestLook {
        guard let room else { return RestLook(spot: .window, mood: .content) }
        return RestLook(spot: room.spot, mood: room.mood, agentWorking: room.agentWorking, hot: room.hot)
    }

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
        fidgetDue = room.mood == .focused || Self.fidgets(for: room, sipsLeft: sipsLeft, coffee: true).isEmpty ? nil : time + 30 + random() * 60
        if room.spot == .window {
            return nextStrollStep()
        }
        return start(.idle(room.spot, restLook()))
    }

    private mutating func walk(to spot: Spot) -> Step {
        (needleDown, heading, reachedEnd, waitDeadline) = (false, .left, nil, nil)  // arriving at the window, the Stroll starts left
        return start(.walk(to: spot))
    }

    /// The Stroll's next walk.
    private mutating func nextStrollStep() -> Step {
        reachedEnd = nil
        return start(.stroll(to: heading, restLook()))
    }

    /// A Fidget that fits where Pix is and how it feels, if any.
    private mutating func fidget(at time: Date) -> Step? {
        guard let room, room.mood != .focused else { return nil }
        let all = Self.fidgets(for: room, sipsLeft: sipsLeft, coffee: coffeeHours(at: time))
        guard !all.isEmpty else { return nil }
        let fresh = all.filter { $0 != lastFidget }
        let choices = fresh.isEmpty ? all : fresh  // a Spot with one Fidget plays it every time
        let choice = choices[min(Int(random() * Double(choices.count)), choices.count - 1)]
        lastFidget = choice
        switch choice {
        case .water: return start(.errand(nearestPlant(to: room.spot)))
        case .refill: return start(.errand(.refillMug))
        case .sip:
            sipsLeft -= 1
            return start(.fidget(choice))
        default: return start(.fidget(choice))
        }
    }

    private mutating func start(_ step: Step) -> Step {
        current = step
        switch step {
        case .stroll, .turn, .lookAround, .stand, .stretch:
            // The Fidget deadline carries on
            break
        case .idle:
            waitDeadline = nil
            fidgetHeld = false
        default:
            waitDeadline = nil
            fidgetHeld = false
            fidgetDue = nil
        }
        switch step {
        case .walk, .errand, .walkBack: place = .onTheWay  // until it finishes
        default: break
        }
        if case .moment = step { lastFidget = nil }  // a cut-short Errand may be tried again at once
        if case .walk = step { lastFidget = nil }
        return step
    }

    /// The Fidgets that fit where Pix is and how it feels.
    static func fidgets(for room: Room, sipsLeft: Int, coffee: Bool) -> [Fidget] {
        if room.mood == .sleepy { return room.spot == .couch || room.spot == .call ? [] : [.nod] }  // asleep on the couch, awake on a call: none
        return switch room.spot {
        case .desk: (coffee ? [sipsLeft > 0 ? .sip : .refill] : []) + [.stretch, .lookaround, .water]
        case .call: [.nod]
        case .couch: [.popcorn]
        case .musicCorner: [.spin]
        case .window: [.gaze, .wave, .scratch]
        }
    }

    /// The desk-side plant nearest the Spot, approached from Pix's side.
    private func nearestPlant(to spot: Spot) -> Errand {
        let here = Art.spot(spot).x, half = Int(Art.plant.width) / 2
        let plants = Art.props.filter { $0.name == "plant" && $0.strip == "desk" }.map(\.x)
        let plant = plants.min { abs($0 + half - here) < abs($1 + half - here) } ?? 0
        return .waterPlant(at: plant, fromRight: here > plant + half)
    }

    /// Pix drinks coffee from morning to late afternoon; in the evening the mug is left alone.
    private func coffeeHours(at time: Date) -> Bool {
        (Self.coffeeFrom..<Self.coffeeUntil).contains(calendar.component(.hour, from: time))
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
