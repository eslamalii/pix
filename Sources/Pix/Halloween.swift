import AppKit
import AmbientCore

/// Halloween in the Room, in the Occasion season only (see AmbientCore's Halloween): its Occasion Props laid over each
/// strip, the jack-o'-lantern faces and candle flames flickering from dusk, and the moon and bats in the window at night.
/// RoomSky supplies time and owns the window sky lifetime; this module keeps Halloween drawing rules.
@MainActor
final class HalloweenLayers {
    private let art: ArtFiles
    private var inSeason = false
    /// Halloween's place among the world's layers, over the Room and under Pix: it dresses and undresses in here.
    private weak var stage: CALayer?
    private var geometry: RoomGeometry?
    private var frameRange = CAFrameRateRange.default
    private var props: [CALayer] = [], glows: [CALayer] = []

    init(art: ArtFiles = ArtFiles()) { self.art = art }

    /// Takes its place over the Room's strips, under Pix, and lays the Occasion Props there in the season.
    func build(in world: CALayer, geometry: RoomGeometry, frameRange: CAFrameRateRange) {
        let stage = CALayer()
        stage.name = "occasionProps"
        stage.frame = world.bounds
        world.addSublayer(stage)
        (self.stage, self.geometry, self.frameRange) = (stage, geometry, frameRange)
        (props, glows) = ([], [])  // the last Room's drawings went with it
        inSeason = false
    }

    /// Every minute: the faces and flames glow from dusk until dawn, and the Room dresses or undresses the moment the
    /// season starts or ends, even with Pix on the bar at midnight.
    func paint(_ daylight: Daylight, at time: Date, calendar: Calendar, frameRange: CAFrameRateRange) {
        let capChanged = self.frameRange != frameRange
        self.frameRange = frameRange
        let now = Halloween.inSeason(on: time, calendar: calendar)
        if now != inSeason {
            inSeason = now
            if now { dress() } else { undress() }
        }
        if capChanged {
            for glow in glows {
                if let flicker = glow.animation(forKey: "flicker")?.copy() as? CAAnimation {  // an added animation is read-only
                    flicker.preferredFrameRateRange = frameRange
                    glow.add(flicker, forKey: "flicker")
                }
            }
        }
        withoutAnimation { for glow in glows { glow.isHidden = daylight != .dusk && daylight != .night } }
    }

    private func dress() {
        guard let stage, let geometry else { return }
        withoutAnimation {
            for strip in Art.strips {
                let layer = pixelCrisp(art.halloweenImage("room-\(strip)"))
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
        for layer in props + glows { layer.removeFromSuperlayer() }
        (props, glows) = ([], [])
    }

    /// The orange moon, and three bats flapping across the window, at night.
    func fillSky(_ daylight: Daylight, in sky: CALayer, frameRange: CAFrameRateRange) {
        guard inSeason, daylight == .night else { return }
        let pane = sky.bounds
        let moon = pixelCrisp(art.halloweenImage("moon"))
        moon.frame = CGRect(origin: CGPoint(x: pane.width * 0.72, y: pane.height - Halloween.moon.height - 3), size: Halloween.moon)
        sky.addSublayer(moon)
        let beats = [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)]
        for height: CGFloat in [0.75, 0.5, 0.62] {
            let bat = pixelCrisp(art.halloweenImage("bat"))
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
        }
    }
}
