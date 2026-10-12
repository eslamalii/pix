import Foundation

/// How a Moment looks: the body Pix plays, an Emote over its head, an extra, and its Caption beside the Clock.
public struct MomentLook: Equatable, Sendable {
    public var body: String
    public var loops: Float
    public var emote: String?
    public var extra: Extra?
    public var caption: Caption

    public init(body: String, loops: Float, emote: String? = nil, extra: Extra? = nil, caption: Caption) {
        (self.body, self.loops, self.emote, self.extra, self.caption) = (body, loops, emote, extra, caption)
    }
}

/// What plays alongside a Moment's body.
public enum Extra: Sendable {
    case hop, hearts, zzz, steam, turnAway
}

/// An Emote and a short word, shown beside the Clock after a Moment.
public struct Caption: Equatable, Sendable {
    public var emote: String
    public var word: String
    public init(emote: String, word: String) { (self.emote, self.word) = (emote, word) }
}

extension Moment {
    public var look: MomentLook {
        switch self {
        case .reaction(.wave): MomentLook(body: "wave", loops: 2, caption: Caption(emote: "star", word: "HI"))
        case .reaction(.jump): MomentLook(body: "jump", loops: 2, extra: .hop, caption: Caption(emote: "exclaim", word: "HOP"))
        case .reaction(.shh): MomentLook(body: "shh", loops: 3, emote: "exclaim", caption: Caption(emote: "exclaim", word: "SHH"))
        case .reaction(.yawn): MomentLook(body: "yawn", loops: 2, extra: .zzz, caption: Caption(emote: "zzz", word: "YAWN"))
        case .reaction(.huff): MomentLook(body: "huff", loops: 3, extra: .turnAway, caption: Caption(emote: "steam", word: "HMPH"))
        case .reaction(.dizzy): MomentLook(body: "dizzy", loops: 4, caption: Caption(emote: "star", word: "DIZZY"))
        case .reaction(.pet): MomentLook(body: "pet", loops: 3, extra: .hearts, caption: Caption(emote: "heart", word: "PET"))
        case .pause(.coffee): MomentLook(body: "coffee", loops: 8, extra: .steam, caption: Caption(emote: "coffee", word: "BREAK"))
        case .pause(.stretch): MomentLook(body: "stretch", loops: 4, caption: Caption(emote: "star", word: "STRETCH"))
        case .greeting(.hello): MomentLook(body: "wave", loops: 2, emote: "exclaim", caption: Caption(emote: "exclaim", word: "HELLO"))
        case .greeting(.cheerful): MomentLook(body: "wave", loops: 2, extra: .hearts, caption: Caption(emote: "heart", word: "HELLO"))
        case .greeting(.sleepy): MomentLook(body: "yawn", loops: 2, extra: .zzz, caption: Caption(emote: "zzz", word: "HELLO"))
        case .greeting(.missedYou): MomentLook(body: "wave", loops: 3, extra: .hearts, caption: Caption(emote: "heart", word: "BACK"))
        case .greeting(.early): MomentLook(body: "jump", loops: 2, emote: "exclaim", extra: .hop, caption: Caption(emote: "exclaim", word: "EARLY"))
        case .greeting(.halloween): MomentLook(body: "jump", loops: 2, emote: "pumpkin", extra: .hop, caption: Caption(emote: "pumpkin", word: "BOO"))
        case .greeting(.holidays): MomentLook(body: "wave", loops: 3, extra: .hearts, caption: Caption(emote: "star", word: "HO HO"))
        case .greeting(.newYear): MomentLook(body: "jump", loops: 3, emote: "star", extra: .hop, caption: Caption(emote: "star", word: "CHEERS"))
        case .greeting(.weekend): MomentLook(body: "wave", loops: 2, emote: "star", caption: Caption(emote: "star", word: "WEEKEND"))
        case .focusStarted: MomentLook(body: "type", loops: 2, emote: "exclaim", caption: Caption(emote: "exclaim", word: "FOCUS"))
        case .focusDone: MomentLook(body: "stretch", loops: 4, extra: .hearts, caption: Caption(emote: "star", word: "DONE"))
        case .agentAsks: MomentLook(body: "wave", loops: 3, emote: "exclaim", caption: Caption(emote: "exclaim", word: "ASKING"))
        case .agentDone: MomentLook(body: "jump", loops: 2, emote: "star", extra: .hop, caption: Caption(emote: "star", word: "DONE"))
        case .agentFailed: MomentLook(body: "scratch", loops: 3, emote: "exclaim", caption: Caption(emote: "exclaim", word: "OOPS"))
        case .newHat: MomentLook(body: "jump", loops: 3, emote: "star", extra: .hop, caption: Caption(emote: "star", word: "NEW HAT"))
        case .overheated: MomentLook(body: "huff", loops: 3, emote: "steam", extra: .steam, caption: Caption(emote: "steam", word: "HOT"))
        case .charging: MomentLook(body: "jump", loops: 2, emote: "bolt", extra: .hop, caption: Caption(emote: "bolt", word: "CHARGE"))
        }
    }
}

/// The time of day as the Room's light sees it.
public enum Daylight: Sendable {
    case dawn, day, dusk, night

    public init(hour: Int) {
        self = switch hour {
        case 6..<8: .dawn
        case 8..<17: .day
        case 17..<20: .dusk
        default: .night
        }
    }
}

/// A day of the year Pix celebrates with the day's first Greeting.
public enum Occasion: String, Codable, Sendable {
    case halloween, holidays, newYear

    public init?(month: Int, day: Int) {
        switch (month, day) {
        case (10, 31): self = .halloween
        case (12, 24...26): self = .holidays
        case (1, 1): self = .newYear
        default: return nil
        }
    }

    public init?(on time: Date, calendar: Calendar) {
        self.init(month: calendar.component(.month, from: time), day: calendar.component(.day, from: time))
    }

    public var greeting: Greeting {
        switch self {
        case .halloween: .halloween
        case .holidays: .holidays
        case .newYear: .newYear
        }
    }

    /// Snow drifts past the window in these months.
    public static func snows(inMonth month: Int) -> Bool { month == 12 || month == 1 }
}
