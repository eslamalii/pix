import AppKit
import AmbientCore

/// Halloween in the Room, in the Occasion season only (see AmbientCore's Halloween): its Occasion Props laid over each
/// strip, the jack-o'-lantern faces and candle flames flickering from dusk, and the moon and bats in the window at night.
/// The rest of the year it adds nothing. PixView holds one and calls it from three places; each of those lines ends "// Halloween".
@MainActor
final class HalloweenLayers {
    private var inSeason = false
    /// Halloween's place among the world's layers, over the Room and under Pix: it dresses and undresses in here.
    private weak var stage: CALayer?
    private var geometry: RoomGeometry?
    private var frameRange = CAFrameRateRange.default
    private weak var sky: CALayer?
    private var daylight: Daylight?
    private var props: [CALayer] = [], glows: [CALayer] = [], skyLife: [CALayer] = []

    /// Takes its place over the Room's strips, under Pix, and lays the Occasion Props there in the season.
    func build(in world: CALayer, geometry: RoomGeometry, frameRange: CAFrameRateRange) {
        let stage = CALayer()
        stage.frame = world.bounds
        world.addSublayer(stage)
        (self.stage, self.geometry, self.frameRange) = (stage, geometry, frameRange)
        (props, glows, skyLife) = ([], [], [])  // the last scene's went with its world
        inSeason = Halloween.inSeason(on: Date(), calendar: .current)
        if inSeason { dress() }
    }

    /// Every minute: the faces and flames glow from dusk until dawn, and the Room dresses or undresses the moment the
    /// season starts or ends, even with Pix on the bar at midnight.
    func paint(_ daylight: Daylight) {
        self.daylight = daylight
        let now = Halloween.inSeason(on: Date(), calendar: .current)
        if now != inSeason {
            inSeason = now
            if now { dress() } else { undress() }
            refillSky()
        }
        withoutAnimation { for glow in glows { glow.isHidden = daylight != .dusk && daylight != .night } }
    }

    private func dress() {
        guard let stage, let geometry else { return }
        withoutAnimation {
            for strip in Art.strips {
                let layer = Self.crisp(Self.image("room-\(strip)"))
                layer.frame = CGRect(x: geometry.stripX(strip), y: 0, width: CGFloat(Art.stripWidth), height: CGFloat(Art.height))
                stage.addSublayer(layer)
                props.append(layer)
            }
            for glow in Halloween.glows {
                let light = CALayer()
                light.frame = geometry.rect(glow.rect, on: glow.strip).insetBy(dx: -1, dy: -1)  // a point of light around it
                light.backgroundColor = CGColor(srgbRed: 1, green: 0.63, blue: 0.25, alpha: 0.3)  // amber, as the lamp's
                light.isHidden = true
                let flicker = CAKeyframeAnimation(keyPath: "opacity")
                flicker.values = [1, 0.5, 0.9, 0.6, 1]
                flicker.duration = .random(in: 1.2...2)
                flicker.repeatCount = .infinity
                flicker.timeOffset = .random(in: 0...2)
                flicker.preferredFrameRateRange = frameRange
                light.add(flicker, forKey: "flicker")
                stage.addSublayer(light)
                glows.append(light)
            }
        }
    }

    private func undress() {
        for layer in props + glows + skyLife { layer.removeFromSuperlayer() }
        (props, glows, skyLife) = ([], [], [])
    }

    /// The orange moon, and three bats flapping across the window, at night.
    func fillSky(_ daylight: Daylight, in sky: CALayer, frameRange: CAFrameRateRange) {
        (self.sky, self.daylight, skyLife) = (sky, daylight, [])  // PixView has just cleared the sky
        addSkyLife()
    }

    /// The season started or ended mid-night: the moon and bats come or go, if the window's sky is alive (stars in it).
    private func refillSky() {
        skyLife.forEach { $0.removeFromSuperlayer() }
        skyLife = []
        if sky?.sublayers?.isEmpty == false { addSkyLife() }
    }

    private func addSkyLife() {
        guard inSeason, daylight == .night, let sky else { return }
        let pane = sky.bounds
        let moon = Self.crisp(Self.image("moon"))
        moon.frame = CGRect(origin: CGPoint(x: pane.width * 0.72, y: pane.height - Halloween.moon.height - 3), size: Halloween.moon)
        sky.addSublayer(moon)
        skyLife.append(moon)
        let beats = [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)]
        for height: CGFloat in [0.75, 0.5, 0.62] {
            let bat = Self.crisp(Self.image("bat"))
            bat.bounds = CGRect(origin: .zero, size: Halloween.bat)
            bat.contentsRect = beats[0]
            let flap = CAKeyframeAnimation(keyPath: "contentsRect")
            flap.values = beats.map { NSValue(rect: $0) }
            flap.calculationMode = .discrete
            flap.duration = 0.4
            flap.repeatCount = .infinity
            flap.preferredFrameRateRange = frameRange
            let y = pane.height * height, wide = Halloween.bat.width
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.values = [CGPoint(x: -wide, y: y), CGPoint(x: pane.width / 2, y: y + 3), CGPoint(x: pane.width + wide, y: y - 1)]
                .map { NSValue(point: $0) }
            fly.duration = .random(in: 9...14)
            fly.repeatCount = .infinity
            fly.timeOffset = .random(in: 0...14)
            fly.preferredFrameRateRange = frameRange
            bat.add(flap, forKey: "flap")
            bat.add(fly, forKey: "fly")
            sky.addSublayer(bat)
            skyLife.append(bat)
        }
    }

    private func withoutAnimation(_ change: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        change()
        CATransaction.commit()
    }

    private static func image(_ name: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art/\(Halloween.folder)"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func crisp(_ image: CGImage?) -> CALayer {
        let layer = CALayer()
        layer.contents = image
        layer.magnificationFilter = .nearest
        return layer
    }
}
