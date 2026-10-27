import AppKit
import Testing
import AmbientCore
@testable import Pix

/// A PixView with its scene built, on a window of its own. The view holds its window weakly: keep the window.
@MainActor
func builtView() async throws -> (view: PixView, window: NSWindow) {
    let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30))
    let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = view
    view.show(Room(spot: .window, activity: .other, mood: .sleepy, fps: 12))
    for _ in 0..<50 where layer("world", of: view) == nil { try await Task.sleep(for: .milliseconds(10)) }
    return (view, window)
}

/// A named host in the rendered Room.
@MainActor
func layer(_ name: String, of view: PixView) -> CALayer? {
    func find(in host: CALayer) -> CALayer? {
        if host.name == name { return host }
        return host.sublayers?.lazy.compactMap { find(in: $0) }.first
    }
    return view.layer.flatMap { find(in: $0) }
}

/// Zs, hearts and steam come and go while Pix walks and the Room scrolls. A fade there shows a ghost of Pix
/// where its walk ends, drawn from the layer's model state.
@MainActor
@Test(arguments: ["pix", "world"])
func particlesComingAndGoingDontFade(_ name: String) async throws {
    let (view, window) = try await builtView()
    let host = try #require(layer(name, of: view))
    let particle = CALayer()
    host.addSublayer(particle)
    particle.removeFromSuperlayer()
    #expect(host.animation(forKey: "transition") == nil)
    withExtendedLifetime(window) {}
}

/// The Status corner is outside the Room: a Prop scrolling under the clock or a caption is hidden, not drawn through.
@MainActor
@Test func theClockAndCaptionSitOnTheBarsOwnBlackOverTheRoom() async throws {
    let (view, window) = try await builtView()
    view.play(.agentDone)
    let corner = try #require(layer("statusCorner", of: view))
    let black = NSColor.black.cgColor
    for name in ["clock", "caption"] {
        let text = try #require(layer(name, of: view)).frame
        let under = corner.sublayers?.filter { $0.backgroundColor == black && $0.frame.contains(text) } ?? []
        #expect(!under.isEmpty, "nothing black under the \(name)")
    }
    withExtendedLifetime(window) {}
}

@MainActor
@Test func lampLightStaysAbovePixAfterBuildingTheRoom() async throws {
    let (view, window) = try await builtView()
    let world = try #require(layer("world", of: view))
    let pix = try #require(layer("pix", of: view))
    let glow = try #require(layer("lampGlow", of: view))
    let children = try #require(world.sublayers)
    let pixIndex = try #require(children.firstIndex(of: pix))
    let glowIndex = try #require(children.firstIndex(of: glow))
    #expect(pixIndex < glowIndex)
    withExtendedLifetime(window) {}
}

@MainActor
@Test func gazePastimeShowsSkyEvenWhenTheDestinationIsTheDesk() async throws {
    let zone = TimeZone(secondsFromGMT: 0)!
    let time = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!
    let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30),
                       routine: Routine(timeZone: zone), effects: RoutineEffects(now: { time }, saveGarden: { _ in }), timeZone: zone)
    let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = view
    view.show(Room(spot: .desk, activity: .coding, mood: .content, fps: 12))
    view.play(.greeting(.hello, after: .gaze))
    for _ in 0..<50 where layer("world", of: view) == nil { try await Task.sleep(for: .milliseconds(10)) }
    let life = try #require(layer("skyLife", of: view))
    #expect(life.sublayers?.filter { $0.animation(forKey: "drift") != nil }.count == 3)
    view.hide()
    window.contentView = nil
    withExtendedLifetime(window) {}
}

@MainActor
@Test func minuteAndTimeZoneRefreshUseOneSampleForClockSkyAndRoutine() async throws {
    let zone = TimeZone(secondsFromGMT: 0)!
    var time = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!
    var reads = 0
    let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30),
                       routine: Routine(timeZone: zone), effects: RoutineEffects(now: { reads += 1; return time }, saveGarden: { _ in }), timeZone: zone)
    let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = view
    view.clockStyle = .twentyFourHour
    view.show(Room(spot: .window, activity: .other, mood: .focused, fps: 12))
    for _ in 0..<50 where layer("world", of: view) == nil { try await Task.sleep(for: .milliseconds(10)) }
    time += 3600
    let beforeMinute = reads
    view.refreshTime()
    #expect(reads == beforeMinute + 1)
    let beforeZone = reads
    view.timeZoneChanged(TimeZone(secondsFromGMT: 9 * 3600)!)
    #expect(reads == beforeZone + 1)
    let life = try #require(layer("skyLife", of: view))
    #expect(life.sublayers?.contains { $0.animation(forKey: "twinkle") != nil } == true)
    let clockContents = try #require(layer("clock", of: view)?.contents)
    let clock = clockContents as! CGImage
    let expected = try #require(pixelText("22:00", color: color(0x8f95a3)))
    #expect((clock.dataProvider?.data as Data?) == (expected.dataProvider?.data as Data?))
    view.hide()
    window.contentView = nil
    withExtendedLifetime(window) {}
}
