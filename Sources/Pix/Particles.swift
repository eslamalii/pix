import AppKit
import AmbientCore

/// Draws rising Emote flights synchronously; callers retain ownership and completion transactions.
@MainActor
enum Particles {
    // CAEmitterLayer ignored the frame cap and tripled TouchBarServer CPU on battery; use pixel flights.
    /// `count` sprites rising from `origin` in `host`, staggered over `period`, each making `flights` flights (forever
    /// by default). Inside a Moment they must end: the Moment ends when everything it started has.
    static func draw(_ sprite: String, count: Int, every period: Double, from origin: CGPoint, in host: CALayer?,
                     rise: CGFloat = 8, life: Double = 2, flights: Float = .infinity, fps: Int, art: ArtFiles = ArtFiles()) -> [CALayer] {
        guard let host else { return [] }
        return (0..<count).map { i in
            let particle = pixelCrisp(art.image("emotes"))
            particle.contentsRect = emoteSlot(sprite)
            particle.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
            particle.position = origin
            particle.opacity = 0  // invisible between flights
            let sway = CGFloat.random(in: 2...6) * (Bool.random() ? 1 : -1)
            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = [origin, CGPoint(x: origin.x + sway / 2, y: origin.y + rise / 2), CGPoint(x: origin.x + sway, y: origin.y + rise)]
                .map { NSValue(point: $0) }
            move.duration = life
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.15, 0.6, 1]
            fade.duration = life
            let flight = CAAnimationGroup()
            flight.animations = [move, fade]
            flight.duration = max(period, life)
            flight.repeatCount = flights
            flight.beginTime = CACurrentMediaTime() + Double(i) * period / Double(count)
            flight.preferredFrameRateRange = capped(fps)
            particle.add(flight, forKey: "flight")
            host.addSublayer(particle)
            return particle
        }
    }

}
