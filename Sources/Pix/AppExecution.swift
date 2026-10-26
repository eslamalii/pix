import AmbientCore
import Foundation

/// Applies Controller decisions in order. macOS event translation and Room execution keep their own owners.
@MainActor
final class AppExecution {
    struct Effects {
        var save: (Saved) -> Void
        var choices: (Saved) -> Void
        var render: (Bar) -> Void
        var play: (Moment) -> Void
    }

    private(set) var controller: Controller
    private var lastSaved: Saved
    private let effects: Effects

    init(controller: Controller, saved: Saved, effects: Effects) {
        self.controller = controller
        self.lastSaved = saved
        self.effects = effects
        // A stored Hat may no longer be earned; choices must also be shown when nothing changed.
        effects.choices(controller.saved)
        saveChanges()
    }

    func send(_ event: Event, at time: Date) {
        let before = controller.bar
        let moment = controller.handle(event, at: time)
        saveChanges()
        switch event {
        // macOS may have closed the bar without notifying Pix.
        case .frontAppChanged, .pixButtonTapped, .showPix: effects.render(controller.bar)
        default: if controller.bar != before { effects.render(controller.bar) }
        }
        if let moment { effects.play(moment) }
    }

    private func saveChanges() {
        let saved = controller.saved
        guard saved != lastSaved else { return }
        effects.save(saved)
        lastSaved = saved
        effects.choices(saved)
    }
}
