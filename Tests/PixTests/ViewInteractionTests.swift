import AppKit
import Testing
import AmbientCore
@testable import Pix

@MainActor
private final class ViewWaits {
    var refreshes: [@MainActor () -> Void] = []
    var taps: [@MainActor () -> Void] = []
    var cancellations = 0
    var timing: PixViewTiming {
        PixViewTiming(refresh: { self.refreshes.append($0) }, after: { seconds, work in
            #expect(seconds == 0.3)
            self.taps.append(work)
            return { self.cancellations += 1 }
        })
    }
    func flush() {
        let work = refreshes
        refreshes = []
        work.forEach { $0() }
    }
}

@MainActor
private func interactiveView(_ waits: ViewWaits) -> (PixView, NSWindow) {
    let zone = TimeZone(secondsFromGMT: 0)!
    let view = PixView(frame: CGRect(x: 0, y: 0, width: 1004, height: 30), routine: Routine(timeZone: zone),
                       effects: RoutineEffects(now: { Date(timeIntervalSince1970: 12 * 3600) },
                                               wake: { _, _ in {} }, saveGarden: { _ in }),
                       timeZone: zone, timing: waits.timing)
    let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = view
    view.show(Room(spot: .desk, activity: .coding, mood: .focused, fps: 12))
    waits.flush()
    return (view, window)
}

@MainActor
private func characterPoint(_ view: PixView) throws -> CGPoint {
    let pix = try #require(layer("pix", of: view))
    let world = try #require(layer("world", of: view))
    let rect = try #require(view.layer).convert(pix.frame, from: world)
    return CGPoint(x: rect.midX, y: rect.midY)
}

@MainActor
@Test func touchWaitsForASingleTapAndRejectsDuplicateCompletion() throws {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    var taps = 0
    view.onPixTapped = { taps += 1 }
    view.touch(at: try characterPoint(view))
    #expect(taps == 0)
    let finish = try #require(waits.taps.last)
    finish()
    finish()
    #expect(taps == 1)
}

@MainActor
@Test func aPetCancelsTheTapAndOldWorkCannotFinishANewTap() throws {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    var taps = 0, pets = 0
    view.onPixTapped = { taps += 1 }
    view.onPixPetted = { pets += 1 }
    let point = try characterPoint(view)
    view.touch(at: point)
    let old = try #require(waits.taps.last)
    view.touch(at: point)
    #expect(pets == 1 && taps == 0 && waits.cancellations == 1)
    view.touch(at: point)
    old()
    #expect(taps == 0)
    let current = try #require(waits.taps.last)
    current()
    #expect(taps == 1 && pets == 1)
}

@MainActor
@Test func outsideTouchAndHideCancelPendingTapsImmediately() throws {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    var taps = 0, outside = 0
    view.onPixTapped = { taps += 1 }
    view.onTappedElsewhere = { outside += 1 }
    view.touch(at: try characterPoint(view))
    let first = try #require(waits.taps.last)
    view.touch(at: CGPoint(x: -100, y: -100))
    first()
    #expect(outside == 1 && taps == 0)
    view.touch(at: try characterPoint(view))
    let second = try #require(waits.taps.last)
    view.hide()
    second() // Before the coalesced teardown runs.
    #expect(taps == 0)
    waits.flush()
    #expect(layer("world", of: view) == nil)
}

@MainActor
@Test func viewCoalescesResizeAndStopsOnDetachThenBuildsOnReattachment() throws {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    view.hat = .cap
    let old = try #require(layer("world", of: view))
    view.setFrameSize(CGSize(width: 900, height: 30))
    view.layout()
    view.setFrameSize(CGSize(width: 800, height: 30))
    view.layout()
    #expect(waits.refreshes.count == 1)
    waits.flush()
    #expect(old.superlayer == nil)
    #expect(layer("world", of: view) != nil && view.hat == .cap)
    view.touch(at: try characterPoint(view))
    var taps = 0
    view.onPixTapped = { taps += 1 }
    let pending = try #require(waits.taps.last)
    window.contentView = nil
    pending() // Detachment cancels immediately, before deferred teardown.
    waits.flush()
    pending()
    #expect(taps == 0 && layer("world", of: view) == nil)
    window.contentView = view
    waits.flush()
    #expect(layer("world", of: view) != nil && view.hat == .cap)
}

@MainActor
@Test func hideBeforeDeferredBuildAndZeroWidthDoNotBuildARoom() {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    view.hide()
    waits.flush()
    let room = Room(spot: .desk, activity: .coding, mood: .focused, fps: 12)
    view.show(room)
    view.hide()
    waits.flush()
    #expect(layer("world", of: view) == nil)
    view.show(room)
    view.setFrameSize(CGSize(width: 0, height: 30))
    view.layout()
    waits.flush()
    #expect(layer("world", of: view) == nil)
}

@MainActor
@Test func clockStylesRetainTimeZoneAndCaptionReplacesItsDrawing() throws {
    let waits = ViewWaits()
    let (view, window) = interactiveView(waits)
    defer { view.hide(); waits.flush(); window.contentView = nil }
    view.timeZoneChanged(TimeZone(secondsFromGMT: 2 * 3600)!)
    for (style, text) in [(ClockStyle.twelveHour, "2:00"), (.twentyFourHour, "14:00")] {
        view.clockStyle = style
        let clock = try #require(layer("clock", of: view))
        let drawn = try #require(clock.contents) as! CGImage
        let expected = try #require(pixelText(text, color: color(0x8f95a3)))
        #expect((drawn.dataProvider?.data as Data?) == (expected.dataProvider?.data as Data?))
        #expect(clock.frame.maxX == view.bounds.width - 10)
    }
    view.clockStyle = .system
    let systemClock = try #require(layer("clock", of: view)?.contents) as! CGImage
    let compactTimes = ["2:00", "02:00", "14:00"].compactMap { pixelText($0, color: color(0x8f95a3)) }
    #expect(compactTimes.contains { ($0.dataProvider?.data as Data?) == (systemClock.dataProvider?.data as Data?) })
    view.play(.reaction(.pet))
    let caption = try #require(layer("caption", of: view))
    let word = try #require(layer("captionWord", of: view))
    let oldWord = try #require(word.contents) as! CGImage
    view.play(.reaction(.wave))
    let newWord = try #require(word.contents) as! CGImage
    #expect((oldWord.dataProvider?.data as Data?) != (newWord.dataProvider?.data as Data?))
    #expect(caption.animationKeys() == ["caption"])
    #expect(caption.frame.maxX <= (try #require(layer("clock", of: view))).frame.minX)
    view.hide()
    waits.flush()
    #expect(caption.superlayer?.superlayer == nil)
    #expect(caption.animationKeys()?.isEmpty != false)
}

@Test func pixelFontSkipsUnsupportedCharactersAndScalesItsOutput() throws {
    #expect(pixelText("🙂", color: color(0xffffff)) == nil)
    let lower = try #require(pixelText("a1", color: color(0xffffff), scale: 1))
    let upper = try #require(pixelText("A🙂1", color: color(0xffffff), scale: 1))
    #expect(lower.width == 7 && lower.height == 5)
    #expect((lower.dataProvider?.data as Data?) == (upper.dataProvider?.data as Data?))
    let scaled = try #require(pixelText("A1", color: color(0xffffff), scale: 2))
    #expect(scaled.width == 14 && scaled.height == 10)
}
