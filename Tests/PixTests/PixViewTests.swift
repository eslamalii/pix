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

/// One of the view's private layers.
@MainActor
func layer(_ name: String, of view: PixView) -> CALayer? {
    Mirror(reflecting: view).children.first { $0.label == name }?.value as? CALayer
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
