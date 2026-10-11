// Draws the art for every file in the art contract (Sources/AmbientCore/ArtContract.swift), in the Glass style:
// a black Room of dark silhouettes with a thin rim of light, so it melts into the bar, and a white Pix
// with a glowing face-screen as the brightest thing on it.
// Replace any file in Art/ with a hand drawing of the same size; nothing else changes.
// Run: scripts/make-art.sh
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: a)
}

/// A canvas in art pixels with a top-left origin.
final class Canvas {
    let ctx: CGContext
    let w: Int, h: Int
    init(_ w: Int, _ h: Int) {
        (self.w, self.h) = (w, h)
        ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
    }
    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    func dots(_ points: [(Int, Int)], _ color: CGColor, dx: Int = 0, dy: Int = 0) {
        for (x, y) in points { rect(x + dx, y + dy, 1, 1, color) }
    }
    func stroke(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: CGColor) {
        rect(x, y, w, 1, color); rect(x, y + h - 1, w, 1, color); rect(x, y, 1, h, color); rect(x + w - 1, y, 1, h, color)
    }
    func clear(_ r: CGRect) { ctx.clear(r) }
    var image: CGImage { ctx.makeImage()! }
    /// Draws `image` with its top-left corner at (x, y). The context is flipped, so the image is flipped back.
    func stamp(_ image: CGImage, x: Int, y: Int) {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(x), y: CGFloat(y + image.height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.restoreGState()
    }
    /// Ordered-dithers both ends of the strip to transparent, so the Room fades into the bezel.
    func fadeEdges(_ edge: Int = 36) {
        let bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in 0..<h { for x in 0..<w {
            let t = Double(min(x, w - 1 - x)) / Double(edge)
            if t < 1 && (Double(bayer[y % 4][x % 4]) + 0.5) / 16 > t { clear(CGRect(x: x, y: y, width: 1, height: 1)) }
        } }
    }
    func save(_ name: String) {
        let url = out.appendingPathComponent(Art.file(name))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("  \(Art.file(name)) \(w)×\(h)")
    }
}

// MARK: - Pix

let outline = hex(0x4a4f5c), shell = hex(0xeceef3), shade = hex(0xb4bac8), light = hex(0xffffff), screen = hex(0x0b0d12)
let limb = hex(0x8f95a3), foot = hex(0x6b7183), glow = hex(0x5ee6ff), dimGlow = hex(0x2a7f8f)
let bulb = hex(0xff6b6b), dimBulb = hex(0x8f3a3a), blush = hex(0xff7eb6), mugColor = hex(0xd8d8e0), coffee = hex(0x5a3a28)

/// One Pix frame. The head and its face-screen never move, per the contract; the antenna, arms and legs do.
func drawPix(_ c: Canvas, at ox: Int, body: String, frame f: Int) {
    let even = f.isMultiple(of: 2)
    func r(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: CGColor) { c.rect(ox + x, y, w, h, color) }

    // antenna: it sways for lookaround, gaze and dizzy, droops for a nod, and its bulb dims as Pix breathes
    let antennaX = body == "lookaround" ? [11, 10, 11, 12][f % 4] : body == "dizzy" ? (even ? 10 : 12) : body == "gaze" ? [11, 11, 12, 12][f % 4] : 11
    let drooped = body == "nod" && f >= 2
    r(antennaX, drooped ? 1 : 0, 2, 1, body == "idle" && f >= 3 ? dimBulb : bulb)
    if !drooped { r(11, 1, 2, 1, outline) }
    // side bolts
    r(4, 6, 1, 3, limb); r(19, 6, 1, 3, limb)
    // head: a rounded box, lit from the top, shaded at the right and bottom
    r(6, 2, 12, 1, outline); r(6, 12, 12, 1, outline); r(5, 3, 1, 9, outline); r(18, 3, 1, 9, outline)
    r(6, 3, 12, 9, shell); r(6, 3, 11, 1, light); r(17, 4, 1, 8, shade); r(6, 11, 12, 1, shade)
    // face-screen with soft corners
    let s = Art.faceScreen
    r(Int(s.minX), Int(s.minY), Int(s.width), Int(s.height), screen)
    for (x, y) in [(7, 4), (16, 4), (7, 10), (16, 10)] { r(x, y, 1, 1, shell) }
    if body == "pet" { r(6, 8, 1, 2, blush); r(17, 8, 1, 2, blush) }
    if body == "call" {  // a headset, kept off the face-screen
        r(6, 1, 5, 1, limb); r(13, 1, 5, 1, limb); r(5, 2, 1, 1, limb); r(18, 2, 1, 1, limb)  // the band, around the antenna
        r(3, 5, 2, 4, foot); r(19, 5, 2, 4, foot)  // ear cups, over the side bolts
        r(20, 9, 1, 3, limb); r(17, 12, 3, 1, limb); r(16, 12, 1, 1, dimGlow)  // the mic arm, down and in to the chin
    }
    // torso with a chest light that breathes with the bulb; walking leans it (and the arms) a pixel forward
    let lean = body == "walk" ? 1 : 0
    func leaned(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: CGColor) { r(x + lean, y, w, h, color) }
    leaned(8, 13, 1, 5, outline); leaned(15, 13, 1, 5, outline); leaned(9, 18, 6, 1, outline)
    leaned(9, 13, 6, 5, shell); leaned(14, 13, 1, 5, shade); leaned(9, 17, 6, 1, shade)
    leaned(11, 15, 2, 1, body == "idle" && f >= 3 ? dimGlow : glow)

    // legs
    switch body {
    case "type", "coffee", "sip", "lookaround", "call":  // seated, legs toward the desk
        r(9, 19, 7, 2, limb); r(14, 21, 2, 2, limb); r(14, 23, 3, 1, foot)
    case "couch", "popcorn":  // sitting on the couch's edge, feet dangling (the renderer lifts Pix onto the seat)
        r(9, 19, 2, 2, limb); r(13, 19, 2, 2, limb); r(8, 21, 3, 1, foot); r(13, 21, 3, 1, foot)
    case "walk":  // six frames: left foot up, still up, pass, right foot up, still up, pass
        let lift = ["L", "L", "", "R", "R", ""][f % 6]
        r(9, 19, 2, lift == "L" ? 3 : 4, limb); r(8, lift == "L" ? 22 : 23, 3, 1, foot)
        r(13, 19, 2, lift == "R" ? 3 : 4, limb); r(13, lift == "R" ? 22 : 23, 3, 1, foot)
    case "jump":  // crouch, tucked in the air twice, squash on landing; the renderer lowers Pix a point for the crouch and squash
        let tuck = f == 1 || f == 2
        r(9, 19, 2, tuck ? 2 : 3, limb); r(8, tuck ? 21 : 22, 3, 1, foot)
        r(13, 19, 2, tuck ? 2 : 3, limb); r(13, tuck ? 21 : 22, 3, 1, foot)
    case "bob":  // tapping one foot to the beat
        r(9, 19, 2, 4, limb); r(8, 23, 3, 1, foot)
        r(13, 19, 2, even ? 4 : 3, limb); r(13, even ? 23 : 22, 3, 1, foot)
    default:
        r(9, 19, 2, 4, limb); r(13, 19, 2, 4, limb); r(8, 23, 3, 1, foot); r(13, 23, 3, 1, foot)
    }

    // arms: a hanging arm is 2 wide with a darker hand below; a reaching arm is 1 tall with the hand at its end
    func arm(_ x: Int, _ y: Int, _ h: Int = 3) { leaned(x, y, 2, h, limb); leaned(x, y + h, 2, 1, foot) }
    /// An arm out from the shoulder and up, a gap away from the head: column x (2 on the left, 20 or 21 on the right), hand at row top.
    func raised(_ x: Int, _ top: Int) {
        if x > 12 { r(16, 14, x - 16, 1, limb) } else { r(x + 2, 14, 6 - x, 1, limb) }
        r(x, top + 1, 2, 14 - top, limb); r(x, top, 2, 1, foot)
    }
    func reach(_ x: Int, _ y: Int, _ w: Int) { r(x, y, w, 1, limb); r(x + w, y, 1, 1, foot) }
    func reachLeft(_ x: Int, _ y: Int, _ w: Int) { r(x - w + 1, y, w, 1, limb); r(x - w, y, 1, 1, foot) }
    func mug(_ x: Int, _ y: Int) { r(x, y, 3, 3, mugColor); r(x, y, 3, 1, coffee); r(x + 3, y + 1, 1, 1, mugColor) }

    switch body {
    case "walk": arm(6, [15, 15, 14, 14, 14, 14][f % 6]); arm(16, [14, 14, 14, 15, 15, 14][f % 6])
    case "type":
        arm(6, 14)
        reach(16, even ? 15 : 16, 5); reach(16, even ? 16 : 15, 4)
    case "bob": if even { raised(2, 9); arm(16, 14) } else { arm(6, 14); raised(20, 9) }
    case "stretch", "yawn":
        let top = [12, 9, 5, 9][f % 4]
        raised(2, top); raised(20, top)
    case "wave": arm(6, 14); raised(even ? 20 : 21, even ? 5 : 6)  // the hand rocks out and back
    case "shh": arm(6, 14); r(13, 13, 2, 2, limb); r(12, 11, 2, 2, foot)  // a hand over the mouth
    case "huff": r(7, 15, 10, 2, limb); r(7, 15, 1, 2, foot); r(16, 15, 1, 2, foot)  // arms crossed
    case "dizzy": arm(even ? 5 : 6, 14); arm(even ? 17 : 16, 14)
    case "pet": r(6, 14, 2, 2, limb); r(16, 14, 2, 2, limb); r(8, 16, 2, 1, foot); r(14, 16, 2, 1, foot)  // hands clasped, bashful
    case "coffee":
        arm(6, 14)
        let y = f < 2 ? 15 : 12
        reach(16, y, 3); mug(19, y - 2)
    case "sip":
        arm(6, 14)
        let y = [15, 13, 11, 13][f % 4]
        reach(16, y + 2, 2); mug(17, y - 1)
    case "lookaround": arm(6, 14); reach(16, 16, 4)
    case "gaze": r(7, 16, 2, 2, limb); r(15, 16, 2, 2, limb)  // hands behind the back, only the elbows show
    case "scratch": arm(6, 14); raised(20, even ? 4 : 5); r(19, even ? 4 : 5, 1, 1, foot)  // fingers on the head
    case "spin":
        let reachOut = [1, 3, 5, 3, 1, 3, 5, 3][f % 8]
        reachLeft(7, 14, reachOut); reach(16, 14, reachOut)
    case "nod": arm(6, f >= 2 ? 15 : 14); arm(16, f >= 2 ? 15 : 14)
    case "needle":  // reaches over to the turntable and lowers the needle
        arm(6, 14)
        if f == 0 { arm(16, 14) } else { reach(16, f == 1 ? 13 : 14, f == 1 ? 4 : 6) }
    case "popcorn":  // a striped bucket on the lap; one hand dips in, then goes to the mouth
        r(9, 16, 6, 3, hex(0xd8d8e0)); r(10, 16, 1, 3, bulb); r(13, 16, 1, 3, bulb); c.dots([(9, 15), (11, 15), (14, 15)].map { (ox + $0.0, $0.1) }, hex(0xffe08a))
        arm(6, 14)
        if even { r(15, 15, 2, 1, limb); r(14, 15, 1, 1, foot) } else { r(13, 13, 2, 2, limb); r(12, 11, 2, 2, foot) }
    case "water":  // a watering can held out front, tipping until drops fall
        arm(6, 14)
        reach(16, 15, 2)
        let can = hex(0x6b8fb0)
        r(18, 14, 4, 3, can); r(19, 13, 2, 1, can)
        if f == 0 { r(22, 14, 1, 1, can) } else { r(22, 16, 1, 1, can) }
        if f >= 2 { c.dots((f == 2 ? [(23, 18), (22, 20)] : [(23, 19), (23, 21)]).map { (ox + $0.0, $0.1) }, glow) }
    case "call":  // on a call: hands resting, then one gestures while talking
        arm(6, 14)
        if f == 2 { reach(16, 15, 3) } else { arm(16, 14) }
    case "switch": arm(6, 14); raised(20, [12, 8, 6, 8][f % 4])  // reaches up to the switch on the lamp's pole
    case "jump": if f == 1 || f == 2 { raised(2, 6); raised(20, 6) } else { arm(5, 15, 2); arm(17, 15, 2) }  // arms swing up, then brace
    default: arm(6, 14); arm(16, 14)
    }
}

// MARK: - Faces (drawn on the face-screen; positions are inside a 10 × 7 screen)

let faces: [String: [(Int, Int)]] = [
    "content": [(2, 2), (3, 2), (2, 3), (3, 3), (6, 2), (7, 2), (6, 3), (7, 3), (3, 5), (6, 5), (4, 6), (5, 6)],
    "focused": [(1, 2), (2, 2), (3, 2), (6, 2), (7, 2), (8, 2), (2, 3), (3, 3), (6, 3), (7, 3), (4, 5), (5, 5)],
    "sleepy": [(1, 4), (2, 4), (3, 4), (6, 4), (7, 4), (8, 4), (4, 6), (5, 6)],
    "cheerful": [(1, 3), (2, 2), (3, 3), (6, 3), (7, 2), (8, 3), (3, 5), (4, 5), (5, 5), (6, 5), (4, 6), (5, 6)],
    "grumpy": [(1, 1), (2, 1), (3, 2), (8, 1), (7, 1), (6, 2), (2, 3), (3, 3), (6, 3), (7, 3), (3, 6), (4, 5), (5, 5), (6, 6)],
    "blink": [(2, 3), (3, 3), (6, 3), (7, 3), (3, 5), (6, 5), (4, 6), (5, 6)],
]

// MARK: - Emotes (8 × 8)

let emoteArt: [String: ([(Int, Int)], CGColor)] = [
    "heart": ([(1, 1), (2, 1), (5, 1), (6, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2),
               (0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4),
               (2, 5), (3, 5), (4, 5), (5, 5), (3, 6), (4, 6)], hex(0xff6b8b)),
    "zzz": ([(3, 0), (4, 0), (5, 0), (6, 0), (5, 1), (4, 2), (3, 3), (4, 3), (5, 3), (6, 3),
             (0, 4), (1, 4), (2, 4), (1, 5), (0, 6), (1, 6), (2, 6)], hex(0x79c0ff)),
    "exclaim": ([(3, 0), (4, 0), (3, 1), (4, 1), (3, 2), (4, 2), (3, 3), (4, 3), (3, 4), (4, 4), (3, 6), (4, 6)], hex(0xe3b341)),
    "note": ([(4, 0), (5, 0), (6, 0), (4, 1), (7, 1), (4, 2), (4, 3), (4, 4), (2, 5), (3, 5), (4, 5), (2, 6), (3, 6), (4, 6)], hex(0x5ee6ff)),
    "coffee": ([(2, 0), (4, 1), (2, 2), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4),
                (1, 5), (2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (2, 6), (3, 6), (4, 6)], hex(0xd8d8e0)),
    "steam": ([(3, 1), (4, 2), (3, 3), (2, 4), (3, 5), (4, 6)], hex(0xc9d1d9, 0.6)),
    "star": ([(3, 2), (3, 3), (3, 4), (2, 3), (4, 3)], hex(0xffe08a)),
    "pumpkin": ([(4, 0), (2, 1), (3, 1), (4, 1), (5, 1), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (0, 3), (1, 3), (3, 3), (4, 3), (6, 3), (7, 3), (0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (1, 5), (2, 5), (5, 5), (6, 5), (2, 6), (3, 6), (4, 6), (5, 6)], hex(0xff9a3c)),
    "bolt": ([(4, 0), (5, 0), (3, 1), (4, 1), (2, 2), (3, 2), (2, 3), (3, 3), (4, 3), (5, 3), (4, 4), (5, 4), (3, 5), (4, 5), (2, 6), (3, 6)], hex(0xffd84a)),
]

// MARK: - Hats: each one a few colors of dots in a hat-sized cell (see Art.hat)

let hatArt: [String: [([(Int, Int)], CGColor)]] = [
    "cap": [([(4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2), (11, 2), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3), (10, 3), (11, 3), (12, 3), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (12, 4), (2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (12, 5), (13, 5), (14, 5), (15, 5)], hex(0xff6b6b))],
    "beanie": [([(7, 0), (8, 0), (2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (12, 5), (13, 5)], hex(0xeceef3)), ([(5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2), (11, 2), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3), (10, 3), (11, 3), (12, 3), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (12, 4)], hex(0x5ea8ff))],
    "party": [([(7, 0), (8, 0), (6, 2), (7, 2), (8, 2), (9, 2), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4)], hex(0xffd84a)), ([(7, 1), (8, 1), (6, 3), (7, 3), (8, 3), (9, 3), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5)], hex(0xff7eb6))],
    "flower": [([(2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (12, 5), (13, 5)], hex(0x6bbf59)), ([(10, 2), (12, 2), (11, 2), (10, 3), (12, 3), (10, 4), (11, 4), (12, 4), (4, 4), (6, 4)], hex(0xff7eb6)), ([(11, 3), (5, 4)], hex(0xffd84a))],
    "crown": [([(3, 2), (7, 1), (8, 1), (12, 2), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3), (10, 3), (11, 3), (12, 3), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (12, 4), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (12, 5)], hex(0xffc83d)), ([(7, 4), (8, 4)], hex(0xff6b6b))],
    "headband": [(row(3...12, 4) + row(3...12, 5) + [(13, 4), (14, 5)], hex(0x4ad6c8)), (row(4...11, 4), hex(0x8ff0e6))],
    "witch": [(row(1...14, 5), hex(0x6e55b8)), (row(5...10, 4), hex(0xff9f43)), (row(6...9, 3) + row(7...9, 2) + row(8...9, 1) + [(10, 0), (11, 0)], hex(0x8a6fd6))],
    "santa": [(row(3...12, 5) + [(13, 2), (14, 2), (13, 3), (14, 3)], hex(0xeceef3)), (row(4...11, 4) + row(5...10, 3) + row(7...11, 2) + row(10...12, 1), hex(0xff4d4d))],
    "topHat": [(row(2...13, 5) + row(5...10, 1) + row(5...10, 2) + row(5...10, 3), hex(0x4a4a56)), (row(5...10, 0), hex(0x8a8a9a)), (row(5...10, 4), hex(0xff6b6b))],
]

/// The points of one row of a hat, from x to x.
func row(_ xs: ClosedRange<Int>, _ y: Int) -> [(Int, Int)] { xs.map { ($0, y) } }

// MARK: - Props: each drawn on its own small canvas, the way a hand drawing would be

let rim = hex(0x5a5a68), silhouette = hex(0x34343e), deep = hex(0x24242b), floorLine = hex(0x2c2c35)
let leaf = hex(0x5c9a6e), darkLeaf = hex(0x3d6b4f)
let blueBook = hex(0x3d6b8f), brownBook = hex(0x8a5a44), purpleBook = hex(0x5c4a8a), gray = hex(0x6b6b78), steel = hex(0x4a4a56)
let floorY = Art.height - Art.floor

/// The generated drawing of every Prop, by name.
let generatedProps: [String: () -> Canvas] = [
    "bookcase": {
        let c = Canvas(26, 21)
        c.rect(0, 0, 26, 21, silhouette); c.rect(0, 0, 26, 1, rim); c.rect(1, 1, 24, 19, deep)
        let spines = [blueBook, brownBook, purpleBook, gray, darkLeaf]
        for (row, y) in [2, 8, 14].enumerated() {
            c.rect(1, y + 5, 24, 1, silhouette)
            var x = 2 + row
            for i in 0..<(6 - row) {
                let h = 3 + (i + row) % 3
                c.rect(x, y + 5 - h, 2, h, spines[(i + row * 2) % spines.count]); x += 3
            }
        }
        return c
    },
    "shelf": {
        let c = Canvas(40, 9)
        c.rect(0, 7, 40, 1, rim); c.rect(0, 8, 40, 1, deep)
        c.rect(4, 1, 3, 6, blueBook); c.rect(7, 2, 2, 5, brownBook); c.rect(9, 0, 3, 7, purpleBook); c.rect(13, 1, 2, 6, gray)
        c.rect(22, 5, 9, 2, blueBook); c.rect(23, 3, 7, 2, brownBook)
        c.rect(34, 4, 3, 3, leaf); c.rect(35, 2, 1, 2, darkLeaf)
        return c
    },
    "print": {
        let c = Canvas(20, 12)
        c.stroke(0, 0, 20, 12, silhouette); c.rect(1, 1, 18, 10, hex(0x101018))
        c.rect(2, 7, 7, 3, hex(0x2c3e5c)); c.rect(6, 5, 9, 5, hex(0x3a4f73)); c.rect(15, 3, 1, 1, hex(0xe3b341))
        return c
    },
    "plant": {
        let c = Canvas(12, 19)
        c.rect(2, 13, 8, 6, silhouette); c.rect(1, 13, 10, 1, rim)
        c.rect(5, 1, 2, 12, darkLeaf)
        for (x, y, w, color) in [(1, 8, 4, darkLeaf), (2, 5, 3, leaf), (7, 3, 3, leaf), (8, 7, 4, darkLeaf),
                                 (4, 0, 3, leaf), (0, 10, 3, leaf), (9, 10, 3, leaf)] {
            c.rect(x, y, w, 2, color)
        }
        return c
    },
    "desk": {
        let c = Canvas(Int(Art.desk.width), Int(Art.desk.height))
        c.rect(0, 0, c.w, 1, rim); c.rect(0, 1, c.w, 1, silhouette); c.rect(3, 2, 2, 6, deep); c.rect(c.w - 5, 2, 2, 6, deep)
        return c
    },
    "chair": {
        let c = Canvas(17, 15)
        c.rect(0, 0, 2, 11, silhouette); c.rect(0, 0, 2, 1, rim); c.rect(0, 10, 17, 2, silhouette); c.rect(0, 10, 17, 1, rim)
        c.rect(7, 12, 2, 3, deep); c.rect(3, 14, 10, 1, deep)
        return c
    },
    "monitor": {
        let c = Canvas(Int(Art.monitors[0].width) + 2, Int(Art.monitors[0].height) + 2)
        c.rect(0, 0, c.w, c.h, silhouette); c.rect(0, 0, c.w, 1, rim); c.rect(1, 1, c.w - 2, c.h - 2, hex(0x06080e))
        return c
    },
    "keyboard": {
        let c = Canvas(16, 1)
        c.rect(0, 0, 16, 1, steel)
        return c
    },
    "mug": {
        let c = Canvas(Int(Art.mug.width), Int(Art.mug.height))
        c.rect(0, 0, 3, 4, mugColor); c.rect(0, 0, 3, 1, coffee); c.rect(3, 1, 1, 2, mugColor)
        return c
    },
    "lamp": {
        let size = Art.workingProps["lamp"]!
        let c = Canvas(Int(size.width), Int(size.height))
        c.rect(3, 0, 8, 1, gray); c.rect(1, 1, 12, 1, hex(0x55556a)); c.rect(0, 2, 14, 1, hex(0x3e3e4a))
        c.rect(6, 3, 2, c.h - 4, silhouette); c.rect(2, c.h - 1, 10, 1, rim)
        return c
    },
    "cabinet": {  // the record's surface sits where Art.turntable says
        let c = Canvas(Int(Art.cabinet.width), Int(Art.cabinet.height))
        c.rect(0, 7, 40, 8, silhouette); c.rect(0, 7, 40, 1, rim); c.rect(19, 9, 1, 5, deep)
        c.rect(4, 4, 16, 3, steel); c.rect(6, 3, 12, 1, hex(0x1c1c22)); c.rect(17, 2, 1, 2, rim)  // turntable
        c.rect(28, 0, 8, 7, deep); c.rect(28, 0, 8, 1, rim); c.rect(31, 3, 2, 2, steel)              // speaker
        return c
    },
    "window": {  // frame, mullions and sill around a see-through pane, where the sky shows
        let size = Art.workingProps["window"]!, w = Int(Art.windowPane.width), h = Int(Art.windowPane.height)
        let c = Canvas(Int(size.width), Int(size.height))
        c.rect(3, 0, w + 4, h + 4, silhouette); c.rect(3, 0, w + 4, 1, rim)
        c.clear(CGRect(x: 5, y: 2, width: w, height: h))
        c.rect(5 + w / 3, 2, 1, h, silhouette); c.rect(5 + 2 * w / 3, 2, 1, h, silhouette)
        c.rect(0, h + 4, c.w, 1, rim); c.rect(0, h + 5, c.w, 1, deep)
        return c
    },
    "couch": {  // the seat cushion's top is Art.couchSeat rows down, where Pix sits
        let size = Art.workingProps["couch"]!, seat = Art.couchSeat
        let c = Canvas(Int(size.width), Int(size.height))
        let fabric = hex(0x3a3652), lit = hex(0x55507a), shadow = hex(0x2a2740)
        c.rect(4, 0, c.w - 8, seat + 3, fabric); c.rect(4, 0, c.w - 8, 1, lit)               // backrest and seat
        c.rect(4, seat, c.w - 8, 1, lit); c.rect(c.w / 2, seat, 1, 3, shadow)                 // two cushions
        c.rect(0, 2, 4, 8, fabric); c.rect(0, 2, 4, 1, lit)                                  // arms
        c.rect(c.w - 4, 2, 4, 8, fabric); c.rect(c.w - 4, 2, 4, 1, lit)
        c.rect(0, seat + 3, c.w, 3, shadow)                                                  // base
        c.rect(2, c.h - 2, 2, 2, deep); c.rect(c.w - 4, c.h - 2, 2, 2, deep)                 // legs
        return c
    },
    "cactus": {
        let c = Canvas(5, 7)
        c.rect(0, 4, 5, 3, gray); c.rect(1, 0, 3, 4, leaf); c.dots([(0, 1), (4, 2)], leaf)
        return c
    },
    "cushion": {
        let c = Canvas(16, 4)
        c.rect(0, 1, 16, 3, hex(0x2e2e45)); c.rect(1, 0, 14, 1, hex(0x3d3d5c))
        return c
    },
    "books": {
        let c = Canvas(16, 6)
        for (i, color) in [blueBook, brownBook, purpleBook].enumerated() { c.rect(i, 4 - 2 * i, 16 - 2 * i, 2, color) }
        return c
    },
]

/// The user's drawings, read from Art/props and never written. A drawing of a working Prop must keep its size.
func userProps(in folder: URL) -> [String: CGImage] {
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    let known = Set(Art.props.map(\.name))
    var drawings: [String: CGImage] = [:]
    for file in files where file.pathExtension.lowercased() == "png" {
        let name = file.deletingPathExtension().lastPathComponent
        guard known.contains(name) else {
            warn("props/\(file.lastPathComponent) skipped: no Prop named \(name) in the art contract")
            continue
        }
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            warn("props/\(file.lastPathComponent) skipped: not a readable PNG")
            continue
        }
        if let size = Art.workingProps[name], size != CGSize(width: image.width, height: image.height) {
            warn("props/\(file.lastPathComponent) is \(image.width)×\(image.height), but \(name) must be \(Int(size.width))×\(Int(size.height)); it may not line up")
        }
        print("  using your \(file.lastPathComponent)")
        drawings[name] = image
    }
    return drawings
}

func warn(_ message: String) { FileHandle.standardError.write(Data("  warning: \(message)\n".utf8)) }

/// One strip of the Room: the floor line, then every Prop on it (the user's drawing where there is one).
func strip(_ strip: String, with drawings: [String: CGImage]) -> Canvas {
    let c = Canvas(Art.stripWidth, Art.height)
    c.rect(0, floorY, c.w, 1, floorLine)
    for prop in Art.props where prop.strip == strip {
        guard let image = drawings[prop.name] ?? generatedProps[prop.name]?().image else {
            warn("no drawing for Prop \(prop.name)")
            continue
        }
        let y = prop.y ?? floorY - image.height
        if prop.x < 0 || y < 0 || prop.x + image.width > c.w || y + image.height > Art.height {
            warn("\(prop.name) at x \(prop.x), y \(y) (\(image.width)×\(image.height)) doesn't fit inside the \(strip) strip; part of it is cut off")
        }
        c.stamp(image, x: prop.x, y: y)
    }
    c.fadeEdges()
    return c
}

// MARK: - Write everything

try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
print("Writing art to \(out.path):")
// Frame counts here; hand-drawn art can use any count (the renderer reads it from the width).
let frameCounts = ["walk": 6, "idle": 6, "spin": 8]
for (body, _) in Art.bodies {
    let frames = frameCounts[body] ?? 4
    let c = Canvas(Art.frame * frames, Art.frame)
    for f in 0..<frames { drawPix(c, at: f * Art.frame, body: body, frame: f) }
    c.save("pix-\(body)")
}
let faceSheet = Canvas(Int(Art.faceScreen.width) * Art.faces.count, Int(Art.faceScreen.height))
for (i, face) in Art.faces.enumerated() {
    let dx = i * Int(Art.faceScreen.width)
    faceSheet.dots(faces[face]!, glow, dx: dx)
    if face == "cheerful" { faceSheet.dots([(0, 5), (9, 5)], blush, dx: dx) }
}
faceSheet.save("pix-face")
let emoteSheet = Canvas(Art.emote * Art.emotes.count, Art.emote)
for (i, name) in Art.emotes.enumerated() { emoteSheet.dots(emoteArt[name]!.0, emoteArt[name]!.1, dx: i * Art.emote) }
emoteSheet.save("emotes")
let hatSheet = Canvas(Int(Art.hat.width) * Art.hats.count, Int(Art.hat.height))
for (i, name) in Art.hats.enumerated() { for (dots, color) in hatArt[name]! { hatSheet.dots(dots, color, dx: i * Int(Art.hat.width)) } }
hatSheet.save("hats")
let cloud = Canvas(Int(Art.cloud.width), Int(Art.cloud.height))
cloud.rect(3, 0, 6, 2, hex(0xffffff, 0.9)); cloud.rect(1, 2, 14, 3, hex(0xffffff, 0.9)); cloud.rect(9, 1, 4, 1, hex(0xffffff, 0.9))
cloud.save("cloud")
let drawings = userProps(in: out.appendingPathComponent("props"))
for name in Art.strips { strip(name, with: drawings).save("room-\(name)") }
