import AppKit
import AmbientCore
import IOKit.ps
import ServiceManagement
import os

let appID = Bundle.main.bundleIdentifier ?? "io.github.eslamalii.Pix"
private let log = Logger(subsystem: appID, category: "app")

func currentPower() -> Power {
    // These calls return NULL on error; treat that as "not on battery", at an unknown level.
    let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
    let source = info.flatMap { IOPSGetProvidingPowerSourceType($0)?.takeUnretainedValue() } as String?
    return Power(onBattery: source == kIOPMBatteryPowerKey, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                 level: info.flatMap(batteryLevel))
}

/// macOS's own verdict on the Mac's temperature: serious or critical counts as hot.
func macIsHot() -> Bool {
    let state = ProcessInfo.processInfo.thermalState
    return state == .serious || state == .critical
}

/// The internal battery's charge in percent, from the power sources list.
private func batteryLevel(_ info: CFTypeRef) -> Int? {
    guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for source in sources {
        guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int, let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
        else { continue }
        return current * 100 / max
    }
    return nil
}

/// Wires macOS events into the Controller and applies its decision to the Touch Bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let trayID = NSTouchBarItem.Identifier("\(appID).sparkles")
    private let barID = NSTouchBarItem.Identifier("\(appID).ambient")
    private let bar = NSTouchBar()
    private let view = PixView(frame: NSRect(x: 0, y: 0, width: CGFloat(Art.stripWidth), height: 30))  // it takes the bar's real width
    private let monitor = UsageMonitor()
    private let menu = StatusMenu()
    private var presenter: TouchBarPresenter!
    private var controller: Controller!
    /// The Memory as last saved, so it's only written when it changes.
    private var savedMemory = Memory()
    /// pix://agent links that arrived before launch finished (one can launch Pix).
    private var earlyAgentEvents: [Event] = []

    func applicationDidFinishLaunching(_ note: Notification) {
        do { presenter = try TouchBarPresenter() } catch {
            log.fault("\(String(describing: error), privacy: .public) — quitting")
            startAtLogin(false)  // so the explanation doesn't come back at every login
            return cannotRun("This macOS doesn't have what Pix needs",
                             "Pix uses private Touch Bar features, and this version of macOS is missing: \((error as? MissingTouchBarAPI)?.names.joined(separator: ", ") ?? String(describing: error)). A later version of Pix may fix it; until then it won't start at login.")
        }
        log.notice("starting \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev", privacy: .public)")

        let sparkles = NSCustomTouchBarItem(identifier: trayID)
        sparkles.view = NSButton(title: "✨", target: self, action: #selector(sparklesTapped))
        presenter.addToControlStrip(sparkles)

        let item = NSCustomTouchBarItem(identifier: barID)
        item.view = view
        view.clockStyle = Settings.clock
        view.skin = Settings.skin.map { Settings.skinsFolder.appendingPathComponent($0, isDirectory: true) }
        view.onPixTapped = { [weak self] in self?.send(.pixTapped) }
        view.onPixPetted = { [weak self] in self?.send(.pixPetted) }
        view.onTappedElsewhere = { [weak self] in self?.send(.tappedElsewhere) }
        bar.templateItems = [item]
        bar.defaultItemIdentifiers = [barID]

        controller = Controller(selfBundleID: appID, frontApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier, power: currentPower(),
                                at: Date(), timeZone: .current, hidden: Settings.hidden, overrides: Settings.overrides, memory: Settings.memory,
                                hat: Settings.hat, allHats: Settings.allHats)
        savedMemory = controller.memory
        (Settings.hat, view.hat) = (controller.hat, controller.hat)  // a saved hat no longer earned comes off
        menu.hidden = Settings.hidden
        menu.onHidden = { [weak self] hide in self?.send(hide ? .hidePix : .showPix) }
        menu.onStartAtLogin = { [weak self] on in self?.startAtLogin(on) }
        menu.frontApp = { [weak self] in
            guard let id = self?.controller.frontApp, id != appID else { return nil }
            let name = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id
            return (id, name)
        }
        menu.focusLeft = { [weak self] in self?.controller.focusMinutesLeft(at: Date()) }
        menu.onFocus = { [weak self] on in self?.send(on ? .startFocus : .stopFocus) }
        menu.onForget = { [weak self] in self?.confirmForget() }
        menu.earnedHats = { [weak self] in self?.controller.wearableHats ?? [] }
        menu.onHat = { [weak self] hat in self?.send(.chooseHat(hat)) }
        menu.onSkin = { [weak self] name in
            Settings.skin = name
            self?.view.skin = name.map { Settings.skinsFolder.appendingPathComponent($0, isDirectory: true) }
        }
        menu.onOpenSkins = {
            try? FileManager.default.createDirectory(at: Settings.skinsFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(Settings.skinsFolder)
        }
        menu.onOverride = { [weak self] id, choice in
            Settings.overrides[id] = choice
            self?.send(.overridesChanged(Settings.overrides))
        }
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
        render()
        send(.appStarted)  // Pix says hi
        if macIsHot() { send(.thermalChanged(hot: true)) }
        earlyAgentEvents.forEach(send)
        earlyAgentEvents = []
        checkForTouchBar()
    }

    @objc private func sparklesTapped() { send(.sparklesTapped) }

    /// pix://agent/working, …/waiting, …/done or …/failed, from an Agent's hooks. Anything else is ignored.
    func application(_ application: NSApplication, open urls: [URL]) {
        for report in urls.compactMap(AgentReport.init(url:)) {
            let event = Event.agent(report.state, agent: report.agent)
            if controller == nil { earlyAgentEvents.append(event) } else { send(event) }
        }
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

    private func send(_ event: Event) {
        let before = controller.bar
        let moment = controller.handle(event, at: Date())
        if controller.hat != view.hat { (Settings.hat, view.hat) = (controller.hat, controller.hat) }
        (Settings.hidden, menu.hidden) = (controller.hidden, controller.hidden)  // Hide Pix sticks across launches
        if controller.memory != savedMemory { (Settings.memory, savedMemory) = (controller.memory, controller.memory) }
        defer { if let moment { view.play(moment) } }
        switch event {
        // Re-present on these even if nothing changed: the system's ✕ may have closed the bar behind our back.
        case .frontAppChanged, .sparklesTapped, .showPix: render()
        default: if controller.bar != before { render() }
        }
    }

    private func render() {
        log.info("bar → \(self.describe(), privacy: .public)")
        switch controller.bar {
        case .room(let room):
            view.show(room)
            presenter.show(bar, tray: trayID)
        case .defaultBar:
            view.hide()
            presenter.hide(bar)
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
    private func syncLoginItem() {
        let service = SMAppService.mainApp, here = Bundle.main.bundlePath
        do {
            if Settings.loginItemPath == nil { try service.register() }
            else if service.status == .enabled && Settings.loginItemPath != here { try service.unregister(); try service.register() }
        } catch {
            log.error("login item: \(String(describing: error), privacy: .public)")
        }
        if Settings.loginItemPath == nil || service.status == .enabled { Settings.loginItemPath = here }
        log.notice("login item status: \(String(describing: service.status), privacy: .public)")
    }

    /// The menu's Start at Login, and the can't-run cases switching it off.
    private func startAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on { try service.register() } else if service.status == .enabled { try service.unregister() }
        } catch {
            log.error("login item: \(String(describing: error), privacy: .public)")
        }
        Settings.loginItemPath = Bundle.main.bundlePath
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
