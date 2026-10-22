import AppKit
import Testing
@testable import Pix

@MainActor
@Test func finiteFlightsRespectLifetimeStaggerAndFrameCap() throws {
    let host = CALayer()
    let origin = CGPoint(x: 10, y: 12)
    let particles = Particles.draw("heart", count: 3, every: 0.45, from: origin, in: host,
                                   rise: 10, life: 1.6, flights: 1, fps: 6)
    #expect(host.sublayers == particles)
    let flights = try particles.map { try #require($0.animation(forKey: "flight") as? CAAnimationGroup) }
    for (particle, flight) in zip(particles, flights) {
        #expect(particle.position == origin && particle.opacity == 0)
        #expect(flight.duration == 1.6 && flight.repeatCount == 1)
        #expect(flight.preferredFrameRateRange.maximum == 6)
        #expect(flight.animations?.allSatisfy { $0.duration == 1.6 } == true)
    }
    #expect(abs((flights[1].beginTime - flights[0].beginTime) - 0.15) < 0.02)
    #expect(abs((flights[2].beginTime - flights[1].beginTime) - 0.15) < 0.02)
    let steam = Particles.draw("steam", count: 1, every: 12, from: origin, in: host, fps: 12)
    let flight = try #require(steam[0].animation(forKey: "flight") as? CAAnimationGroup)
    #expect(flight.duration == 12 && flight.repeatCount == .infinity)
}
