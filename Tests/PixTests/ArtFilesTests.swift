import AppKit
import ImageIO
import Testing
import AmbientCore
@testable import Pix

private struct ArtFixture {
    let root: URL
    var classic: URL { root.appendingPathComponent("Classic") }
    var skin: URL { root.appendingPathComponent("Skin") }
    var other: URL { root.appendingPathComponent("Other") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pix-art-\(UUID().uuidString)")
        for folder in [classic, skin, other] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func draw(_ name: String, in folder: URL, width: Int, height: Int, shade: CGFloat = 0.5) throws {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: shade, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let file = folder.appendingPathComponent(Art.file(name))
        let destination = try #require(CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}

@MainActor
@Test func shortSkinHatSheetResolvesDrawnCellsAndFallsBackForOmittedHats() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("hats", in: fixture.classic, width: Art.hats.count * 16, height: 6)
    try fixture.draw("hats", in: fixture.skin, width: 32, height: 6)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    let beanie = try #require(art.hat(.beanie))
    #expect(beanie.image.width == 32)
    #expect(beanie.rect == CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    let crown = try #require(art.hat(.crown))
    #expect(crown.image.width == Art.hats.count * 16)
    #expect(crown.rect == CGRect(x: 4.0 / 9, y: 0, width: 1.0 / 9, height: 1))
}

@MainActor
@Test(arguments: [(31, 6), (32, 7), (160, 6)])
func invalidSkinHatSheetsUseClassic(size: (Int, Int)) throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("hats", in: fixture.classic, width: 144, height: 6)
    try fixture.draw("hats", in: fixture.skin, width: size.0, height: size.1)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    let hat = try #require(art.hat(.cap))
    #expect(hat.image.width == 144)
    #expect(hat.rect.width == 1.0 / 9)
}

@MainActor
@Test func missingAndUnreadableSkinFilesFallBackAndMissingClassicReturnsNil() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("hats", in: fixture.classic, width: 144, height: 6)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    #expect(art.hat(.cap)?.image.width == 144)
    try Data("not a png".utf8).write(to: fixture.other.appendingPathComponent("hats.png"))
    art.skin = fixture.other
    #expect(art.hat(.cap)?.image.width == 144)
    #expect(ArtFiles(classicFolder: nil, skin: fixture.skin).hat(.cap) == nil)
}

@MainActor
@Test func changingSkinInvalidatesResolvedHatAndImageCaches() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("hats", in: fixture.classic, width: 144, height: 6)
    try fixture.draw("hats", in: fixture.skin, width: 16, height: 6)
    try fixture.draw("hats", in: fixture.other, width: 32, height: 6)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    let first = try #require(art.image("hats"))
    #expect(art.hat(.cap)?.image === first)
    art.skin = fixture.other
    #expect(art.hat(.cap)?.image.width == 32)
    art.skin = nil
    #expect(art.hat(.cap)?.image.width == 144)
}

@MainActor
@Test func skinBodyCanChangeFrameCountWhileRoomDrawingsMustKeepTheirSize() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("pix-walk", in: fixture.classic, width: 48, height: 24)
    try fixture.draw("pix-walk", in: fixture.skin, width: 72, height: 24)
    try fixture.draw("room-desk", in: fixture.classic, width: Art.stripWidth, height: Art.height)
    try fixture.draw("room-desk", in: fixture.skin, width: 30, height: Art.height)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    #expect(art.image("pix-walk")?.width == 72)
    #expect(art.image("room-desk")?.width == Art.stripWidth)
}

@MainActor
@Test func playbackUsesResolvedHatAndKeepsBodyWearability() throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    try fixture.draw("hats", in: fixture.classic, width: 144, height: 6)
    try fixture.draw("hats", in: fixture.skin, width: 16, height: 6)
    let art = ArtFiles(classicFolder: fixture.classic, skin: fixture.skin)
    let playback = Playback(art: art)
    let world = CALayer()
    playback.hat = .crown
    playback.build(in: world, geometry: RoomGeometry(barWidth: CGFloat(Art.stripWidth)), at: .desk, mood: .content)
    let hat = try #require(playback.pix.sublayers?.first { $0.name == "hat" })
    #expect(hat.contentsRect == CGRect(x: 4.0 / 9, y: 0, width: 1.0 / 9, height: 1))
    #expect(!hat.isHidden)
    playback.run(.idle(.call, .content))
    #expect(hat.isHidden)
    playback.run(.idle(.desk, .content))
    #expect(!hat.isHidden)
    playback.stop()
    withExtendedLifetime(world) {}
}

@MainActor
@Test func roomSkinRebuildUsesOneArtSourceAndLeavesAnotherRoomAlone() async throws {
    let fixture = try ArtFixture()
    defer { fixture.remove() }
    let drawings = Art.bodies.map { ("pix-" + $0.name, Art.frame, Art.frame) } + [
        ("pix-face", Art.faces.count * 10, 7), ("emotes", Art.emotes.count * Art.emote, Art.emote),
        ("hats", Art.hats.count * 16, 6), ("room-desk", Art.stripWidth, Art.height),
        ("room-window", Art.stripWidth, Art.height), ("mug-gone", 4, 4),
        ("plant-thirsty", Art.plantProps.count * 12, 19), ("cloud", 16, 6)
    ]
    for (name, width, height) in drawings {
        try fixture.draw(name, in: fixture.classic, width: width, height: height, shade: 0.2)
        try fixture.draw(name, in: fixture.skin, width: width, height: height, shade: 0.7)
        // A partial second Skin must fall back for Props and Room strips.
        if name.hasPrefix("pix-") || name == "emotes" {
            try fixture.draw(name, in: fixture.other, width: width, height: height, shade: 0.9)
        }
    }
    let zone = TimeZone(secondsFromGMT: 0)!
    let time = ISO8601DateFormatter().date(from: "2026-10-21T12:00:00Z")!
    let art = ArtFiles(classicFolder: fixture.classic)
    let otherArt = ArtFiles(classicFolder: fixture.classic)
    func makeView(_ art: ArtFiles) -> (PixView, NSWindow) {
        let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30),
                           routine: Routine(timeZone: zone), effects: RoutineEffects(now: { time }, saveGarden: { _ in }),
                           timeZone: zone, art: art)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        view.show(Room(spot: .window, activity: .other, mood: .focused, fps: 12))
        return (view, window)
    }
    let (view, window) = makeView(art)
    let (otherView, otherWindow) = makeView(otherArt)
    defer {
        view.hide()
        otherView.hide()
        window.contentView = nil
        otherWindow.contentView = nil
    }
    // Selecting a Skin before the first build uses the same path as changing it later.
    view.skin = fixture.skin
    for _ in 0..<50 where layer("world", of: view) == nil || layer("world", of: otherView) == nil {
        try await Task.sleep(for: .milliseconds(10))
    }
    func verify(_ view: PixView, art: ArtFiles) throws {
        let world = try #require(layer("world", of: view))
        let pix = try #require(layer("pix", of: view))
        let strips = try #require(world.sublayers?.filter { $0.name == "roomStrip" })
        let cloud = try #require(layer("skyLife", of: view)?.sublayers?.first { $0.animation(forKey: "drift") != nil })
        let body = try #require(pix.sublayers?.first { $0.animation(forKey: "frames") != nil })
        let face = try #require(pix.sublayers?.first { $0.animation(forKey: "blink") != nil })
        let mug = try #require(layer("mugGone", of: view))
        let plant = try #require(layer("thirstyPlant", of: view))
        let caption = try #require(layer("captionIcon", of: view))
        for (drawing, name) in [(strips[0], "room-desk"), (strips[1], "room-window"),
                                (body, "pix-walk"), (face, "pix-face"), (mug, "mug-gone"),
                                (plant, "plant-thirsty"), (cloud, "cloud"), (caption, "emotes")] {
            let image = try #require(drawing.contents) as! CGImage
            #expect(image === art.image(name))
        }
    }
    try verify(view, art: art)
    try verify(otherView, art: otherArt)
    let otherWorld = try #require(layer("world", of: otherView))
    let otherMugImage = try #require(layer("mugGone", of: otherView)?.contents) as! CGImage
    for skin in [fixture.other, nil] as [URL?] {
        let previous = try #require(layer("world", of: view))
        view.skin = skin
        for _ in 0..<50 where layer("world", of: view) == nil || layer("world", of: view) === previous {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(previous.superlayer == nil)
        try verify(view, art: art)
        #expect(layer("world", of: otherView) === otherWorld)
        #expect((layer("mugGone", of: otherView)?.contents as! CGImage) === otherMugImage)
        #expect(otherArt.skin == nil)
        let fallback = try #require(art.image("mug-gone"))
        #expect((fallback.dataProvider?.data as Data?) == (otherMugImage.dataProvider?.data as Data?))
    }
    withExtendedLifetime((window, otherWindow)) {}
}
