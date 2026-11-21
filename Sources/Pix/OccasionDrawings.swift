import AppKit
import AmbientCore

/// The Room's Occasion drawings: it decides the Occasion season once, from the time and calendar it is given, dresses
/// and undresses the Room, and supplies the window's sky treats. The season is Halloween's (see AmbientCore's Halloween):
/// its Occasion Props laid over each strip, the jack-o'-lantern faces and candle flames flickering from dusk, and the
/// moon and bats in the window at night. It also draws the day's Occasion Props on their Perches, as Pix places them on
/// its Occasion tour, each with a glow from dusk, and gives the window the day's own night-sky treat; at the day's end
/// they go and its art is dropped.
/// RoomSky owns the window sky lifetime and never names an Occasion.
@MainActor
final class OccasionDrawings {
    /// What the window's sky treats are now, held by RoomSky only to compare and hand back to `fillSky`.
    struct SkyTreats: Equatable {
        fileprivate enum Season { case halloween }
        fileprivate let season: Season?
        fileprivate let occasion: Occasion?
    }

    private let art: ArtFiles
    private var inSeason = false
    /// The Occasion drawings' place among the world's layers, over the Room and under Pix: it dresses and undresses in here.
    private weak var stage: CALayer?
    private var geometry: RoomGeometry?
    private var frameRange = CAFrameRateRange.default
    private var props: [CALayer] = [], glows: [CALayer] = []
    /// The day's Occasion Props, one layer per Perch, and whose they are.
    private var perchProps: [CALayer] = []
    private var perchOccasion: Occasion?
    private var perchGlows: [CALayer] = []
    /// How many Perches' Props show.
    private var perchesShown = 0
    /// Dusk or night: dark enough for the glows.
    private var dark = false

    init(art: ArtFiles = ArtFiles()) { self.art = art }

    /// Takes its place over the Room's strips, under Pix, and lays the Occasion Props there in the season.
    func build(in world: CALayer, geometry: RoomGeometry, frameRange: CAFrameRateRange) {
        let stage = CALayer()
        stage.name = "occasionProps"
        stage.frame = world.bounds
        world.addSublayer(stage)
        (self.stage, self.geometry, self.frameRange) = (stage, geometry, frameRange)
        if let over = perchOccasion { art.dropOccasionPropSheet(over) }  // a Room rebuilt after the day ended
        (props, glows, perchProps, perchGlows, perchOccasion) = ([], [], [], [], nil)  // the last Room's drawings went with it
        inSeason = false
    }

    /// The day's Occasion Props: all four Perches' layers while today is an Occasion, the first `occasionPropsShown` visible;
    /// none otherwise.
    func update(_ props: Props) {
        guard let stage, let geometry else { return }
        if perchOccasion != props.occasion {
            (perchProps + perchGlows).forEach { $0.removeFromSuperlayer() }
            if let over = perchOccasion { art.dropOccasionPropSheet(over) }  // the day's art leaves with the day
            perchOccasion = props.occasion
            (perchProps, perchGlows) = ([], [])
            if let occasion = props.occasion {
                let sheet = art.occasionPropSheet(occasion)
                withoutAnimation {
                    perchProps = Art.perches.indices.map { perch in
                        let layer = pixelCrisp(sheet)
                        layer.name = "occasionProp"
                        layer.frame = geometry.occasionPropRect(perch: perch)
                        layer.contentsRect = slot(perch, of: Art.perches.count)
                        layer.isHidden = true
                        stage.addSublayer(layer)
                        return layer
                    }
                    perchGlows = Art.perches.indices.map { perch in
                        let light = perchGlow(for: occasion, around: geometry.occasionPropRect(perch: perch))
                        stage.addSublayer(light)
                        return light
                    }
                }
            }
        }
        perchesShown = props.occasionPropsShown
        withoutAnimation {
            for (perch, layer) in perchProps.enumerated() { layer.isHidden = perch >= perchesShown }
            showPerchGlows()
        }
    }

    /// A placed Prop glows from dusk until dawn.
    private func showPerchGlows() {
        for (perch, light) in perchGlows.enumerated() { light.isHidden = perch >= perchesShown || !dark }
    }

    /// A glow for one of the Occasion's Props: a flickering amber for Halloween's, twinkling warm lights for the holidays',
    /// quick gold sparkles for the New Year's.
    private func perchGlow(for occasion: Occasion, around rect: CGRect) -> CALayer {
        let light = switch occasion {
        case .halloween: pointOfLight(in: rect, color(0xffa140, 0.3), [1, 0.5, 0.9, 0.6, 1], 1.2...2, key: "flicker")
        case .holidays: pointOfLight(in: rect, color(0xff7360, 0.3), [1, 0.3, 0.8, 0.3, 1], 1.5...2.5, key: "twinkle")
        case .newYear: pointOfLight(in: rect, color(0xffd24d, 0.35), [0.4, 1, 0.5, 1, 0.4], 0.6...1, key: "sparkle")
        }
        light.name = "occasionGlow"
        return light
    }

    /// A point of light around `rect`, hidden until shown, its opacity cycling through `values` forever.
    private func pointOfLight(in rect: CGRect, _ tint: CGColor, _ values: [Double], _ length: ClosedRange<Double>, key: String) -> CALayer {
        let light = CALayer()
        light.frame = rect.insetBy(dx: -1, dy: -1)
        light.backgroundColor = tint
        light.isHidden = true
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values
        animation.duration = .random(in: length)
        animation.repeatCount = .infinity
        animation.timeOffset = .random(in: 0...2)
        animation.preferredFrameRateRange = frameRange
        light.add(animation, forKey: key)
        return light
    }

    /// Every minute: the faces and flames glow from dusk until dawn, and the Room dresses or undresses the moment the
    /// season starts or ends, even with Pix on the bar at midnight. Returns the sky's treats now (nil out of season), to
    /// hand to `fillSky` once the sky draws.
    func paint(_ daylight: Daylight, at time: Date, calendar: Calendar, frameRange: CAFrameRateRange) -> SkyTreats? {
        self.frameRange = frameRange
        let now = Halloween.inSeason(on: time, calendar: calendar)
        if now != inSeason {
            inSeason = now
            if now { dress() } else { undress() }
        }
        dark = daylight == .dusk || daylight == .night
        withoutAnimation {
            for glow in glows { glow.isHidden = !dark }
            showPerchGlows()
        }
        let occasion = Occasion(on: time, calendar: calendar)
        return inSeason || occasion != nil ? SkyTreats(season: inSeason ? .halloween : nil, occasion: occasion) : nil
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
                let light = pointOfLight(in: geometry.rect(glow.rect, on: glow.strip), color(0xffa140, 0.3), [1, 0.5, 0.9, 0.6, 1], 1.2...2, key: "flicker")
                stage.addSublayer(light)
                glows.append(light)
            }
        }
    }

    private func undress() {
        for layer in props + glows { layer.removeFromSuperlayer() }
        (props, glows) = ([], [])
    }

    /// The window's treats at night: the season's moon and bats, and the Occasion's own.
    func fillSky(_ treats: SkyTreats?, at daylight: Daylight, in sky: CALayer, frameRange: CAFrameRateRange) {
        guard let treats, daylight == .night else { return }
        if treats.season == .halloween { moonAndBats(in: sky, frameRange: frameRange) }
        switch treats.occasion {
        case .holidays?: coloredLights(in: sky, frameRange: frameRange)
        case .newYear?: fireworks(in: sky, frameRange: frameRange)
        case .halloween?, nil: break  // Halloween's is the season's
        }
    }

    /// A string of twinkling coloured lights across the top of the pane.
    private func coloredLights(in sky: CALayer, frameRange: CAFrameRateRange) {
        let palette: [UInt32] = [0xff5a4d, 0xffd24d, 0x5ad17a, 0x5aa8ff]
        for n in 0..<Int(sky.bounds.width / 8) {
            let bulb = CALayer()
            bulb.frame = CGRect(x: CGFloat(n * 8 + 3), y: sky.bounds.height - 4, width: 2, height: 2)
            bulb.backgroundColor = color(palette[n % palette.count])
            let twinkle = CAKeyframeAnimation(keyPath: "opacity")
            twinkle.values = [1, 0.3, 1]
            twinkle.duration = .random(in: 1...2)
            twinkle.repeatCount = .infinity
            twinkle.timeOffset = .random(in: 0...2)
            twinkle.preferredFrameRateRange = frameRange
            bulb.add(twinkle, forKey: "bulb")
            sky.addSublayer(bulb)
        }
    }

    /// A few gold bursts, each swelling and fading, over and over.
    private func fireworks(in sky: CALayer, frameRange: CAFrameRateRange) {
        let pane = sky.bounds
        for (across, up) in [(0.2, 0.4), (0.5, 0.65), (0.8, 0.5)] as [(CGFloat, CGFloat)] {
            let burst = CALayer()
            burst.bounds = CGRect(x: 0, y: 0, width: 4, height: 4)
            burst.position = CGPoint(x: pane.width * across, y: pane.height * up)
            burst.backgroundColor = color(0xffd24d)
            let swell = CAKeyframeAnimation(keyPath: "transform.scale")
            swell.values = [0.2, 1.5, 1.5]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 0.8, 0]
            let group = CAAnimationGroup()
            group.animations = [swell, fade]
            group.duration = .random(in: 2...3)
            group.repeatCount = .infinity
            group.timeOffset = .random(in: 0...3)
            group.preferredFrameRateRange = frameRange
            burst.add(group, forKey: "burst")
            sky.addSublayer(burst)
        }
    }

    /// The orange moon, and three bats flapping across the window.
    private func moonAndBats(in sky: CALayer, frameRange: CAFrameRateRange) {
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
