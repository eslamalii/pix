import Foundation

public enum Activity: String, Sendable, CaseIterable { case coding, browsing, watching, music, meeting, other }

extension Spot {
    init(for activity: Activity) {
        self = switch activity {
        case .coding: .desk
        case .meeting: .call
        case .watching: .couch
        case .music: .musicCorner
        case .browsing, .other: .window
        }
    }
}

public enum Mood: String, Sendable, CaseIterable { case content, focused, sleepy, cheerful, grumpy }

public struct Power: Equatable, Sendable {
    public var onBattery: Bool
    public var lowPowerMode: Bool
    /// The battery's charge in percent; nil when it isn't known.
    public var level: Int?
    public init(onBattery: Bool, lowPowerMode: Bool, level: Int? = nil) {
        self.onBattery = onBattery
        self.lowPowerMode = lowPowerMode
        self.level = level
    }

    /// Running low on battery: Pix runs low with it.
    var low: Bool { onBattery && (level ?? 100) <= Rules.lowBattery }

    /// Frames per second: pixel art needs no more than 12, and less power means fewer. A low battery gets the
    /// fewest, like Low Power Mode: Pix rests to save it.
    public var fps: Int { lowPowerMode || low ? 6 : onBattery ? 10 : 12 }
}

public enum Reaction: String, Sendable, CaseIterable { case wave, jump, shh, yawn, huff, dizzy, pet }

public enum Break: String, Sendable, CaseIterable { case coffee, stretch }

/// How Pix says hi, depending on its Mood: hello (❗), cheerful (♥) or sleepy (💤); or, on the day's first arrival,
/// for an Occasion, or from its Memory: back after days away, early, or the weekend.
public enum Greeting: String, Sendable, CaseIterable { case hello, cheerful, sleepy, missedYou, early, weekend, halloween, holidays, newYear }

/// Something Pix does once, on top of idling.
public enum Moment: Equatable, Sendable {
    case reaction(Reaction)
    case pause(Break)
    case greeting(Greeting)
    /// The charger went in: Pix perks up.
    case charging
    /// A Focus session began, or ran its full length.
    case focusStarted, focusDone
    /// An Agent needs the user, finished its work, or its turn failed.
    case agentAsks, agentDone, agentFailed
    /// Pix just earned a hat (and the app puts it on).
    case newHat
    /// The Mac started running hot.
    case overheated
}

/// What the Touch Bar shows of the Room.
public struct Room: Equatable, Sendable {
    public var spot: Spot
    public var activity: Activity
    public var mood: Mood
    public var fps: Int
    /// The user's AI agent is at work: Pix types along at the desk, twice as fast.
    public var agentWorking: Bool
    /// The Mac is running hot: Pix steams.
    public var hot: Bool
    public init(spot: Spot, activity: Activity, mood: Mood, fps: Int, agentWorking: Bool = false, hot: Bool = false) {
        (self.spot, self.activity, self.mood, self.fps, self.agentWorking, self.hot) = (spot, activity, mood, fps, agentWorking, hot)
    }
}

/// What an Agent (one conversation with the user's AI coding agent: Claude Code, Codex, Cursor…) is doing, as its hooks
/// tell Pix: `open -g pix://agent/working`, `…/waiting` (it needs the user), `…/done` or `…/failed`. Pix never looks for itself.
public enum AgentState: String, Sendable {
    case working, waiting, done, failed
}

/// One pix://agent link: the state, and the anonymous ID of the Agent that sent it (nil: the nameless Agent).
public struct AgentReport: Equatable, Sendable {
    public var state: AgentState
    public var agent: String?

    public init(state: AgentState, agent: String? = nil) { (self.state, self.agent) = (state, agent) }

    /// A pix://agent/<state>[?session=<id>] link; nil for anything else. Any app can open one, so an ID must be
    /// 1–128 letters, digits, `-`, `_` or `.` (every tool's IDs are UUID-like), or the whole link is ignored.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == "pix", url.host?.lowercased() == "agent", url.pathComponents.count == 2,
              let state = AgentState(rawValue: url.pathComponents[1].lowercased()) else { return nil }
        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "session" }?.value ?? ""
        guard id.count <= 128, id.allSatisfy(Self.idCharacters.contains) else { return nil }
        self.init(state: state, agent: id.isEmpty ? nil : id)
    }

    private static let idCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
}

public enum Bar: Equatable, Sendable {
    case room(Room)
    case defaultBar
}

// Add an app: one line here. Add an activity: a new case, its apps, and a scene.
let apps: [String: Activity] = [
    "com.microsoft.VSCode": .coding,
    "com.apple.dt.Xcode": .coding,
    "com.apple.Terminal": .coding,
    "com.googlecode.iterm2": .coding,
    "dev.warp.Warp-Stable": .coding,
    "dev.zed.Zed": .coding,
    "com.mitchellh.ghostty": .coding,
    "com.todesktop.230313mzl4w4u92": .coding,  // Cursor
    "com.apple.Safari": .browsing,
    "com.google.Chrome": .browsing,
    "company.thebrowser.Browser": .browsing,  // Arc
    "org.mozilla.firefox": .browsing,
    "com.brave.Browser": .browsing,
    "com.microsoft.edgemac": .browsing,
    "com.colliderli.iina": .watching,
    "org.videolan.vlc": .watching,
    "com.apple.QuickTimePlayerX": .watching,
    "com.apple.TV": .watching,
    "com.firecore.infuse": .watching,
    "com.spotify.client": .music,
    "com.apple.Music": .music,
    "com.apple.podcasts": .music,
    "us.zoom.xos": .meeting,
    "com.microsoft.teams2": .meeting,
    "com.microsoft.teams": .meeting,
    "com.apple.FaceTime": .meeting,
    "Cisco-Systems.Spark": .meeting,  // Webex
]

extension Activity {
    /// Pix's own guess at what an app is for, before any override the user chose.
    public init(guessing bundleID: String?) {
        guard let id = bundleID else { self = .other; return }
        self = id.hasPrefix("com.jetbrains.") ? .coding : apps[id] ?? .other
    }
}

/// What the user chose an app is for, in place of Pix's guess ("Treat ‹app› as" in the menu).
public enum Override: Equatable, Sendable {
    case activity(Activity)
    /// Pix steps aside while the app is in front, so the app's own Touch Bar shows.
    case defaultBar

    /// Read back from how it's stored in the settings.
    public init?(stored: String) {
        if stored == "defaultBar" { self = .defaultBar } else if let activity = Activity(rawValue: stored) { self = .activity(activity) } else { return nil }
    }

    /// How it's stored in the settings.
    public var stored: String {
        switch self {
        case .activity(let activity): activity.rawValue
        case .defaultBar: "defaultBar"
        }
    }
}

public enum Event: Sendable {
    /// Sent once, right after the Controller is created.
    case appStarted
    case pixTapped
    case pixPetted
    case tappedElsewhere
    case frontAppChanged(String?)
    /// The user chose what some apps are for (bundle ID → choice), overriding Pix's guess.
    case overridesChanged([String: Override])
    case sparklesTapped
    /// The user chose Hide Pix or Show Pix in the menu.
    case hidePix
    case showPix
    case powerChanged(Power)
    case screenSlept
    case screenWoke
    case locked
    case unlocked
    /// Sent once a minute so time alone can change the Mood.
    case clockTick
    /// The user chose Focus with Pix, or stopped it early, in the menu.
    case startFocus
    case stopFocus
    /// The user chose Forget Pix's Memory.
    case forgetMemory
    /// An Agent said what it's doing; `agent` is its anonymous ID (nil: the nameless Agent).
    case agent(AgentState, agent: String? = nil)
    /// macOS says the Mac is running hot (serious or critical), or has cooled down.
    case thermalChanged(hot: Bool)
}

/// Time spent in one Activity. Short trips away pause it; long ones end it.
struct Session {
    private var banked: TimeInterval = 0
    private var activeSince: Date?
    private var leftAt: Date?
    private var breaksTaken = 0

    init(startingAt time: Date) { activeSince = time }

    /// The Break due at a new 45-minute mark, if one was just reached: coffee first, then stretch, alternating.
    mutating func dueBreak(at now: Date) -> Break? {
        let marks = Int(length(at: now) / Rules.breakEvery)
        guard marks > breaksTaken else { return nil }
        breaksTaken = marks
        return marks.isMultiple(of: 2) ? .stretch : .coffee
    }

    func length(at now: Date) -> TimeInterval { banked + (activeSince.map { now.timeIntervalSince($0) } ?? 0) }

    mutating func leave(at time: Date) {
        guard let since = activeSince else { return }
        banked += time.timeIntervalSince(since)
        (activeSince, leftAt) = (nil, time)
    }

    /// Picks the Session back up after a short trip, or starts over after a long one.
    mutating func resume(at time: Date) {
        guard activeSince == nil else { return }
        if let leftAt, time.timeIntervalSince(leftAt) >= Rules.sessionBreaksAfter { (banked, breaksTaken) = (0, 0) }
        (activeSince, leftAt) = (time, nil)
    }
}

/// The numbers behind Pix's personality, in one place so they're easy to tune.
enum Rules {
    static let sleepyFrom = 23, sleepyUntil = 5  // hours, local time
    static let cheerfulFrom = 6, cheerfulUntil = 10
    static let focusAfter: TimeInterval = 45 * 60
    static let breakEvery: TimeInterval = 45 * 60
    static let sessionBreaksAfter: TimeInterval = 5 * 60  // away this long starts a Session over…
    static let longAway = sessionBreaksAfter               // …and earns a Greeting on return
    static let grumpySwitches = 6, grumpyWindow: TimeInterval = 2 * 60  // this many app switches within the window…
    static let grumpyApps = 3                                           // …across at least this many different apps…
    static let grumpyCalmsAfter: TimeInterval = 2 * 60                  // …until this long after switching was last scattered
    static let dizzyTaps = 5, dizzyWindow: TimeInterval = 3
    static let cheerfulAfterPet: TimeInterval = 10 * 60
    static let lowBattery = 20  // percent, on battery: Pix is sleepy
    static let agentQuietAfter: TimeInterval = 10 * 60  // an Agent silent this long has stopped, done or not
}

public struct Controller {
    private let selfBundleID: String
    public private(set) var activity: Activity
    /// The app in front, as far as Pix knows (never Pix itself once another app has been in front).
    public private(set) var frontApp: String?
    private var overrides: [String: Override]
    /// ✨ was tapped in an app Pix steps aside for: Pix shows until another app comes to the front.
    private var showingAnyway = false
    public private(set) var power: Power
    private var animating = true
    /// The user hid Pix; only Show Pix or ✨ brings it back.
    public private(set) var hidden: Bool
    private var asleep = false
    private var isLocked = false
    private var now: Date
    private var sessions: [Activity: Session] = [:]
    private var recentSwitches: [(time: Date, app: String?)] = []
    private var lastScattered: Date?  // the last switch that made the recent switching scattered
    private var recentTaps: [Date] = []
    private var lastPet: Date?
    private var awaySince: Date?
    /// When the Focus session ends, while there is one.
    private var focusUntil: Date?
    /// A hat was earned alongside a Greeting, or on the Default bar, and its NEW HAT is still to play.
    private var newHatOwed = false
    /// When each working Agent last said so, by its ID (nil: the nameless Agent). In memory only, never in the Memory.
    private var workingAgents: [String?: Date] = [:]
    /// The Mac is running hot.
    private var hot = false
    /// What Pix remembers of the user's days; the app keeps it between launches.
    public private(set) var memory: Memory
    private let calendar: Calendar

    /// How long a Focus session lasts.
    public static let focusLength: TimeInterval = 25 * 60

    /// What the Touch Bar shows: the Room, or the Default bar.
    public var bar: Bar { !hidden && animating && !asleep && !isLocked && !steppingAside ? .room(room) : .defaultBar }

    /// The app in front is one the user gave its own Touch Bar.
    private var steppingAside: Bool { !showingAnyway && frontApp.flatMap { overrides[$0] } == .defaultBar }

    /// The Room as Pix lives in it right now, whether or not it's on screen.
    public var room: Room {
        // Focusing, or with the user's agent at work, Pix works at the desk whatever's in front, unless a call takes it.
        let atDesk = (focusUntil != nil || !workingAgents.isEmpty) && activity != .meeting
        // Hot, Pix slows to the fewest frames, to help the Mac cool down.
        return Room(spot: atDesk ? .desk : Spot(for: activity), activity: activity, mood: mood, fps: hot ? min(6, power.fps) : power.fps,
                    agentWorking: !workingAgents.isEmpty, hot: hot)
    }

    /// Whole minutes left in the Focus session (rounded up), or nil when there's none.
    public func focusMinutesLeft(at time: Date) -> Int? {
        focusUntil.map { max(1, Int((($0.timeIntervalSince(time)) / 60).rounded(.up))) }
    }

    private var mood: Mood {
        let hour = calendar.component(.hour, from: now)
        if hot { return .grumpy }  // until the Mac cools down
        if let lastScattered, now.timeIntervalSince(lastScattered) < Rules.grumpyCalmsAfter { return .grumpy }
        if focusUntil != nil { return .focused }
        if hour >= Rules.sleepyFrom || hour < Rules.sleepyUntil || power.low { return .sleepy }
        if activity == .coding, let coding = sessions[.coding], coding.length(at: now) >= Rules.focusAfter { return .focused }
        if hour >= Rules.cheerfulFrom && hour < Rules.cheerfulUntil { return .cheerful }
        if let lastPet, now.timeIntervalSince(lastPet) < Rules.cheerfulAfterPet { return .cheerful }
        return .content
    }

    public init(selfBundleID: String, frontApp: String?, power: Power, at time: Date, timeZone: TimeZone, hidden: Bool = false,
                overrides: [String: Override] = [:], memory: Memory = Memory()) {
        self.selfBundleID = selfBundleID
        self.hidden = hidden
        self.frontApp = frontApp
        self.overrides = overrides
        self.memory = memory
        now = time
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = .current  // the user's region decides which days are the weekend
        self.calendar = calendar
        activity = Self.activity(for: frontApp, overrides: overrides)
        self.power = power
        sessions[activity] = Session(startingAt: time)
    }

    /// Pix's hello: on the day's first arrival maybe a special one from its Memory, otherwise in its Mood.
    /// The arrival is remembered either way, but nobody sees a Greeting on the Default bar, so there's none then.
    private mutating func greeting(at time: Date) -> Moment? {
        let firstToday = memory.days.last != Memory.day(time, in: calendar)
        let occasion = Occasion(on: time, calendar: calendar).map(\.greeting)
        let special = firstToday ? occasion ?? memory.specialGreeting(at: time, calendar: calendar) : nil
        memory.arrived(at: time, calendar: calendar)
        guard case .room = bar else { return nil }
        if let special, special != .cheerful || mood != .sleepy { return .greeting(special) }
        return switch mood {
        case .cheerful: .greeting(.cheerful)
        case .sleepy: .greeting(.sleepy)
        case .content, .focused, .grumpy: .greeting(.hello)
        }
    }

    /// Records taps on Pix; true once there are enough within the dizzy window.
    private mutating func poke(times: Int, at time: Date) -> Bool {
        recentTaps = recentTaps.filter { time.timeIntervalSince($0) <= Rules.dizzyWindow } + Array(repeating: time, count: times)
        return recentTaps.count >= Rules.dizzyTaps
    }

    @discardableResult
    public mutating func handle(_ event: Event, at time: Date) -> Moment? {
        let hatsBefore = Hat.earned(by: memory).count
        let moment = react(to: event, at: time)
        let earned = Hat.earned(by: memory).count > hatsBefore
        if earned { newHatOwed = true }
        guard newHatOwed, case .room = bar else { return moment }  // nobody sees it on the Default bar: it waits
        switch moment {
        case .greeting?: return moment  // the Greeting first; NEW HAT follows on the next quiet event
        case .some where !earned: return moment  // a NEW HAT owed from before waits for an event with no Moment of its own
        default:
            // A hat is rare: earning one is the Moment, whatever else was about to play.
            newHatOwed = false
            return .newHat
        }
    }

    private mutating func react(to event: Event, at time: Date) -> Moment? {
        now = time
        let wasAway = isAway
        let moment = apply(event, at: time, wasAway: wasAway)
        // Asleep or locked is time away: it pauses the Session, and a long absence earns a Greeting on return.
        if isAway && !wasAway {
            sessions[activity]?.leave(at: time)
            awaySince = time
        }
        if !isAway && wasAway, let since = awaySince {
            sessions[activity]?.resume(at: time)
            awaySince = nil
            if time.timeIntervalSince(since) >= Rules.longAway { return greeting(at: time) }
        }
        // The user doing something counts as being here today, Greeting or not (say, working past midnight).
        switch event {
        case .frontAppChanged, .pixTapped, .pixPetted, .tappedElsewhere, .sparklesTapped, .startFocus:
            if !isAway { memory.saw(at: time, calendar: calendar) }
        default: break
        }
        return moment
    }

    private var isAway: Bool { asleep || isLocked }

    /// What an app is for: the Activity the user chose, or else Pix's guess (also for an app Pix steps aside for).
    private static func activity(for bundleID: String?, overrides: [String: Override]) -> Activity {
        if let id = bundleID, case .activity(let chosen) = overrides[id] { return chosen }
        return Activity(guessing: bundleID)
    }

    /// Moves to another Activity, pausing the old one's Session and picking up (or starting) the new one's.
    private mutating func switchActivity(to next: Activity, at time: Date, wasAway: Bool) {
        guard next != activity else { return }
        sessions[activity]?.leave(at: time)
        if sessions[next] == nil { sessions[next] = Session(startingAt: time) } else { sessions[next]?.resume(at: time) }
        if wasAway { sessions[next]?.leave(at: time) }  // nobody's there yet; the clock starts on wake
        activity = next
    }

    private mutating func apply(_ event: Event, at time: Date, wasAway: Bool) -> Moment? {
        switch event {
        case .appStarted:
            return greeting(at: time)
        case .pixTapped:
            if poke(times: 1, at: time) { return .reaction(.dizzy) }
            if activity == .meeting { return .reaction(.shh) }  // Pix is on a call
            switch mood {
            case .content: return .reaction(.wave)
            case .cheerful: return .reaction(.jump)
            case .focused: return .reaction(.shh)
            case .sleepy: return .reaction(.yawn)
            case .grumpy: return .reaction(.huff)
            }
        case .pixPetted:
            if poke(times: 2, at: time) { return .reaction(.dizzy) }  // a Pet is two quick taps
            lastPet = time
            memory.petted(at: time, calendar: calendar)
            lastScattered = nil  // a Pet makes up with a grumpy Pix, and forgives the switching that did it
            recentSwitches = []
            return .reaction(.pet)
        case .tappedElsewhere: animating = false
        case .frontAppChanged(let bundleID):
            guard bundleID != selfBundleID else { return nil }
            recentSwitches = recentSwitches.filter { time.timeIntervalSince($0.time) <= Rules.grumpyWindow } + [(time, bundleID)]
            // Scattered, not busy: ping-ponging between two apps is normal work.
            let apps = Set(recentSwitches.compactMap(\.app))
            if recentSwitches.count >= Rules.grumpySwitches && apps.count >= Rules.grumpyApps { lastScattered = time }
            frontApp = bundleID
            switchActivity(to: Self.activity(for: bundleID, overrides: overrides), at: time, wasAway: wasAway)
            (animating, showingAnyway) = (true, false)
        case .overridesChanged(let new):
            (overrides, showingAnyway) = (new, false)  // not a switch: it doesn't count toward grumpy
            switchActivity(to: Self.activity(for: frontApp, overrides: overrides), at: time, wasAway: wasAway)
        case .sparklesTapped: (hidden, animating, showingAnyway) = (false, true, true)
        case .showPix: (hidden, animating) = (false, true)
        case .hidePix: hidden = true
        case .powerChanged(let newPower):
            let pluggedIn = power.onBattery && !newPower.onBattery
            power = newPower
            if pluggedIn, case .room = bar { return .charging }  // nobody sees it on the Default bar
        case .screenSlept: asleep = true
        case .screenWoke: asleep = false
        case .locked: isLocked = true
        case .unlocked: isLocked = false
        case .clockTick:
            workingAgents = workingAgents.filter { time.timeIntervalSince($0.value) < Rules.agentQuietAfter }
            if let until = focusUntil, time >= until {
                focusUntil = nil
                memory.finishedFocus()
                if case .room = bar { return .focusDone }  // nobody sees it on the Default bar
                return nil
            }
            // No Break during Focus: the Session keeps counting, and a due one comes after.
            if activity == .coding, focusUntil == nil, let pause = sessions[.coding]?.dueBreak(at: time) { return .pause(pause) }
        case .startFocus:
            focusUntil = time + Self.focusLength
            if case .room = bar { return .focusStarted }
        case .stopFocus:
            focusUntil = nil
        case .forgetMemory:
            memory = Memory()
            newHatOwed = false
        case .thermalChanged(let nowHot):
            let heated = nowHot && !hot
            hot = nowHot
            if heated, case .room = bar { return .overheated }
        case .agent(let state, let agent):
            workingAgents[agent] = state == .working ? time : nil
            guard case .room = bar else { return nil }  // nobody would see it
            switch state {
            case .working: return nil
            case .waiting: return .agentAsks
            case .done: return .agentDone
            case .failed: return .agentFailed
            }
        }
        return nil
    }
}
