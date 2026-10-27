import AppKit
import AmbientCore
import IOKit.ps
import ServiceManagement
import os

private let log = Logger(subsystem: appID, category: "app")

/// Wires macOS events into the Controller and applies its decision to the Touch Bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trayID = NSTouchBarItem.Identifier("\(appID).pixButton")
    private let barID = NSTouchBarItem.Identifier("\(appID).ambient")
    private let bar = NSTouchBar()
    private let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30))  // it takes the bar's real width
    private let monitor = UsageMonitor()
    private lazy var menu = StatusMenu()
    private var presenter: TouchBarPresenter!
    private var execution: AppExecution!
    private var controller: Controller { execution.controller }
    private lazy var agentDelivery = AgentDelivery(forward: { [weak self] urls in
        self?.forwardToOther(urls) ?? false
    })
    private var forwardingToOther = false

    func applicationDidFinishLaunching(_ note: Notification) {
        // Only one Pix may run at a time, even when opened from another path (DMG, Homebrew, or App Translocation).
        if NSRunningApplication.runningApplications(withBundleIdentifier: appID).contains(where: { $0 != .current }) {
            if !forwardingToOther { NSApp.terminate(nil) }
            return
        }
        do { presenter = try TouchBarPresenter() } catch {
            log.fault("\(String(describing: error), privacy: .public) — quitting")
            startAtLogin(false)  // so the explanation doesn't come back at every login
            return cannotRun("This macOS doesn't have what Pix needs",
                             "Pix uses private Touch Bar features, and this version of macOS is missing: \((error as? MissingTouchBarAPI)?.names.joined(separator: ", ") ?? String(describing: error)). A later version of Pix may fix it; until then it won't start at login.")
        }
        log.notice("starting \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev", privacy: .public)")

        let pixButton = NSCustomTouchBarItem(identifier: trayID)
        pixButton.view = NSButton(image: StatusMenu.icon, target: self, action: #selector(pixButtonTapped))
        presenter.addToControlStrip(pixButton)

        let item = NSCustomTouchBarItem(identifier: barID)
        item.view = view
        view.clockStyle = Settings.clock
        view.skin = Settings.skinFolder
        view.onPixTapped = { [weak self] in self?.send(.pixTapped) }
        view.onPixPetted = { [weak self] in self?.send(.pixPetted) }
        view.onTappedElsewhere = { [weak self] in self?.send(.tappedElsewhere) }
        bar.templateItems = [item]
        bar.defaultItemIdentifiers = [barID]

        let saved = Settings.saved
        execution = AppExecution(controller: Controller(selfBundleID: appID, frontApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, power: currentPower(),
                                at: Date(), timeZone: .current, saved: saved, allHats: Settings.allHats), saved: saved,
                                 effects: AppExecution.Effects(save: { Settings.saved = $0 }, choices: { [weak self] saved in
                                     self?.view.hat = saved.hat
                                     self?.menu.hidden = saved.hidden
                                 }, render: { [weak self] in self?.render($0) }, play: { [weak self] in self?.view.play($0) }))
        menu.state = { [weak self] in self?.menuState() ?? StatusMenu.State() }
        menu.onHidden = { [weak self] hide in self?.send(hide ? .hidePix : .showPix) }
        menu.onStartAtLogin = { [weak self] on in self?.startAtLogin(on) }
        menu.onFocus = { [weak self] on in self?.send(on ? .startFocus : .stopFocus) }
        menu.onForget = { [weak self] in self?.confirmForget() }
        menu.onHat = { [weak self] hat in self?.send(.chooseHat(hat)) }
        menu.onSkin = { [weak self] name in
            Settings.skin = name
            self?.view.skin = Settings.skinFolder
        }
        menu.onOpenSkins = {
            try? FileManager.default.createDirectory(at: Settings.skinsFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(Settings.skinsFolder)
        }
        menu.onOverride = { [weak self] id, choice in self?.send(.override(id, choice)) }
        menu.onClock = { [weak self] style in
            Settings.clock = style
            self?.view.clockStyle = style
        }
        observeSystem()
        syncLoginItem()
        if Settings.usageLog { monitor.start { [weak self] in self?.describe() ?? "" } }
        // Every minute, on the minute, so the clock turns over with the menu bar's.
        let nextMinute = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0), matchingPolicy: .nextTime) ?? Date()
        let tick = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {  // runs on the main run loop
                self?.send(.clockTick)
                self?.view.refreshTime()
            }
        }
        RunLoop.main.add(tick, forMode: .common)
        render(controller.bar)
        send(.appStarted)  // Pix says hi
        if macIsHot() { send(.thermalChanged(hot: true)) }
        agentDelivery.start { [weak self] in self?.send($0) }
        checkForTouchBar()
    }

    @objc private func pixButtonTapped() { send(.pixButtonTapped) }

    /// pix://agent/working, …/waiting, …/done or …/failed, from an Agent's hooks. Anything else is ignored.
    func application(_ application: NSApplication, open urls: [URL]) { agentDelivery.receive(urls) }

    private func forwardToOther(_ urls: [URL]) -> Bool {
        // Hand links to the running copy, including a hook that launched this second instance.
        guard let other = NSRunningApplication.runningApplications(withBundleIdentifier: appID).first(where: { $0 != .current }),
              let appURL = other.bundleURL else { return false }
        forwardingToOther = true
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    /// Forget Pix's Memory, once the user confirms it.
    private func confirmForget() {
        let alert = NSAlert()
        alert.messageText = "Forget Pix's Memory?"
        alert.informativeText = "Pix forgets which days it saw you, when you usually arrive and how many Pets it got, and gives back the hats it earned. It starts remembering again from now."
        alert.addButton(withTitle: "Forget")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { send(.forgetMemory) }
    }

    /// What the menu shows when it opens: the Controller's state, and the user's other choices.
    private func menuState() -> StatusMenu.State {
        let front = controller.frontApp.flatMap { id -> (id: String, name: String, override: Override?)? in
            guard id != appID else { return nil }
            let name = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id
            return (id, name, controller.saved.overrides[id])
        }
        return StatusMenu.State(startAtLogin: SMAppService.mainApp.status == .enabled, hidden: controller.hidden, frontApp: front, focusLeft: controller.focusMinutesLeft(at: Date()),
                                hat: controller.hat, wearableHats: controller.wearableHats, clock: Settings.clock,
                                skin: Settings.skin, skins: Settings.skins)
    }

    private func send(_ event: Event) { execution.send(event, at: Date()) }

    private func render(_ decision: Bar) {
        log.info("bar → \(self.describe(), privacy: .public)")
        switch decision {
        case .room(let room):
            view.show(room)
            presenter.show(bar, tray: trayID)
        case .defaultBar:
            view.hide()
            presenter.hide(bar, tray: trayID)
        }
    }

    private func describe() -> String {
        let room = controller.room
        let state = controller.hidden ? "hidden" : controller.bar == .defaultBar ? "default bar" : "showing"
        let source = controller.power.lowPowerMode ? "low power mode" : controller.power.onBattery ? "battery" : "charger"
        return "\(state) · \(room.spot.rawValue) · \(room.activity.rawValue) · \(room.mood.rawValue) · \(room.fps) fps · \(source)"
    }

    // MARK: - macOS events → Controller events

    private func observeSystem() {
        // Every observer below is delivered on the main queue / main run loop.
        let send: @Sendable (Event) -> Void = { [weak self] event in MainActor.assumeIsolated { self?.send(event) } }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            send(.frontAppChanged(app?.bundleIdentifier))
        }
        for (name, event) in [(NSWorkspace.screensDidSleepNotification, Event.screenSlept), (NSWorkspace.screensDidWakeNotification, .screenWoke)] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in send(event) }
        }
        let distributed = DistributedNotificationCenter.default()
        // macOS has no public lock notification; these distributed ones are the de facto standard.
        for (name, event) in [("com.apple.screenIsLocked", Event.locked), ("com.apple.screenIsUnlocked", .unlocked)] {
            distributed.addObserver(forName: .init(name), object: nil, queue: .main) { _ in send(event) }
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
            send(.powerChanged(currentPower()))
        }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { _ in
            send(.thermalChanged(hot: macIsHot()))
        }
        // The user travelled: Mood, Greetings, Occasions and the lamp follow the new hour and date.
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                NSTimeZone.resetSystemTimeZone()
                send(.timeZoneChanged(.current))
                self?.view.timeZoneChanged(.current)
            }
        }
        // Charger plugged/unplugged. Fires on every battery % change too; send() ignores no-op changes.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            MainActor.assumeIsolated {
                Unmanaged<AppDelegate>.fromOpaque(context!).takeUnretainedValue().send(.powerChanged(currentPower()))
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    // MARK: - When Pix can't run

    /// The private API is there on every Mac, so a Mac without a Touch Bar only shows itself by never giving Pix's
    /// view a window. Both that and an empty hardware registry must say so before Pix believes it.
    private func checkForTouchBar() {
        guard !TouchBarPresenter.hasTouchBarDevice() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in  // generous, for a slow login
            guard let self, view.window == nil, controller.bar != .defaultBar else { return }
            startAtLogin(false)  // so the explanation doesn't come back at every login
            cannotRun("Pix needs a Touch Bar", "This Mac doesn't seem to have one, so there's nowhere for Pix to live. It won't start at login again.")
        }
    }

    /// Explains why Pix can't run here, then quits.
    private func cannotRun(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "Quit Pix")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }

    // MARK: - Start at login

    /// Start at login lives in macOS (System Settings → General → Login Items), so a choice made there sticks.
    /// Pix only asks for it on its very first launch, and moves it to itself when it opens from a new place
    /// (after a Homebrew upgrade the old copy is gone).
    private var loginItem: LoginItem {
        let service = SMAppService.mainApp
        return LoginItem(path: Bundle.main.bundlePath, savedPath: { Settings.loginItemPath },
                         savePath: { Settings.loginItemPath = $0 }, enabled: { service.status == .enabled },
                         register: { try service.register() }, unregister: { try service.unregister() })
    }

    private func syncLoginItem() {
        do { try loginItem.sync() } catch {
            log.error("login item: \(String(describing: error), privacy: .public)")
        }
        log.notice("login item status: \(String(describing: SMAppService.mainApp.status), privacy: .public)")
    }

    /// The menu's Start at Login, and the can't-run cases switching it off.
    private func startAtLogin(_ on: Bool) {
        do { try loginItem.setEnabled(on) } catch {
            log.error("login item: \(String(describing: error), privacy: .public)")
        }
    }

}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
