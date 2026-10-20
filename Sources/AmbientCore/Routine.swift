import Foundation


/// A trip to a Prop, as a Fidget, as Care, or at a time of day: Pix walks to it, uses it, and walks back to its Spot.
public enum Errand: Equatable, Sendable {
    case switchLamp
    /// A thirsty plant, approached from its right or its left.
    case waterPlant(Plant, fromRight: Bool)
    /// The coffee machine by the desk: Pix takes its mug there and fills it.
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

/// Something Pix does now and then while idling: plays the body sheet named by its raw value, or, for refill, runs the
/// mug Errand.
public enum Fidget: String, CaseIterable, Sendable {
    case sip, stretch, lookaround, nod, popcorn, spin, gaze, wave, scratch, refill
}

/// The two ends of the window that Pix strolls between.
public enum WindowEnd: Sendable {
    case left, right

    var other: WindowEnd { self == .left ? .right : .left }

    /// What Pix does on reaching the end, after looking around: stretch at the right, stand at the left.
    var stopBody: String? { self == .right ? "stretch" : nil }
}

/// What the Room's Props show right now: what the Routine decides about the lamp and the mug, as the view paints it.
public struct Props: Equatable, Sendable {
    public var lampLit: Bool
    /// Pix has the mug in hand, so the desk shows no mug.
    public var mugAway: Bool
    /// The mug on the desk has coffee in it and it's coffee hours (a mug left over in the evening goes cold).
    public var mugSteams: Bool
    /// The plants that droop: thirsty, and not yet seen to.
    public var thirstyPlants: Set<Plant> = []

    /// The body Pix walks in: with the mug held out in front while it carries it.
    public var walkBody: String { mugAway ? "walkmug" : "walk" }
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
        /// Back from being Away: the scene opens with Pix at the Pastime's place, doing it for a beat before the Greeting.
        case pastime(Pastime)
        /// The Stroll: walk to an end of the window.
        case stroll(to: WindowEnd, RestLook)
        /// The Stroll: stop at an end of the window: a beat, a look around, then the end's body (a stretch), or, with
        /// none, standing a while. Finished when the view is done.
        case stop(at: WindowEnd, body: String?, RestLook)
        /// Mid-Stroll Look update: face and particles change without interrupting motion.
        case relook(RestLook)

        public static func idle(_ spot: Spot, _ mood: Mood) -> Step {
            .idle(spot, RestLook(spot: spot, mood: mood))
        }
        public static func stroll(to end: WindowEnd, _ mood: Mood = .content) -> Step {
            .stroll(to: end, RestLook(spot: .window, mood: mood))
        }
        public static func stop(at end: WindowEnd, body: String?, _ mood: Mood = .content) -> Step {
            .stop(at: end, body: body, RestLook(spot: .window, mood: mood))
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
    /// Moments that arrived while Pix was found at a Pastime: they play after the Greeting, in order.
    private var afterGreeting: [Moment] = []
    private var needleDown = false
    private var lamp: Bool?  // nil until the scene first starts, when it takes the hour's state
    /// The end of the window the Stroll heads for next.
    private var heading = WindowEnd.left
    /// A Fidget fell due mid-walk: it plays when Pix reaches the end.
    private var fidgetHeld = false
    /// When the next Fidget falls due: set by an idle or settling at the window, kept by the Stroll's steps, cleared by anything else.
    private var fidgetDue: Date?
    /// Sips left in the mug: it starts empty at launch, so the first desk Fidget is the refill.
    private var sipsLeft = 0
    /// Pix has the mug in hand: from setting off on the refill until it's idle again (or leaves for another Spot).
    private var carryingMug = false
    /// The Fidget Pix played last, so it doesn't play it twice in a row.
    private var lastFidget: Fidget?
    /// Which plants are thirsty: Pix's Care answers it.
    public private(set) var garden: Garden
    /// Dice for how long a watered plant stays watered, apart from `random` so Fidgets don't depend on them.
    private let thirstRandom: () -> Double

    /// Where Pix was last seen: the scene starts with Pix there, and it walks into view if the Spot changed.
    public private(set) var lastSpot: Spot?

    /// What the Props show at `time`: steam follows the hour, so ask again when it changes.
    public func props(at time: Date) -> Props {
        Props(lampLit: lamp == true, mugAway: carryingMug, mugSteams: sipsLeft > 0 && coffeeHours(at: time),
              thirstyPlants: Set(garden.thirsty(at: time)))
    }

    /// When the view should send `wake` (nil: no need).
    public var nextWake: Date? { fidgetDue }

    /// `random` and `thirstRandom` return a number in 0..<1; tests pass fixed ones. `garden` is what Pix kept of the
    /// plants' thirst from the last launch.
    public init(timeZone: TimeZone, random: @escaping () -> Double = { Double.random(in: 0..<1) }, garden: Garden = Garden(),
                thirstRandom: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.random = random
        self.garden = garden
        self.thirstRandom = thirstRandom
    }

    @discardableResult
    public mutating func handle(_ event: Event, at time: Date) -> Step? {
        switch event {
        case .sceneStarted(let room):
            self.room = room
            running = true
            if lamp == nil { lamp = lampWanted(at: time) }
            garden.adopt(Self.plants, at: time, random: thirstRandom)
            let from = lastSpot ?? room.spot
            (place, lastSpot) = (.spot(from), room.spot)
            heading = .left
            if case .greeting(_, let pastime?)? = waiting { return start(.pastime(pastime)) }  // the Greeting follows it
            return from == room.spot ? settle(at: time) : walk(to: room.spot)

        case .sceneStopped:
            (running, current, waiting, afterGreeting) = (false, nil, nil, [])
            (heading, fidgetHeld, fidgetDue) = (.left, false, nil)
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
                    fidgetDue = nextFidgetDue(for: new, at: time)
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
            if case .pastime = current { afterGreeting.append(moment); return nil }  // the Greeting comes first
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
                if case .waterPlant(let plant, _) = errand { garden.watered(plant, at: time, random: thirstRandom) }
                if room?.spot == .window { return nextStrollStep() }  // at the window, on from the Prop is part of the Stroll
                return start(.walkBack(to: room?.spot ?? .desk))
            case .stroll(let end, _):
                heading = end.other
                let held = fidgetHeld
                fidgetHeld = false  // played now or never: it must not wait for a later walk
                if held, let fidget = fidget(at: time) { return fidget }  // in place of the stop
                return start(.stop(at: end, body: end.stopBody, restLook()))
            case .stop:
                return nextStrollStep()
            case .pastime(let pastime):
                let carried = room?.spot == .desk  // the filled mug goes along only to the desk; elsewhere it is set down there
                place = pastime == .coffee && carried ? .prop : .spot(pastime.spot)
                if pastime == .coffee { (sipsLeft, carryingMug) = (Self.mugSips, carried) }
            case .idle, .moment, .fidget, .dropNeedle, .relook:
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

            case .stop:
                if fidgetTime, let fidget = fidget(at: time) { return fidget }
                return nil

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
        case .stroll, .stop: true
        default: false
        }
    }

    private func restLook() -> RestLook {
        guard let room else { return RestLook(spot: .window, mood: .content) }
        return RestLook(spot: room.spot, mood: room.mood, agentWorking: room.agentWorking, hot: room.hot)
    }

    /// What Pix does when nothing else is going on: a waiting Moment, the lamp, the walk from a Pastime, the way home,
    /// the needle, or rest.
    private mutating func settle(at time: Date) -> Step? {
        guard let room else { return nil }
        if let moment = waiting {
            waiting = nil
            return start(.moment(moment))
        }
        if !afterGreeting.isEmpty { return start(.moment(afterGreeting.removeFirst())) }
        if lampNeedsSwitching(at: time) { return start(.errand(.switchLamp)) }
        // Back from a Pastime at another Spot: the walk between Spots, which scrolls the Room to another strip.
        if case .spot(let from)? = place, Art.spot(from) != Art.spot(room.spot) { return walk(to: room.spot) }
        // A Moment cut an Errand short: walk back first. At the window, anywhere is part of the stroll.
        if room.spot != .window && place != .spot(room.spot) { return start(.walkBack(to: room.spot)) }
        if room.spot == .musicCorner && !needleDown {  // part of arriving, not a Moment
            needleDown = true
            return start(.dropNeedle)
        }
        fidgetDue = nextFidgetDue(for: room, at: time)
        if room.spot == .window {
            return nextStrollStep()
        }
        return start(.idle(room.spot, restLook()))
    }

    private mutating func walk(to spot: Spot) -> Step {
        (needleDown, heading) = (false, .left)  // arriving at the window, the Stroll starts left
        return start(.walk(to: spot))
    }

    /// The Stroll's next walk.
    private mutating func nextStrollStep() -> Step { start(.stroll(to: heading, restLook())) }

    /// When the next Fidget falls due 30 to 90 seconds on; none while focused, or when none fit where Pix is.
    private func nextFidgetDue(for room: Room, at time: Date) -> Date? {
        room.mood == .focused || Self.fidgets(for: room, sipsLeft: sipsLeft, coffee: coffeeHours(at: time)).isEmpty ? nil : time + 30 + random() * 60
    }

    /// A Fidget that fits where Pix is and how it feels, if any.
    private mutating func fidget(at time: Date) -> Step? {
        guard let room, room.mood != .focused else { return nil }
        if let care = plantToWater(at: time) { return start(.errand(care)) }
        let all = Self.fidgets(for: room, sipsLeft: sipsLeft, coffee: coffeeHours(at: time))
        guard !all.isEmpty else { return nil }
        let fresh = all.filter { $0 != lastFidget }
        let choices = fresh.isEmpty ? all : fresh  // a Spot with one Fidget plays it every time
        let choice = choices[min(Int(random() * Double(choices.count)), choices.count - 1)]
        lastFidget = choice
        switch choice {
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
        case .stroll, .stop:
            // The Fidget deadline carries on
            break
        case .idle:
            fidgetHeld = false
        default:
            fidgetHeld = false
            fidgetDue = nil
        }
        switch step {
        case .walk, .errand, .walkBack, .pastime: place = .onTheWay  // until it finishes
        default: break
        }
        if case .moment = step { lastFidget = nil }  // a cut-short Errand may be tried again at once
        if case .walk = step { lastFidget = nil; carryingMug = false }
        if case .idle = step { carryingMug = false }
        if case .errand(.refillMug) = step { carryingMug = true }
        if case .pastime(.coffee) = step { carryingMug = true }
        return step
    }

    /// The Fidgets that fit where Pix is and how it feels.
    static func fidgets(for room: Room, sipsLeft: Int, coffee: Bool) -> [Fidget] {
        if room.mood == .sleepy { return room.spot == .couch || room.spot == .call ? [] : [.nod] }  // asleep on the couch, awake on a call: none
        return switch room.spot {
        case .desk: (coffee ? [sipsLeft > 0 ? .sip : .refill] : []) + [.stretch, .lookaround]
        case .call: [.nod]
        case .couch: [.popcorn]
        case .musicCorner: [.spin]
        case .window: [.gaze, .wave, .scratch]
        }
    }

    private static let plants = Art.plantProps.map(Plant.init)

    /// Where Pix stands now, along its strip: at an end of the window mid-Stroll, otherwise at its Spot.
    private var restX: Int {
        switch current {
        case .stroll(let end, _)?, .stop(let end, _, _)?: end == .left ? Art.wanderFrom : Art.wanderTo
        default: room.map { Art.spot($0.spot).x } ?? 0
        }
    }

    /// Care: the thirsty plant Pix sees to next, if it is free to leave. Only plants on its own strip, nearest first,
    /// and only from the desk or the window, not while sleepy.
    private func plantToWater(at time: Date) -> Errand? {
        guard let room, room.mood != .sleepy, room.spot == .desk || room.spot == .window else { return nil }
        let strip = Art.spot(room.spot).strip, here = restX
        func distance(_ plant: Plant) -> Int { abs(plant.middle - here) }
        let plant = garden.thirsty(at: time).filter { $0.strip == strip }.min { distance($0) < distance($1) }
        return plant.map { .waterPlant($0, fromRight: here > $0.middle) }
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
