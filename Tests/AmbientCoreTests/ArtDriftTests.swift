import Foundation
import ImageIO
import Testing
@testable import AmbientCore

// Every art name AmbientCore hands the view must be in the art contract, and every sheet in the contract must be drawn:
// an unknown name doesn't fail on the Touch Bar, it just plays at the wrong speed or shows the wrong Emote.

let everyMoment: [Moment] = [Reaction.allCases.map(Moment.reaction), Break.allCases.map(Moment.pause), Greeting.allCases.map { Moment.greeting($0) },
                             [.charging, .focusStarted, .focusDone, .agentAsks, .agentDone, .agentFailed, .newHat, .overheated]].flatMap { $0 }

/// Adding a Moment or an Errand stops this compiling until it's in the lists above and below.
private func listed(_ moment: Moment, _ errand: Errand) -> Bool {
    switch moment {
    case .reaction, .pause, .greeting, .charging, .focusStarted, .focusDone, .agentAsks, .agentDone, .agentFailed, .newHat, .overheated: break
    }
    switch errand { case .switchLamp, .waterPlant, .refillMug: return true }
}

let everyRoom: [Room] = Spot.allCases.flatMap { spot in
    Mood.allCases.flatMap { mood in [false, true].map { Room(spot: spot, activity: .other, mood: mood, fps: 12, agentWorking: $0, hot: $0) } }
}

let bodies = Set(Art.bodies.map(\.name))

@Test(arguments: everyMoment)
func everyMomentIsDrawnFromTheArtContract(moment: Moment) {
    let look = moment.look
    #expect(bodies.contains(look.body), "body \(look.body)")
    for emote in [look.emote, look.caption.emote].compactMap({ $0 }) { #expect(Art.emotes.contains(emote), "emote \(emote)") }
}

@Test func everyRestLookIsDrawnFromTheArtContract() {
    for room in everyRoom {
        let look = RestLook(spot: room.spot, mood: room.mood, agentWorking: room.agentWorking, hot: room.hot)
        if let body = look.body { #expect(bodies.contains(body), "body \(body)") }
        for sprite in look.particles { #expect(Art.emotes.contains(sprite), "particle \(sprite)") }
    }
}

@Test func everyFidgetErrandAndStrollStopIsABody() {
    for fidget in Fidget.allCases where fidget != .refill { #expect(bodies.contains(fidget.rawValue), "fidget \(fidget)") }  // refill is an Errand
    #expect(Set(everyRoom.flatMap { room in [Fidget.sip, .refill].flatMap { Routine.fidgets(for: room, coffee: $0) } }) == Set(Fidget.allCases))
    for errand in [Errand.switchLamp, .waterPlant(deskPlant), .refillMug] { #expect(bodies.contains(errand.body), "errand \(errand.body)") }
    for end in [WindowEnd.left, .right] { if let body = end.stopBody { #expect(bodies.contains(body), "stroll stop \(body)") } }
}

@Test func bothWalkBodiesAreInTheArtContract() {
    for mugAway in [false, true] {
        let body = Props(lampLit: false, mugAway: mugAway, mugSteams: false).walkBody
        #expect(bodies.contains(body), "walk body \(body)")
    }
}

@Test func everySheetInTheArtContractIsDrawn() {
    let art = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Art").standardized
    let sheets = Art.strips.map { "room-\($0)" } + Art.bodies.map { "pix-\($0.name)" } + ["pix-face", "emotes", "hats", "cloud", "mug-gone", "plant-thirsty"]
    for sheet in sheets {
        #expect(FileManager.default.fileExists(atPath: art.appendingPathComponent(Art.file(sheet)).path), "missing Art/\(Art.file(sheet))")
    }
}

@Test func thePlantThirstySheetHasOneCellPerPlantInTheRoom() throws {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Art").standardized
        .appendingPathComponent(Art.file("plant-thirsty"))
    let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(Art.plantProps.map(\.x) == [404, 730, 678])  // desk, desk, window: the order of the cells
    #expect(image.width == Art.plantProps.count * Int(Art.plant.width))
    #expect(image.height == Int(Art.plant.height))
}

@Test func everyPastimeIsDrawnFromTheArtContract() {
    for pastime in Pastime.allCases { #expect(bodies.contains(pastime.body), "pastime \(pastime) body \(pastime.body)") }
}

// MARK: - The day's Occasion Props

/// An image in Art/, as drawn.
private func artImage(_ name: String) throws -> CGImage {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Art").standardized
        .appendingPathComponent(Art.file(name))
    let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil), "missing Art/\(Art.file(name))")
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

/// How many pixels of `image` inside `rect` (top-left origin) are drawn, not transparent.
private func drawnPixels(of image: CGImage, in rect: CGRect) -> Int {
    let (w, h) = (image.width, image.height)
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var drawn = 0
    for y in Int(rect.minY)..<Int(rect.maxY) { for x in Int(rect.minX)..<Int(rect.maxX) where pixels[(y * w + x) * 4 + 3] > 0 { drawn += 1 } }
    return drawn
}

private func cell(_ stop: (strip: String, x: Int, y: Int)) -> CGRect {
    CGRect(x: stop.x, y: stop.y, width: Art.occasionProp, height: Art.occasionProp)
}

@Test func everyStopsCellLiesInsideItsStrip() {
    let strip = CGRect(x: 0, y: 0, width: Art.stripWidth, height: Art.height)
    for stop in Art.occasionStops {
        #expect(Art.strips.contains(stop.strip), "stop on \(stop.strip)")
        #expect(strip.contains(cell(stop)), "stop at \(stop.x), \(stop.y)")
    }
}

@Test func halloweensSeasonPropsLeaveEveryStopClear() throws {
    // On October 31 both stand in the Room: a day's Occasion Prop must never be drawn over the season's.
    for stop in Art.occasionStops {
        let season = try artImage("\(Halloween.folder)/room-\(stop.strip)")
        #expect(drawnPixels(of: season, in: cell(stop)) == 0, "stop at \(stop.x), \(stop.y)")
    }
}

@Test(arguments: Occasion.allCases)
func everyOccasionHasOneDrawnCellPerStop(occasion: Occasion) throws {
    let sheet = try artImage(Art.occasionPropSheet(occasion.rawValue))
    #expect(sheet.width == Art.occasionStops.count * Art.occasionProp)
    #expect(sheet.height == Art.occasionProp)
    for stop in Art.occasionStops.indices {
        let cell = CGRect(x: stop * Art.occasionProp, y: 0, width: Art.occasionProp, height: Art.occasionProp)
        #expect(drawnPixels(of: sheet, in: cell) > 0, "nothing drawn at stop \(stop)")
    }
}
