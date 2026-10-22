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
