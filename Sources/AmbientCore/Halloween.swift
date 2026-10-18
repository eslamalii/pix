import CoreGraphics
import Foundation

/// Halloween's Occasion Props, and the Occasion season they stand in the Room for. Everything Halloween adds lives in
/// this file, Sources/Pix/Halloween.swift, scripts/art/halloween.swift and Art/Halloween, so the season comes and goes
/// with one commit.
public enum Halloween {
    /// The Occasion season: October 24 through November 1, so a user who skips October 31 still finds the Room dressed.
    public static func inSeason(on time: Date, calendar: Calendar) -> Bool {
        let month = calendar.component(.month, from: time), day = calendar.component(.day, from: time)
        return month == 10 && day >= 24 || month == 11 && day == 1
    }

    /// Where the art lives, inside Art: room-<strip>.png (the Occasion Props on a clear strip), moon.png and bat.png.
    public static let folder = "Halloween"

    /// The Occasion Props, stamped into their strip's Halloween layer by the art generator, as Art.props are into the Room.
    /// The haunted print hangs exactly over the Room's print, covering it for the season.
    public static let props: [Art.Prop] = [
        Art.Prop(name: "jackOLantern", strip: "desk", x: 50, y: nil),
        Art.Prop(name: "jackSmall", strip: "desk", x: 66, y: nil),
        Art.Prop(name: "pumpkin", strip: "desk", x: 78, y: nil),
        Art.Prop(name: "candles", strip: "desk", x: 128, y: 0),  // on top of the bookcase
        Art.Prop(name: "bunting", strip: "desk", x: 150, y: 0),
        Art.Prop(name: "candle", strip: "desk", x: 276, y: 1),   // in the gap on the shelf
        Art.Prop(name: "spider", strip: "desk", x: 295, y: 11),  // hanging from the end of the shelf
        Art.Prop(name: "hauntedPrint", strip: "desk", x: 342, y: 5),
        Art.Prop(name: "ghost", strip: "desk", x: 664, y: 4),    // hanging from the lamp shade
        Art.Prop(name: "broom", strip: "desk", x: 880, y: nil),
        Art.Prop(name: "cobweb", strip: "window", x: Int(Art.windowPane.minX), y: Int(Art.windowPane.minY)),
        Art.Prop(name: "cobwebRight", strip: "window", x: Int(Art.windowPane.maxX) - 10, y: Int(Art.windowPane.minY)),
        Art.Prop(name: "jackSmall", strip: "window", x: 420, y: 14),  // on the windowsill
    ]

    /// The jack-o'-lantern faces and candle flames: they glow and flicker from dusk on. Art-contract rectangles on a strip.
    public static let glows: [(strip: String, rect: CGRect)] = [
        ("desk", CGRect(x: 53, y: 19, width: 9, height: 6)),
        ("desk", CGRect(x: 68, y: 21, width: 6, height: 4)),
        ("desk", CGRect(x: 129, y: 0, width: 8, height: 4)),
        ("desk", CGRect(x: 277, y: 1, width: 1, height: 2)),
        ("window", CGRect(x: 422, y: 17, width: 6, height: 4)),
    ]

    /// The orange moon in the window at night.
    public static let moon = CGSize(width: 10, height: 10)
    /// A bat crossing the window at night: bat.png holds its two wing beats side by side.
    public static let bat = CGSize(width: 7, height: 4)
}
