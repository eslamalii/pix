import AppKit
import Testing
@testable import AmbientCore
@testable import Pix

@MainActor
@Test func propsFollowRoutineAndCleanUpAcrossInterruptionsAndRebuilds() throws {
    let drawings = RoomProps()
    let world = CALayer(), pix = CALayer(), strip = CALayer(), occasion = CALayer()
    strip.name = "roomStrip"
    world.sublayers = [strip, occasion, pix]
    let geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    drawings.build(in: world, geometry: geometry)
    let plant = Plant(Art.plantProps[0])
    let props = Props(lampLit: true, mugAway: true, mugSteams: true, thirstyPlants: [plant])
    drawings.update(props, step: .idle(.desk, .content), fps: 12)
    let mug = try #require(drawings.patches.sublayers?.first { $0.name == "mugGone" })
    let glow = try #require(world.sublayers?.first { $0.name == "lampGlow" })
    let plants = drawings.patches.sublayers?.filter { $0.name == "thirstyPlant" } ?? []
    #expect(!mug.isHidden && !glow.isHidden)
    #expect(plants.filter { !$0.isHidden }.count == 1)
    let children = try #require(world.sublayers)
    let steam = try #require(children.first { $0.name == "deskSteam" })
    drawings.update(props, step: .idle(.desk, .content), fps: 12)
    #expect(steam.superlayer === world)
    drawings.update(props, step: .moment(.reaction(.pet)), fps: 12)
    #expect(steam.superlayer == nil)
    drawings.update(props, step: .idle(.desk, .content), fps: 6)
    let cappedSteam = try #require(world.sublayers?.first { $0.name == "deskSteam" })
    #expect(cappedSteam.animation(forKey: "flight")?.preferredFrameRateRange.maximum == 6)
    let rebuilt = CALayer(), rebuiltPix = CALayer()
    rebuilt.addSublayer(rebuiltPix)
    drawings.build(in: rebuilt, geometry: geometry)
    #expect(cappedSteam.superlayer == nil)
    #expect(mug.superlayer === drawings.patches && glow.superlayer === rebuilt)
    #expect(world.sublayers == [strip, occasion, pix])
    drawings.update(Props(lampLit: false, mugAway: false, mugSteams: false), step: .idle(.desk, .content), fps: 12)
    #expect(rebuilt.sublayers?.contains { $0.name == "deskSteam" } == false)
    #expect(drawings.patches.sublayers?.first { $0.name == "mugGone" }?.isHidden == true)
    drawings.stop()
    #expect(rebuilt.sublayers == [rebuiltPix])
}
