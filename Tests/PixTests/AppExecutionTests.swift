import Foundation
import Testing
import AmbientCore
@testable import Pix

@MainActor
private final class AppEffects {
    var calls: [String] = []
    var saves: [Saved] = []
    var bars: [Bar] = []
    var moments: [Moment] = []
    var effects: AppExecution.Effects {
        AppExecution.Effects(save: { self.calls.append("save"); self.saves.append($0) },
                             choices: { _ in self.calls.append("choices") },
                             render: { self.calls.append("render"); self.bars.append($0) },
                             play: { self.calls.append("play"); self.moments.append($0) })
    }
    func start(saved: Saved = Saved()) -> AppExecution {
        AppExecution(controller: Controller(selfBundleID: "pix.test", frontApp: "com.apple.Safari",
                                            power: Power(onBattery: false, lowPowerMode: false),
                                            at: Date(timeIntervalSince1970: 12 * 3600), timeZone: TimeZone(secondsFromGMT: 0)!, saved: saved),
                     saved: saved, effects: effects)
    }
}

@MainActor
@Test func appExecutionSavesThenRendersThenPlaysAndSkipsUnchangedWrites() {
    let observed = AppEffects()
    let app = observed.start()
    observed.calls = []
    let time = Date(timeIntervalSince1970: 12 * 3600 + 1)
    app.send(.agent(.working), at: time)
    #expect(observed.calls == ["save", "choices", "render"])
    observed.calls = []
    app.send(.agent(.done), at: time)
    #expect(observed.calls == ["render", "play"])
    #expect(observed.moments == [.agentDone])
    observed.calls = []
    app.send(.clockTick, at: time)
    #expect(observed.calls.isEmpty)
}

@MainActor
@Test func appExecutionRepresentsOnExplicitRequestsEvenWhenTheBarIsUnchanged() {
    let observed = AppEffects()
    let app = observed.start()
    let time = Date(timeIntervalSince1970: 12 * 3600 + 1)
    for event in [Event.frontAppChanged("com.apple.Safari"), .sparklesTapped, .showPix] {
        let before = observed.bars.count
        app.send(event, at: time)
        #expect(observed.bars.count == before + 1)
    }
}

@MainActor
@Test func appExecutionNormalizesAStoredHatAndKeepsHiddenMomentsOffTheRoom() {
    let observed = AppEffects()
    let app = observed.start(saved: Saved(hidden: true, hat: .crown))
    #expect(observed.saves.last?.hat == nil)
    observed.calls = []
    app.send(.agent(.done), at: Date(timeIntervalSince1970: 12 * 3600 + 1))
    #expect(observed.moments.isEmpty && observed.bars.isEmpty)
    #expect(observed.calls == ["save", "choices"])
}
