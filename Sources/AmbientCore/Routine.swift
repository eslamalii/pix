import Foundation


/// A trip to a Prop, as a Fidget, as Care, or at a time of day: Pix walks to it, uses it, and walks back to its Spot.
public enum Errand: Equatable, Sendable {
    case switchLamp
    /// A thirsty plant.
    case waterPlant(Plant)
    /// The coffee machine by the desk: Pix takes its mug there and fills it.
    case refillMug
    /// A day's Occasion Prop on a Perch: Pix walks over to it, waves at it, and walks back.
    case admireOccasionProp(perch: Int)

    /// The body Pix plays at the Prop.
    public var body: String {
        switch self {
        case .switchLamp: "switch"
        case .waterPlant: "water"
        case .refillMug: "pour"
        case .admireOccasionProp: "wave"
        }
    }
}

/// Something Pix does now and then while idling: plays the body sheet named by its raw value, or, for refill and admire,
/// runs an Errand. Celebrate is for an Occasion's day, with the Occasion's Emote.
public enum Fidget: String, CaseIterable, Sendable {
    case sip, stretch, lookaround, nod, popcorn, spin, gaze, wave, scratch, refill, celebrate, admire
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
    /// Steam rises from the mug on the desk: it has coffee in it, it's coffee hours (a mug left over in the evening goes
    /// cold), and Pix rests beside it.
    public var mugSteams: Bool
    /// The plants that droop: thirsty, and not yet seen to.
    public var thirstyPlants: Set<Plant> = []
    /// Today's Occasion, if it is one.
    public var occasion: Occasion?
    /// How many of the Occasion's four Props stand in the Room: none until the tour starts, one more as Pix places each,
    /// and all four once it has.
    public var occasionPropsShown = 0

    /// The body Pix walks in: with the mug held out in front while it carries it.
    public var walkBody: String { mugAway ? "walkmug" : "walk" }
}

/// What Pix does next with its body in the Room. The view tells it what happened and performs the step it asks for;
/// it decides in Spots, Props and the art contract's positions along a strip, never in screen points.
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
        /// The Look at the Spot changes (face, particles, body) without interrupting the idle or the Stroll.
        case relook(Spot, RestLook)
        /// The Occasion tour: walk to a Perch (0..<4) from wherever Pix is.
        case tourWalk(perch: Int)
        /// The Occasion tour: at the Perch, switch the Occasion Prop on; it shows.
        case placeOccasionProp(perch: Int)

        public static func idle(_ spot: Spot, _ mood: Mood) -> Step {
            .idle(spot, RestLook(spot: spot, mood: mood))
        }
        public static func stroll(to end: WindowEnd, _ mood: Mood = .content) -> Step {
            .stroll(to: end, RestLook(spot: .window, mood: mood))
        }
        public static func stop(at end: WindowEnd, body: String?, _ mood: Mood = .content) -> Step {
            .stop(at: end, body: body, RestLook(spot: .window, mood: mood))
        }
        public static func relook(_ mood: Mood, at spot: Spot = .window) -> Step {
            .relook(spot, RestLook(spot: spot, mood: mood))
        }
    }

    /// Where Pix is, as far as the Routine knows.
    private enum Place: Equatable {
        case spot(Spot)
        case prop
        /// A walk was replaced before it finished.
        case onTheWay
    }

    private var calendar: Calendar
    private let random: () -> Double
    private var room: Room?
    private var running = false
    private var current: Step?
    private var place: Place?
    private var waiting = WaitingMoments()
    private var needleDown = false
    private var lamp = Lamp()
    /// The end of the window the Stroll heads for next.
    private var heading = WindowEnd.left
    private var fidgetClock: FidgetClock
    /// Empty at launch, so the first desk Fidget is the refill.
    private var mug = Mug()
    /// The Fidget Pix played last, so it doesn't play it twice in a row.
    private var lastFidget: Fidget?
    /// How many Occasion Props Pix has placed. A day restored from `saved` counts as all placed, which `props` shows only if that day is today.
    private var occasionPropsPlaced = 0
    /// What the Routine keeps between launches.
    public struct Saved: Equatable, Sendable {
        /// Which plants are thirsty: Pix's Care answers it.
        public var garden: Garden
        /// The day (in the Routine's calendar, "yyyy-MM-dd") Pix started its Occasion tour.
        public var occasionPropsPlacedOn: String?
        public init(garden: Garden = Garden(), occasionPropsPlacedOn: String? = nil) {
            (self.garden, self.occasionPropsPlacedOn) = (garden, occasionPropsPlacedOn)
        }
    }
    public private(set) var saved: Saved
    /// Dice for how long a watered plant stays watered, apart from `random` so Fidgets don't depend on them.
    private let thirstRandom: () -> Double

    /// Where Pix was last seen: the scene starts with Pix there, and it walks into view if the Spot changed.
    public private(set) var lastSpot: Spot?

    /// What the Props show at `time`: steam follows the hour, so ask again when it changes.
    public func props(at time: Date) -> Props {
        let resting: Bool
        if case .idle(.desk, _)? = current { resting = true } else { resting = false }
        let occasion = Occasion(on: time, calendar: calendar)
        // A tour running past midnight keeps showing what it has placed while the new day is still an Occasion.
        let shown = occasion != nil && (isTouring || saved.occasionPropsPlacedOn == day(of: time)) ? occasionPropsPlaced : 0
        return Props(lampLit: lamp.lit, mugAway: mug.inHand, mugSteams: resting && mug.hot(atHour: hour(of: time)),
                     thirstyPlants: Set(saved.garden.thirsty(at: time)), occasion: occasion, occasionPropsShown: shown)
    }

    /// When the view should send `wake` (nil: no need).
    public var nextWake: Date? { fidgetClock.due }

    /// `random` and `thirstRandom` return a number in 0..<1; tests pass fixed ones. `saved` is what Pix kept from the last launch.
    public init(timeZone: TimeZone, random: @escaping () -> Double = { Double.random(in: 0..<1) }, saved: Saved = Saved(),
                thirstRandom: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.random = random
        fidgetClock = FidgetClock(random: random)
        self.saved = saved
        occasionPropsPlaced = saved.occasionPropsPlacedOn == nil ? 0 : Art.perches.count
        self.thirstRandom = thirstRandom
    }

    @discardableResult
    public mutating func handle(_ event: Event, at time: Date) -> Step? {
        switch event {
        case .sceneStarted(let room):
            self.room = room
            running = true
            lamp.found(atHour: hour(of: time))
            saved.garden.adopt(Self.plants, at: time, random: thirstRandom)
            let from = lastSpot ?? room.spot
            (place, lastSpot) = (.spot(from), room.spot)
            heading = .left
            if let pastime = waiting.pastime { return start(.pastime(pastime)) }  // the Greeting follows it
            return from == room.spot ? settle(at: time) : walk(to: room.spot)

        case .sceneStopped:
            if isTouring { occasionPropsPlaced = Art.perches.count }  // a rebuild draws the day's Props whole
            (running, current) = (false, nil)
            waiting.drop()
            heading = .left
            fidgetClock.stop()
            return nil

        case .roomChanged(let new):
            let old = room
            room = new
            guard running else { return nil }
            if new.spot != old?.spot {
                lastSpot = new.spot
                if isTouring { return nil }  // Pix finishes the tour, then settling takes it to the new Spot
                // Two Spots in one place (the desk and the call): Pix stays put and settles into the new one.
                if let old, Art.spot(old.spot) == Art.spot(new.spot), place == .spot(old.spot) {
                    place = .spot(new.spot)
                    if case .idle = current { return settle(at: time) }
                    return nil
                }
                return walk(to: new.spot)
            }
            // Anything else Pix is doing ends in settling, which takes the new Room.
            guard isResting, let old else { return nil }
            if tourDue(at: time) { return startTour(at: time) }
            // A new Mood changes which Fidgets fit; running hot or an Agent only changes how Pix looks.
            if new.mood != old.mood { fidgetClock.rest(at: time, fits: fidgetFits(new, at: time)) }
            let look = restLook()
            return look != Self.restLook(in: old) ? .relook(new.spot, look) : nil  // the Activity or frame rate alone changes nothing

        case .momentArrived(let moment):
            if !running || mustFinish {
                waiting.add(moment)
                return nil
            }
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
                if errand == .switchLamp { lamp.switched(atHour: hour(of: time)) }
                if errand == .refillMug { mug.filled(inHand: true) }
                if case .waterPlant(let plant) = errand { saved.garden.watered(plant, at: time, random: thirstRandom) }
                if room?.spot == .window { return nextStrollStep() }  // at the window, on from the Prop is part of the Stroll
                return start(.walkBack(to: room?.spot ?? .desk))
            case .stroll(let end, _):
                heading = end.other
                if fidgetClock.walkEnded(), let fidget = fidget(at: time) { return fidget }  // in place of the stop
                return start(.stop(at: end, body: end.stopBody, restLook()))
            case .stop:
                return nextStrollStep()
            case .pastime(let pastime):
                let carried = room?.spot == .desk  // the filled mug goes along only to the desk; elsewhere it is set down there
                place = pastime == .coffee && carried ? .prop : .spot(pastime.spot)
                if pastime == .coffee { mug.filled(inHand: carried) }
            case .tourWalk(let perch):
                return start(.placeOccasionProp(perch: perch))
            case .placeOccasionProp(let perch):
                occasionPropsPlaced = perch + 1
                if perch + 1 < Art.perches.count { return start(.tourWalk(perch: perch + 1)) }
            case .idle, .moment, .fidget, .dropNeedle, .relook:
                break
            }
            return settle(at: time)

        case .wake:
            guard running, fidgetClock.wake(at: time, during: current) else { return nil }
            return fidget(at: time)

        case .timeZoneChanged(let zone):
            calendar.timeZone = zone
            return nil

        case .minutePassed:
            guard running, isResting else { return nil }
            if tourDue(at: time) { return startTour(at: time) }
            guard case .idle = current, lampNeedsSwitching(at: time) else { return nil }
            return start(.errand(.switchLamp))
        }
    }

    // MARK: - Deciding

    /// Pix is walking to a Spot (a Moment plays on arrival), found at a Pastime or greeting the user (the Greeting
    /// comes first): a Moment waits for it.
    private var mustFinish: Bool {
        switch current {
        case .walk?, .pastime?, .moment(.greeting)?, .tourWalk?, .placeOccasionProp?: true
        case .idle?, .moment?, .fidget?, .errand?, .use?, .walkBack?, .dropNeedle?, .stroll?, .stop?, .relook?, nil: false
        }
    }

    /// Pix is on its Occasion tour: nothing cuts it short.
    private var isTouring: Bool {
        switch current {
        case .tourWalk?, .placeOccasionProp?: true
        case .walk?, .idle?, .moment?, .fidget?, .errand?, .use?, .walkBack?, .dropNeedle?, .pastime?, .stroll?, .stop?, .relook?, nil: false
        }
    }

    /// Today is an Occasion Pix hasn't toured yet, and it's free for it: not in a Focus session or a meeting, whatever the Mood.
    private func tourDue(at time: Date) -> Bool {
        guard let room, Occasion(on: time, calendar: calendar) != nil, saved.occasionPropsPlacedOn != day(of: time) else { return false }
        return !room.focusing && room.activity != .meeting
    }

    private mutating func startTour(at time: Date) -> Step {
        (saved.occasionPropsPlacedOn, occasionPropsPlaced) = (day(of: time), 0)
        return start(.tourWalk(perch: 0))
    }

    /// Idling at a Spot, or on the Stroll.
    private var isResting: Bool {
        switch current {
        case .idle?, .stroll?, .stop?: true
        case .walk?, .moment?, .fidget?, .errand?, .use?, .walkBack?, .dropNeedle?, .pastime?, .relook?, .tourWalk?,
             .placeOccasionProp?, nil: false
        }
    }

    private func restLook() -> RestLook {
        guard let room else { return RestLook(spot: .window, mood: .content) }
        return Self.restLook(in: room)
    }

    private static func restLook(in room: Room) -> RestLook {
        RestLook(spot: room.spot, mood: room.mood, agentWorking: room.agentWorking, hot: room.hot)
    }

    /// What Pix does when nothing else is going on: a waiting Moment, the lamp, the walk from a Pastime, the way home,
    /// the needle, or rest.
    private mutating func settle(at time: Date) -> Step? {
        guard let room else { return nil }
        if let moment = waiting.next() { return start(.moment(moment)) }
        if tourDue(at: time) { return startTour(at: time) }
        if lampNeedsSwitching(at: time) { return start(.errand(.switchLamp)) }
        // Back from a Pastime at another Spot: the walk between Spots, which scrolls the Room to another strip.
        if case .spot(let from)? = place, Art.spot(from) != Art.spot(room.spot) { return walk(to: room.spot) }
        // A Moment cut an Errand short: walk back first. At the window, anywhere is part of the stroll.
        if room.spot != .window && place != .spot(room.spot) { return start(.walkBack(to: room.spot)) }
        if room.spot == .musicCorner && !needleDown {  // part of arriving, not a Moment
            needleDown = true
            return start(.dropNeedle)
        }
        fidgetClock.rest(at: time, fits: fidgetFits(room, at: time))
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

    /// Some Fidget fits where Pix is and how it feels: none while focused.
    private func fidgetFits(_ room: Room, at time: Date) -> Bool {
        room.mood != .focused && !Self.fidgets(for: room, coffee: mug.fidget(atHour: hour(of: time)), festive: festive(at: time)).isEmpty
    }

    /// A Fidget that fits where Pix is and how it feels, if any.
    private mutating func fidget(at time: Date) -> Step? {
        guard let room, room.mood != .focused else { return nil }
        if let care = plantToWater(at: time) { return start(.errand(care)) }
        let all = Self.fidgets(for: room, coffee: mug.fidget(atHour: hour(of: time)), festive: festive(at: time))
        guard !all.isEmpty else { return nil }
        let fresh = all.filter { $0 != lastFidget }
        let choices = fresh.isEmpty ? all : fresh  // a Spot with one Fidget plays it every time
        let choice = pick(choices)
        lastFidget = choice
        switch choice {
        case .refill: return start(.errand(.refillMug))
        case .admire:
            let here = Self.perches(on: Art.spot(room.spot).strip)
            return start(.errand(.admireOccasionProp(perch: pick(here))))
        case .sip:
            mug.sipped()
            return start(.fidget(choice))
        default: return start(.fidget(choice))
        }
    }

    /// One of `xs`, by the Routine's dice.
    private func pick<T>(_ xs: [T]) -> T { xs[min(Int(random() * Double(xs.count)), xs.count - 1)] }

    private mutating func start(_ step: Step) -> Step {
        current = step
        fidgetClock.started(step)
        switch step {
        case .walk, .errand, .walkBack, .pastime, .tourWalk: place = .onTheWay  // until it finishes
        case .placeOccasionProp: place = .prop
        case .idle, .moment, .fidget, .use, .dropNeedle, .stroll, .stop, .relook: break
        }
        if case .moment = step { lastFidget = nil }  // a cut-short Errand may be tried again at once
        if case .walk = step { lastFidget = nil }
        mug.started(step)
        return step
    }

    /// The Fidgets that fit where Pix is and how it feels; `coffee` is the mug's own, offered at the desk. On a `festive`
    /// day (an Occasion whose Props Pix has placed) it also celebrates, spins and, where it is free to leave and a Perch
    /// shares its strip, admires an Occasion Prop; a meeting stays calm, and a focused Pix is left alone.
    static func fidgets(for room: Room, coffee: Fidget?, festive: Bool = false) -> [Fidget] {
        if room.mood == .sleepy { return room.spot == .couch || room.spot == .call ? [] : [.nod] }  // asleep on the couch, awake on a call: none
        let usual: [Fidget] = switch room.spot {
        case .desk: (coffee.map { [$0] } ?? []) + [.stretch, .lookaround]
        case .call: [.nod]
        case .couch: [.popcorn]
        case .musicCorner: [.spin]
        case .window: [.gaze, .wave, .scratch]
        }
        guard festive, room.mood != .focused, room.spot != .call else { return usual }
        let admires: [Fidget] = Self.freeToLeave(room.spot) && !perches(on: Art.spot(room.spot).strip).isEmpty ? [.admire] : []
        return usual + [.celebrate] + (usual.contains(.spin) ? [] : [.spin]) + admires
    }

    /// Pix is free to leave this Spot for an Errand: the desk and the window.
    private static func freeToLeave(_ spot: Spot) -> Bool { spot == .desk || spot == .window }

    /// The Perches (indices into `Art.perches`) on a strip.
    private static func perches(on strip: String) -> [Int] { Art.perches.indices.filter { Art.perches[$0].strip == strip } }

    private static let plants = Art.plantProps.map(Plant.init)

    /// Where Pix stands now, along its strip: at an end of the window mid-Stroll, otherwise at its Spot.
    private var restX: Int {
        switch current {
        case .stroll(let end, _)?, .stop(let end, _, _)?: end == .left ? Art.wanderFrom : Art.wanderTo
        case .walk?, .idle?, .moment?, .fidget?, .errand?, .use?, .walkBack?, .dropNeedle?, .pastime?, .relook?, .tourWalk?,
             .placeOccasionProp?, nil:
            room.map { Art.spot($0.spot).x } ?? 0
        }
    }

    /// Care: the thirsty plant Pix sees to next, if it is free to leave. Only plants on its own strip, nearest first,
    /// and only from the desk or the window, not while sleepy.
    private func plantToWater(at time: Date) -> Errand? {
        guard let room, room.mood != .sleepy, Self.freeToLeave(room.spot) else { return nil }
        return saved.garden.nearestThirsty(on: Art.spot(room.spot).strip, to: restX, at: time).map(Errand.waterPlant)
    }

    /// Today is an Occasion and Pix has placed its Props: it celebrates the day among its usual Fidgets.
    private func festive(at time: Date) -> Bool {
        Occasion(on: time, calendar: calendar) != nil && saved.occasionPropsPlacedOn == day(of: time)
    }

    private func hour(of time: Date) -> Int { calendar.component(.hour, from: time) }

    /// The calendar day in the Routine's own calendar, as "yyyy-MM-dd".
    private func day(of time: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: time)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The lamp isn't as the hour wants it, and Pix is on the desk side to do something about it.
    private func lampNeedsSwitching(at time: Date) -> Bool {
        guard let room, room.spot != .window else { return false }
        return lamp.needsSwitching(atHour: hour(of: time))
    }
}
