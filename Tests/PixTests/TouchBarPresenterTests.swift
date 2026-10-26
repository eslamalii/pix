import AppKit
import Testing
@testable import Pix

@MainActor
@Test func missingTouchBarSymbolsAreReportedTogetherBeforeAnyPresentation() {
    var methods: [String] = [], functions: [String] = []
    do {
        _ = try TouchBarPresenter(symbols: TouchBarSymbols(method: { _, selector in
            methods.append(NSStringFromSelector(selector))
            return nil
        }, function: { name in functions.append(name); return nil }))
        Issue.record("Missing symbols must prevent construction")
    } catch let error as MissingTouchBarAPI {
        #expect(methods.count == 3 && functions.count == 2)
        #expect(error.names.count == 5)
        #expect(error.names.contains("DFRElementSetControlStripPresenceForIdentifier"))
        #expect(error.names.contains("DFRSystemModalShowsCloseBoxWhenFrontMost"))
        #expect(error.description.contains("missing private Touch Bar API"))
    } catch { Issue.record("Unexpected error: \(error)") }
}

@MainActor
@Test func currentMacCanResolveThePresentationSymbolsWithoutShowingABar() throws {
    _ = try TouchBarPresenter()
}

/// What the fake private API was asked, in order.
nonisolated(unsafe) private var touchBarCalls: [String] = []

private func fakeSymbols() -> TouchBarSymbols { TouchBarSymbols(method: { _, selector in
    let name = NSStringFromSelector(selector)
    let block: @convention(block) (AnyObject, AnyObject) -> Void = { _, _ in touchBarCalls.append(name) }
    return imp_implementationWithBlock(block)
}, function: { name in
    switch name {
    case "DFRElementSetControlStripPresenceForIdentifier":
        let presence: @convention(c) (CFString, Bool) -> Void = { id, on in touchBarCalls.append("presence \(id) \(on)") }
        return unsafeBitCast(presence, to: UnsafeMutableRawPointer.self)
    default:
        let closeBox: @convention(c) (Bool) -> Void = { _ in }
        return unsafeBitCast(closeBox, to: UnsafeMutableRawPointer.self)
    }
}) }

/// The Control Strip shows one app's item, whichever claimed it last: handing the bar back claims it for the Pix button again,
/// so another app that took the slot since doesn't leave the user without a way back to Pix.
@MainActor
@Test func handingTheBarBackClaimsTheControlStripSlotForThePixButton() throws {
    let presenter = try TouchBarPresenter(symbols: fakeSymbols())
    let tray = NSTouchBarItem.Identifier("pix.sparkles")
    touchBarCalls = []
    presenter.hide(NSTouchBar(), tray: tray)
    #expect(touchBarCalls == ["minimizeSystemModalTouchBar:", "presence pix.sparkles true"])
}
