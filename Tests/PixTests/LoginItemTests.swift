import Testing
@testable import Pix

@MainActor
private final class LoginEffects {
    var path: String?
    var enabled = false
    var fail = false
    var calls: [String] = []
    enum Failure: Error { case registration }
    var item: LoginItem {
        LoginItem(path: "/new/Pix.app", savedPath: { self.path }, savePath: { self.path = $0 },
                  enabled: { self.enabled }, register: {
                      self.calls.append("register")
                      if self.fail { throw Failure.registration }
                      self.enabled = true
                  }, unregister: { self.calls.append("unregister"); self.enabled = false })
    }
}

@MainActor
@Test func loginItemRegistersOnceAndMovesOnlyAnEnabledLogin() throws {
    let effects = LoginEffects()
    try effects.item.sync()
    #expect(effects.calls == ["register"] && effects.path == "/new/Pix.app")
    effects.calls = []
    try effects.item.sync()
    #expect(effects.calls.isEmpty)
    effects.path = "/old/Pix.app"
    try effects.item.sync()
    #expect(effects.calls == ["unregister", "register"])
    effects.calls = []
    effects.enabled = false // Disabled in macOS, rather than Pix's menu.
    effects.path = "/old/Pix.app"
    try effects.item.sync()
    #expect(effects.calls.isEmpty && effects.path == "/old/Pix.app")
}

@MainActor
@Test func failedLoginRegistrationKeepsExistingRetryAndFirstLaunchRules() {
    let effects = LoginEffects()
    effects.fail = true
    #expect(throws: LoginEffects.Failure.registration) { try effects.item.sync() }
    #expect(effects.path == "/new/Pix.app") // First launch is not retried on every launch.
    effects.path = "/old/Pix.app"
    effects.enabled = true
    #expect(throws: LoginEffects.Failure.registration) { try effects.item.sync() }
    #expect(effects.path == "/old/Pix.app" && !effects.enabled)
}

@MainActor
@Test func manualLoginChoiceUpdatesThePathAndDoesNotUnregisterTwice() throws {
    let effects = LoginEffects()
    try effects.item.setEnabled(true)
    try effects.item.setEnabled(false)
    try effects.item.setEnabled(false)
    #expect(effects.calls == ["register", "unregister"])
    #expect(effects.path == "/new/Pix.app")
    effects.fail = true
    #expect(throws: LoginEffects.Failure.registration) { try effects.item.setEnabled(true) }
    #expect(effects.path == "/new/Pix.app")
}
