import AppKit
import AmbientCore
import os

private let log = Logger(subsystem: appID, category: "art")

/// The art files, loaded once each: from the chosen skin's folder when it has a drawing that fits, otherwise from the
/// app bundle (Contents/Resources/Art).
@MainActor
final class ArtFiles {
    private let classicFolder: URL?

    init(classicFolder: URL? = Bundle.main.resourceURL?.appendingPathComponent("Art"), skin: URL? = nil) {
        self.classicFolder = classicFolder
        self.skin = skin
    }
    private var cache: [String: CGImage] = [:]
    /// The chosen skin's folder; nil for Pix's own art.
    var skin: URL? { didSet { cache = [:] } }

    func image(_ name: String) -> CGImage? {
        if let hit = cache[name] { return hit }
        guard let bundled = classic(name) else { return nil }
        var image = bundled
        if let skin, let drawn = load(skin.appendingPathComponent(Art.file(name))) {
            if Art.skinFits(name, width: drawn.width, height: drawn.height, bundled: (bundled.width, bundled.height)) {
                image = drawn
            } else {
                log.error("skin art \(name, privacy: .public) is \(drawn.width)×\(drawn.height), not \(bundled.width)×\(bundled.height): using Pix's own")
            }
        }
        cache[name] = image
        return image
    }

    /// Occasion Props stay Classic, including when the Room uses a Skin.
    func halloweenImage(_ name: String) -> CGImage? {
        classic("\(Halloween.folder)/\(name)")
    }

    /// Pix's own drawing, whatever the skin: what a skin's hats.png that stops early leaves out comes from here.
    private func classic(_ name: String) -> CGImage? {
        if let hit = cache["classic/" + name] { return hit }
        guard let url = classicFolder?.appendingPathComponent(Art.file(name)), let bundled = load(url) else {
            log.error("missing art: \(name, privacy: .public)")
            return nil
        }
        cache["classic/" + name] = bundled
        return bundled
    }

    /// A complete Hat drawing: a valid Skin cell, or the same Hat from Classic when a short sheet omits it.
    func hat(_ hat: Hat) -> (image: CGImage, rect: CGRect)? {
        guard let index = Art.hats.firstIndex(of: hat.rawValue), let sheet = image("hats") else { return nil }
        let cells = sheet.width / Int(Art.hat.width)
        if index < cells { return (sheet, slot(index, of: cells)) }
        guard let classic = classic("hats") else { return nil }
        return (classic, slot(index, of: Art.hats.count))
    }

    private func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// Layers measure in points, and the Touch Bar is a 2× screen: one point is 2×2 pixels, i.e. exactly one art pixel.
func px(_ artPixels: Int) -> CGFloat { CGFloat(artPixels) }
func px(_ artPixels: CGFloat) -> CGFloat { artPixels }

/// The part of a horizontal sprite sheet holding cell `index` of `count`.
func slot(_ index: Int, of count: Int) -> CGRect {
    CGRect(x: CGFloat(index) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1)
}

func emoteSlot(_ name: String) -> CGRect { slot(Art.emotes.firstIndex(of: name) ?? 0, of: Art.emotes.count) }

func pixelCrisp(_ image: CGImage?) -> CALayer {
    let layer = CALayer()
    layer.contents = image
    layer.magnificationFilter = .nearest
    return layer
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let facingLeft = CATransform3DMakeScale(-1, 1, 1)

func withoutAnimation(_ change: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    change()
    CATransaction.commit()
}

func capped(_ fps: Int) -> CAFrameRateRange {
    CAFrameRateRange(minimum: Float(min(6, fps)), maximum: Float(fps), preferred: Float(fps))
}
