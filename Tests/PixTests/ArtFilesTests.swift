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
