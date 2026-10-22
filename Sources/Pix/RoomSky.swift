import AppKit
import AmbientCore

/// The sky's colors for each time of day.
private extension Daylight {
    var sky: (top: UInt32, bottom: UInt32) {
        switch self {
        case .dawn: (0x6e5aa8, 0xffb37a)
        case .day: (0x4aa3ff, 0xbfe3ff)
        case .dusk: (0x5b3f8f, 0xff8a5c)
        case .night: (0x0b1026, 0x24305e)
        }
    }
}

/// Owns the visible window's sky and all conditions that invalidate its drawings.
/// Playback supplies visibility; the destination Spot never decides what is visible.
@MainActor
final class RoomSky {
    private struct Conditions: Equatable {
        var daylight: Daylight
        var snows: Bool
        var halloween: Bool
        var fps: Int
    }

    private let sky = CAGradientLayer(), skyBox = CALayer(), skyLife = CALayer()
    private let halloween: HalloweenLayers
    private let art: ArtFiles
    private var conditions: Conditions?
    private var drawn: Conditions?
    private var visible = false
    private var fps = 12
    private var frameRange: CAFrameRateRange { capped(fps) }

    init(halloween: HalloweenLayers, art: ArtFiles = ArtFiles()) {
        self.halloween = halloween
        self.art = art
    }

    func build(in world: CALayer, geometry: RoomGeometry) {
        skyBox.name = "skyBox"
        skyLife.name = "skyLife"
        skyBox.frame = geometry.rect(Art.windowPane, on: "window")
        skyBox.masksToBounds = true
        sky.frame = skyBox.bounds
        skyLife.frame = skyBox.bounds
        skyBox.sublayers = [sky, skyLife]
        world.addSublayer(skyBox)
        drawn = nil
    }

    func refresh(at time: Date, calendar: Calendar, fps: Int) {
        self.fps = fps
        let daylight = Daylight(hour: calendar.component(.hour, from: time))
        conditions = Conditions(daylight: daylight, snows: Occasion.snows(inMonth: calendar.component(.month, from: time)),
                                halloween: Halloween.inSeason(on: time, calendar: calendar), fps: fps)
        withoutAnimation { sky.colors = [color(daylight.sky.bottom), color(daylight.sky.top)] }
        halloween.paint(daylight, at: time, calendar: calendar, frameRange: frameRange)
        drawIfNeeded()
    }

    func show(_ visible: Bool) {
        self.visible = visible
        if visible {
            drawIfNeeded()
        } else {
            skyLife.sublayers = nil
            drawn = nil
        }
    }

    func stop() {
        show(false)
        skyBox.removeFromSuperlayer()
        conditions = nil
    }

    private func drawIfNeeded() {
        guard visible, let conditions, conditions != drawn else { return }
        fillSky(for: conditions.daylight)
        drawn = conditions
    }

    /// Stars and a rare shooting star at night, drifting clouds by day, and snow in winter, clipped to the window pane.
    private func fillSky(for daylight: Daylight) {
        skyLife.sublayers = nil
        let pane = skyBox.bounds
        switch daylight {
        case .night:
            for _ in 0..<Int(pane.width / 20) {  // one star per 20 points of window
                let star = pixelCrisp(art.image("emotes"))
                star.contentsRect = emoteSlot("star")
                star.frame = CGRect(x: .random(in: 0...(pane.width - 8)), y: .random(in: 4...(pane.height - 8)), width: 8, height: 8)
                let twinkle = CAKeyframeAnimation(keyPath: "opacity")
                twinkle.values = [0.3, 1, 0.3]
                twinkle.duration = .random(in: 2...5)
                twinkle.repeatCount = .infinity
                twinkle.timeOffset = .random(in: 0...5)
                twinkle.preferredFrameRateRange = frameRange
                star.add(twinkle, forKey: "twinkle")
                skyLife.addSublayer(star)
            }
            let streak = CALayer()
            streak.bounds = CGRect(x: 0, y: 0, width: 4, height: 1)
            streak.backgroundColor = color(0xffffff)
            streak.opacity = 0
            let every = Double.random(in: 90...120)  // a rare treat, for under a second
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.values = [CGPoint(x: pane.width * 0.2, y: pane.height - 2), CGPoint(x: pane.width * 0.6, y: 4), CGPoint(x: pane.width * 0.6, y: 4)]
            fly.keyTimes = [0, 0.007, 1]
            fly.duration = every
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 0, 0]
            fade.keyTimes = [0, 0.007, 1]
            fade.duration = every
            let shooting = CAAnimationGroup()
            shooting.animations = [fly, fade]
            shooting.duration = every
            shooting.repeatCount = .infinity
            shooting.timeOffset = .random(in: 0...every)
            shooting.preferredFrameRateRange = frameRange
            streak.add(shooting, forKey: "shooting")
            skyLife.addSublayer(streak)
        case .day, .dawn:
            for i in 0..<3 {
                let cloud = pixelCrisp(art.image("cloud"))
                cloud.frame = CGRect(x: 0, y: CGFloat(4 + i * 4), width: Art.cloud.width, height: Art.cloud.height)
                let drift = CABasicAnimation(keyPath: "position.x")
                drift.fromValue = -Art.cloud.width
                drift.toValue = pane.width + Art.cloud.width
                drift.duration = .random(in: 50...90)
                drift.repeatCount = .infinity
                drift.timeOffset = .random(in: 0...90)
                drift.preferredFrameRateRange = frameRange
                cloud.add(drift, forKey: "drift")
                skyLife.addSublayer(cloud)
            }
        case .dusk:
            break
        }
        if conditions?.snows == true { letItSnow(in: pane) }
        halloween.fillSky(daylight, in: skyLife, frameRange: frameRange)  // Halloween
    }

    /// Flakes drifting down past the window: one per 24 points of it, or per 48 below full frame rate (on battery).
    private func letItSnow(in pane: CGRect) {
        for _ in 0..<Int(pane.width / (fps < 12 ? 48 : 24)) {
            let flake = CALayer()
            flake.bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
            flake.backgroundColor = color(0xffffff, 0.85)
            let x = CGFloat.random(in: 0...pane.width)
            let fall = CAKeyframeAnimation(keyPath: "position")
            fall.values = [CGPoint(x: x, y: pane.height + 1), CGPoint(x: x + .random(in: -3...3), y: pane.height / 2), CGPoint(x: x, y: -1)]
                .map { NSValue(point: $0) }
            fall.duration = .random(in: 6...10)
            fall.repeatCount = .infinity
            fall.timeOffset = .random(in: 0...10)
            fall.preferredFrameRateRange = frameRange
            flake.add(fall, forKey: "fall")
            skyLife.addSublayer(flake)
        }
    }

}
