import CoreGraphics

/// The art contract: every file, size and position the drawings and the renderer agree on.
/// Units are art pixels: one art pixel is 2×2 Touch Bar pixels (one point). Origins are top-left, as in a paint program.
/// The art generator (scripts/art) compiles this same file, so the art always matches the contract.
public enum Art {
    public static let height = 30

    // MARK: Room — strips laid out left to right: room-<strip>.png, stripWidth × height

    public static let stripWidth = 1004  // the whole Touch Bar on a 13" M1 (the Control Strip is hidden while Pix shows)
    public static let strips = ["desk", "window"]
    /// Rows from the bottom where Pix's feet rest.
    public static let floor = 3

    // MARK: Spots — the strip each one is on, and Pix's center there. Several Spots can share a strip;
    // the Room scrolls only when Pix walks to another strip.

    public static func spot(_ spot: Spot) -> (strip: String, x: Int) {
        switch spot {
        case .desk: ("desk", seatX)
        case .call: ("desk", seatX)  // the same seat, headset on
        case .couch: ("desk", Int(couch.midX))
        case .musicCorner: ("desk", 804)  // just left of the record cabinet, close enough to reach the turntable
        case .window: ("window", (wanderFrom + wanderTo) / 2)
        }
    }

    // Desk strip
    public static let seatX = 492  // Pix's center while sitting at the desk
    public static let monitors = [CGRect(x: 510, y: 5, width: 26, height: 14), CGRect(x: 542, y: 5, width: 26, height: 14)]
    public static let mug = CGRect(x: 574, y: 15, width: 4, height: 4)
    public static let lamp = CGRect(x: 656, y: 1, width: 14, height: 3)  // the shade; it casts light once Pix switches it on
    public static let couch = CGRect(x: 170, y: 15, width: 44, height: 12)  // stands on the floor
    public static let couchSeat = 4  // rows from the couch's top to the top of its seat cushion
    public static let lampSwitch = 6  // the switch is on the pole, this far into the shade
    public static let plant = CGSize(width: 12, height: 19)
    public static let wateringReach = 14  // Pix holds the can out front: it stands this far from a plant's middle
    public static let coffeeMachine = CGRect(x: 618, y: 8, width: 14, height: 19)  // on the floor, spout on its left
    public static let pourReach = 5  // Pix holds the mug out front: it stands this far left of the machine's edge
    public static let cabinet = CGRect(x: 810, y: 12, width: 40, height: 15)  // the record cabinet, on the floor
    public static let turntable = CGRect(x: 816, y: 15, width: 12, height: 1)  // the record's surface; it spins while music plays

    // Window strip
    public static let windowPane = CGRect(x: 382, y: 3, width: 240, height: 18)  // left transparent: the sky shows through
    public static let wanderFrom = 150, wanderTo = 860  // Pix's center while wandering

    // MARK: Props — every thing standing in the Room, stamped into its strip by the art generator.
    // Draw your own as Art/props/<name>.png: it replaces every Prop of that name, at the same place.

    public struct Prop: Sendable {
        public let name: String
        public let strip: String
        public let x: Int      // left edge, within the strip
        public let y: Int?     // top edge; nil stands the Prop on the floor
    }
    public static let props: [Prop] = [
        Prop(name: "bookcase", strip: "desk", x: 120, y: nil),
        Prop(name: "shelf", strip: "desk", x: 258, y: 3),
        Prop(name: "print", strip: "desk", x: 342, y: 5),
        Prop(name: "plant", strip: "desk", x: 404, y: nil),
        Prop(name: "desk", strip: "desk", x: Int(desk.minX), y: Int(desk.minY)),
        Prop(name: "chair", strip: "desk", x: seatX - 11, y: nil),
        Prop(name: "monitor", strip: "desk", x: Int(monitors[0].minX) - 1, y: Int(monitors[0].minY) - 1),
        Prop(name: "monitor", strip: "desk", x: Int(monitors[1].minX) - 1, y: Int(monitors[1].minY) - 1),
        Prop(name: "keyboard", strip: "desk", x: 548, y: 17),
        Prop(name: "mug", strip: "desk", x: Int(mug.minX), y: Int(mug.minY)),
        Prop(name: "lamp", strip: "desk", x: Int(lamp.minX), y: Int(lamp.minY)),
        Prop(name: "plant", strip: "desk", x: 730, y: nil),
        Prop(name: "coffeemachine", strip: "desk", x: Int(coffeeMachine.minX), y: nil),
        Prop(name: "cabinet", strip: "desk", x: Int(cabinet.minX), y: Int(cabinet.minY)),
        Prop(name: "couch", strip: "desk", x: Int(couch.minX), y: Int(couch.minY)),
        Prop(name: "window", strip: "window", x: Int(windowPane.minX) - 5, y: Int(windowPane.minY) - 2),
        Prop(name: "cactus", strip: "window", x: Int(windowPane.maxX) - 24, y: 16),
        Prop(name: "cushion", strip: "window", x: 260, y: nil),
        Prop(name: "plant", strip: "window", x: 678, y: nil),
        Prop(name: "books", strip: "window", x: 840, y: nil),
    ]
    /// Props that do something. A drawing of one must keep this size (width × height), or the code, steam,
    /// light or sky that goes with it lands in the wrong place.
    public static let workingProps: [String: CGSize] = [
        "desk": desk.size,
        "monitor": CGSize(width: monitors[0].width + 2, height: monitors[0].height + 2),  // the screen plus a 1-pixel bezel
        "mug": mug.size,
        "coffeemachine": coffeeMachine.size,  // Pix holds the mug under the spout, coffee falls from its tip
        "lamp": CGSize(width: lamp.width, height: CGFloat(height - floor) - lamp.minY),  // shade to floor
        "window": CGSize(width: windowPane.width + 10, height: windowPane.height + 6),  // pane, frame and sill
        "couch": couch.size,      // Pix sits on the seat, couchSeat rows down
        "cabinet": cabinet.size,  // the record spins at turntable
        "plant": plant,           // Pix waters it from either side of its middle
    ]
    public static let desk = CGRect(x: 476, y: 19, width: 116, height: 8)  // Pix sits at it; the keyboard and mug stand on it

    // MARK: Pix — body sheets pix-<body>.png: frames of frame × frame side by side, as many as you like

    public static let frame = 24
    /// Every body and how fast it plays, in frames per second. The frame count is the image width ÷ frame.
    public static let bodies: [(name: String, fps: Double)] = [
        ("idle", 4), ("walk", 10), ("walkmug", 10), ("type", 8), ("bob", 6), ("stretch", 6), ("coffee", 6),
        ("wave", 8), ("jump", 8), ("shh", 6), ("yawn", 5), ("huff", 6), ("dizzy", 10), ("pet", 8),
        // Fidgets
        ("sip", 6), ("lookaround", 4), ("gaze", 3), ("scratch", 8), ("spin", 10), ("nod", 4),
        // Using the Room
        ("needle", 6), ("couch", 4), ("popcorn", 6), ("water", 6), ("pour", 6), ("switch", 6), ("call", 4),
    ]
    public static func fps(of body: String) -> Double { bodies.first { $0.name == body }?.fps ?? 8 }

    /// Where the face-screen sits inside every body frame. Keep the head here in every frame.
    public static let faceScreen = CGRect(x: 7, y: 4, width: 10, height: 7)
    /// The frame row just under the torso: Pix's seat when it sits.
    public static let seatRow = 19
    /// How far right of Pix's center its raised right hand is.
    public static let raisedHand = 8

    // MARK: Faces — pix-face.png: faceScreen-sized faces side by side: one per Mood, then the blink

    public static let faces = ["content", "focused", "sleepy", "cheerful", "grumpy", "blink"]

    // MARK: Emotes — emotes.png: emote × emote each, side by side. Particles use the same cells.

    public static let emote = 8
    public static let emotes = ["heart", "zzz", "exclaim", "note", "coffee", "steam", "star", "bolt", "pumpkin"]

    // MARK: Hats — hats.png: hat-sized cells side by side, one per hat, worn over the head (Pix earns them)

    /// Where a hat sits within a body frame: over the head, rising into the 3 free rows above the frame.
    public static let hat = CGRect(x: 4, y: -3, width: 16, height: 6)
    /// In a fixed order: a skin's hats.png may stop early and still keep its hats, so new hats only go at the end.
    public static let hats = ["cap", "beanie", "party", "flower", "crown", "headband", "witch", "santa", "topHat"]
    /// Bodies that can't be done in a hat (the call's headset): Pix takes it off for them, and puts it back after.
    static let hatless: Set<String> = ["call"]
    public static func wearsHat(_ body: String) -> Bool { !hatless.contains(body) }

    // MARK: Sky — cloud.png drifts past the window by day

    public static let cloud = CGSize(width: 16, height: 6)

    public static func file(_ name: String) -> String { name + ".png" }

    /// Whether a skin's drawing can stand in for a bundled art file of `bundled` size: the same height, and the same
    /// width too, except Pix's body sheets, which may have any number of frames, and the hats, which may stop early
    /// (the hats it leaves out come from Pix's own).
    public static func skinFits(_ name: String, width: Int, height: Int, bundled: (width: Int, height: Int)) -> Bool {
        guard height == bundled.height else { return false }
        if name == "hats" { return width > 0 && width <= bundled.width && width % Int(hat.width) == 0 }
        return name.hasPrefix("pix-") && name != "pix-face" ? width > 0 && width % frame == 0 : width == bundled.width
    }
}
