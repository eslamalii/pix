import CoreGraphics
import Foundation
import ImageIO
import Testing
import AmbientCore

// Halloween's Occasion season, and its Occasion Props: drawn, and where the art contract says.

private func date(_ month: Int, _ day: Int, _ hour: Int = 12, in zone: String = "UTC") -> (Date, Calendar) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return (calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!, calendar)
}

@Test func theSeasonRunsFromOctober24ThroughNovember1() {
    for (month, day) in [(10, 24), (10, 28), (10, 31), (11, 1)] {
        let (time, calendar) = date(month, day)
        #expect(Halloween.inSeason(on: time, calendar: calendar), "\(month)/\(day)")
    }
}

@Test func theRoomIsItselfTheRestOfTheYear() {
    for (month, day) in [(10, 23), (11, 2), (10, 1), (9, 30), (12, 25), (1, 1)] {
        let (time, calendar) = date(month, day)
        #expect(!Halloween.inSeason(on: time, calendar: calendar), "\(month)/\(day)")
    }
}

@Test func theSeasonStartsAndEndsAtTheUsersMidnight() {
    let (lastHourBefore, tokyo) = date(10, 23, 23, in: "Asia/Tokyo")
    #expect(!Halloween.inSeason(on: lastHourBefore, calendar: tokyo))
    #expect(Halloween.inSeason(on: lastHourBefore.addingTimeInterval(3600), calendar: tokyo))
    // The same instant is still October 23 further west.
    var losAngeles = Calendar(identifier: .gregorian)
    losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    #expect(!Halloween.inSeason(on: lastHourBefore.addingTimeInterval(3600), calendar: losAngeles))
    let (lastHour, _) = date(11, 1, 23, in: "Asia/Tokyo")
    #expect(Halloween.inSeason(on: lastHour, calendar: tokyo))
    #expect(!Halloween.inSeason(on: lastHour.addingTimeInterval(3600), calendar: tokyo))
}

private let art = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Art").standardized
    .appendingPathComponent(Halloween.folder)

private func image(_ name: String) -> CGImage? {
    CGImageSourceCreateWithURL(art.appendingPathComponent(Art.file(name)) as CFURL, nil)
        .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
}

/// Whether the image has a drawn (not clear) pixel in the column range, on any row.
private func drawn(_ image: CGImage, columns: Range<Int>) -> Bool {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return (0..<height).contains { y in columns.contains { x in pixels[(y * width + x) * 4 + 3] > 0 } }
}

@Test func everyStripHasAHalloweenLayerTheSizeOfTheRoom() {
    for strip in Art.strips {
        let layer = image("room-\(strip)")
        #expect(layer?.width == Art.stripWidth && layer?.height == Art.height, "Art/\(Halloween.folder)/room-\(strip).png")
    }
    #expect(image("moon").map { CGSize(width: $0.width, height: $0.height) } == Halloween.moon)
    #expect(image("bat").map { CGSize(width: $0.width, height: $0.height) } == CGSize(width: Halloween.bat.width * 2, height: Halloween.bat.height))
}

@Test func everyOccasionPropIsDrawnWhereTheContractPutsIt() {
    for prop in Halloween.props {
        #expect(Art.strips.contains(prop.strip), "\(prop.name) on \(prop.strip)")
        #expect(prop.x >= 0 && prop.x < Art.stripWidth && (prop.y ?? 0) >= 0 && (prop.y ?? 0) < Art.height, "\(prop.name) at \(prop.x)")
        guard let layer = image("room-\(prop.strip)") else { continue }
        #expect(drawn(layer, columns: prop.x..<min(prop.x + 3, Art.stripWidth)), "\(prop.name) at x \(prop.x) on \(prop.strip)")
    }
}

@Test func everyGlowLightsSomethingDrawn() {
    for glow in Halloween.glows {
        #expect(Art.strips.contains(glow.strip))
        guard let layer = image("room-\(glow.strip)") else { continue }
        #expect(drawn(layer, columns: Int(glow.rect.minX)..<Int(glow.rect.maxX)), "glow at x \(glow.rect.minX) on \(glow.strip)")
    }
}
