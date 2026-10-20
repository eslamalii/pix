import AppKit
import AmbientCore
import os

private let log = Logger(subsystem: appID, category: "scene")

/// The art files, loaded once each: from the chosen skin's folder when it has a drawing that fits, otherwise from the
/// app bundle (Contents/Resources/Art).
@MainActor
private enum ArtFiles {
    static var cache: [String: CGImage] = [:]
    /// The chosen skin's folder; nil for Pix's own art.
    static var skin: URL? { didSet { cache = [:] } }

    static func image(_ name: String) -> CGImage? {
        if let hit = cache[name] { return hit }
        guard let bundled = classic(name) else { return nil }
        var image = bundled
        if let skin, let drawn = load(skin.appendingPathComponent(Art.file(name))) {
            if Art.skinFits(name, width: drawn.width, height: drawn.height, bundled: (bundled.width, bundled.height)) {
                image = drawn
            } else {
                log.error("skin art \(name, privacy: .public) is \(drawn.width)×\(drawn.height), not \(bundled.width)×\(bundled.height): using Pix's own")
            }
        }
        cache[name] = image
        return image
    }

    /// Pix's own drawing, whatever the skin: what a skin's hats.png that stops early leaves out comes from here.
    static func classic(_ name: String) -> CGImage? {
        if let hit = cache["classic/" + name] { return hit }
        guard let bundled = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art").flatMap(load) else {
            log.error("missing art: \(name, privacy: .public)")
            return nil
        }
        cache["classic/" + name] = bundled
        return bundled
    }

    private static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// Layers measure in points, and the Touch Bar is a 2× screen: one point is 2×2 pixels, i.e. exactly one art pixel.
private func px(_ artPixels: Int) -> CGFloat { CGFloat(artPixels) }
private func px(_ artPixels: CGFloat) -> CGFloat { artPixels }

/// The part of a horizontal sprite sheet holding cell `index` of `count`.
private func slot(_ index: Int, of count: Int) -> CGRect {
    CGRect(x: CGFloat(index) / CGFloat(count), y: 0, width: 1 / CGFloat(count), height: 1)
}

private func emoteSlot(_ name: String) -> CGRect { slot(Art.emotes.firstIndex(of: name) ?? 0, of: Art.emotes.count) }

private func pixelCrisp(_ image: CGImage?) -> CALayer {
    let layer = CALayer()
    layer.contents = image
    layer.magnificationFilter = .nearest
    return layer
}

private func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

private let facingLeft = CATransform3DMakeScale(-1, 1, 1)

/// The sky's colors for each time of day.
private extension Daylight {
    var sky: (top: UInt32, bottom: UInt32) {
        switch self {
        case .dawn: (0x6e5aa8, 0xffb37a)
        case .day: (0x4aa3ff, 0xbfe3ff)
        case .dusk: (0x5b3f8f, 0xff8a5c)
        case .night: (0x0b1026, 0x24305e)
        }
    }
}

/// The Touch Bar view: the Room, with Pix in it. Everything moves on Core Animation; the app only
/// does work when something changes. It runs only while it's actually on the Touch Bar (in a window).
/// What Pix does next is the Routine's call: the view performs each step and tells the Routine when it ends.
final class PixView: NSView {
    var onPixTapped: () -> Void = {}
    var onPixPetted: () -> Void = {}
    var onTappedElsewhere: () -> Void = {}

    private var room: Room?        // what the Controller wants shown
    private var shown: Room?       // what the layers currently show
    private var routine = Routine(timeZone: .current, garden: Settings.garden)
    /// The Garden as last saved, so it's only written when it changes.
    private var savedGarden = Settings.garden
    private var step: Routine.Step?  // the one playing

    private var world: CALayer?
    private let sky = CAGradientLayer(), skyBox = CALayer(), skyLife = CALayer()
    private let lampGlow = CALayer()
    /// The desk where the mug stands, over the mug while Pix carries it off.
    private let mugGone = CALayer()
    /// Each plant drooping over the upright one, in the order of `Art.plantProps`, while it is thirsty.
    private var droopingPlants: [CALayer] = []
    private let halloween = HalloweenLayers()  // Halloween
    // The status corner at the right end of the bar: the clock, and a caption beside it while a Moment plays.
    // It sits outside the world, so it stays put while Pix walks between Spots.
    private let hud = CALayer(), clock = pixelCrisp(nil), caption = CALayer(), captionIcon = pixelCrisp(nil), captionWord = pixelCrisp(nil)
    private let pix = CALayer(), body = pixelCrisp(nil), face = pixelCrisp(nil), faceGlow = CALayer(), emote = pixelCrisp(nil)
    private let hatLayer = pixelCrisp(nil)
    private var bodySheet = "idle"  // the body playing: some can't be done in a hat
    private var skyDaylight: Daylight?
    private var builtSize: CGSize = .zero
    private var monitors: [CALayer] = []       // the code scrolling on them
    private var ambient: [CALayer] = []        // particles that belong to the current idle (notes, Zs, desk steam)
    private var deskSteam: [CALayer] = []      // the mug's steam, which is also in `ambient`
    private var momentParticles: [CALayer] = [] // particles that belong to the Moment playing (hearts, Zs, coffee steam)
    private var faceHome: CGPoint = .zero  // where the face sits when Pix looks straight at the user

    // Only one step plays at a time. Each gets a token, so a completion that arrives after a newer step took over
    // does nothing.
    private var token = 0
    /// Sends the Routine `wake` at its `nextWake`. Every call into the Routine moves it.
    private var wakeTask: Task<Void, Never>?
    private var pendingTap: Task<Void, Never>?

    /// The bar's width. It starts at one Room strip and takes the real width once the view is on the bar.
    private lazy var barWidth = widthAnchor.constraint(equalToConstant: CGFloat(Art.stripWidth))

    /// How the Clock reads; set from the menu.
    /// The hat Pix wears; nil for none.
    var hat: Hat? { didSet { showHat() } }

    /// The chosen skin's folder (nil for Pix's own art). Changing it rebuilds the scene in the new art.
    var skin: URL? {
        didSet {
            ArtFiles.skin = skin
            guard world != nil else { return }
            teardown()
            scheduleRefresh()
        }
    }

    var clockStyle: ClockStyle = .system {
        didSet {
            clockFormat = Self.format(for: clockStyle)
            if world != nil { updateClock() }
        }
    }
    private var clockFormat = PixView.format(for: .system)

    override init(frame: NSRect) {
        super.init(frame: frame)
        barWidth.isActive = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        allowedTouchTypes = .direct
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - What the app tells the view

    func show(_ room: Room) {
        self.room = room
        scheduleRefresh()
    }

    func hide() {
        room = nil
        if world == nil { send(.sceneStopped) }  // a Moment still waiting for the scene is dropped; a built one stops in teardown
        scheduleRefresh()
    }

    /// Plays a Moment once, then goes back to idling: now, after the walk Pix is on, or once the scene is ready.
    func play(_ moment: Moment) {
        guard room != nil else { return }
        send(.momentArrived(moment))
    }

    /// macOS moved to another time zone: the Routine's lamp follows, and the Clock shows the new time at once.
    func timeZoneChanged(_ zone: TimeZone) {
        send(.timeZoneChanged(zone))
        if world != nil { paintTime() }
    }

    /// Repaints everything that follows the time, and lets the Routine see the minute pass. Called on every minute.
    func refreshTime() {
        guard world != nil else { return }
        paintTime()
        send(.minutePassed)
    }

    /// The clock, sky, and stars or clouds. The Room itself stays black, like the bar around it, so there is no tint.
    private func paintTime() {
        updateClock()
        let daylight = Daylight(hour: Calendar.current.component(.hour, from: Date()))
        withoutAnimation {
            sky.colors = [color(daylight.sky.bottom), color(daylight.sky.top)]
        }
        halloween.paint(daylight)  // Halloween
        if shown?.spot == .window && daylight != skyDaylight { fillSky(for: daylight) }
    }

    /// Stars and clouds only exist while the window is in view.
    private func showSkyLife(_ visible: Bool) {
        if visible {
            if skyDaylight == nil { paintTime() }
        } else {
            skyLife.sublayers = nil
            skyDaylight = nil
        }
    }

    /// The hat, from the skin when it draws that one, otherwise Pix's own; hidden for a body that can't wear it.
    private func showHat() {
        withoutAnimation {
            hatLayer.isHidden = hat == nil || !Art.wearsHat(bodySheet)
            guard let hat, let index = Art.hats.firstIndex(of: hat.rawValue) else { return }
            let sheet = ArtFiles.image("hats"), cells = (sheet?.width ?? 0) / Int(Art.hat.width)
            if index < cells {
                (hatLayer.contents, hatLayer.contentsRect) = (sheet, slot(index, of: cells))
            } else {
                (hatLayer.contents, hatLayer.contentsRect) = (ArtFiles.classic("hats"), slot(index, of: Art.hats.count))
            }
        }
    }

    // MARK: - Touch: Pix (tap or double-tap) vs anywhere else

    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        guard pixHitArea.contains(touch.location(in: self)) else {
            pendingTap?.cancel()
            pendingTap = nil
            return onTappedElsewhere()
        }
        if let pending = pendingTap {
            pending.cancel()
            pendingTap = nil
            onPixPetted()
        } else {
            // Wait a moment: a second tap makes it a Pet instead.
            pendingTap = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                pendingTap = nil
                onPixTapped()
            }
        }
    }

    /// Pix's on-screen frame as it is right now (mid-animation), padded because fingers are bigger than Pix.
    private var pixHitArea: CGRect {
        guard let root = layer, let world else { return .null }
        let onScreen = (root.presentation() ?? root).convert((pix.presentation() ?? pix).frame, from: world.presentation() ?? world)
        return onScreen.insetBy(dx: -10, dy: -4)
    }

    // MARK: - Building and updating

    override func viewDidMoveToWindow() {
        // Every Touch Bar is a little different: take the width this one gives us.
        if let width = window?.frame.width, width > 0, width != barWidth.constant { barWidth.constant = width }
        scheduleRefresh()
    }
    override func layout() {
        super.layout()
        scheduleRefresh()
    }

    /// The Touch Bar resizes the view a few times while showing it; act once, at the final size.
    private var refreshScheduled = false
    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        let wanted = window != nil && bounds.width > 0 ? room : nil
        guard let wanted else { return teardown() }
        if world == nil || builtSize != bounds.size {
            teardown()
            build(wanted)
        } else if wanted != shown {
            update(to: wanted)
        }
    }

    private var geometry: RoomGeometry { RoomGeometry(barWidth: bounds.width) }

    private func build(_ room: Room) {
        let world = CALayer()
        world.anchorPoint = .zero
        world.bounds = CGRect(x: 0, y: 0, width: geometry.stripPitch * CGFloat(Art.strips.count), height: px(Art.height))
        layer?.addSublayer(world)
        self.world = world
        builtSize = bounds.size

        // The sky, with its stars or clouds, behind the window strip's transparent pane.
        skyBox.frame = geometry.rect(Art.windowPane, on: "window")
        skyBox.masksToBounds = true
        sky.frame = skyBox.bounds
        skyLife.frame = skyBox.bounds
        skyBox.addSublayer(sky)
        skyBox.addSublayer(skyLife)
        world.addSublayer(skyBox)
        for name in Art.strips {
            let strip = pixelCrisp(ArtFiles.image("room-\(name)"))
            strip.frame = CGRect(x: geometry.stripX(name), y: 0, width: px(Art.stripWidth), height: px(Art.height))
            world.addSublayer(strip)
        }
        mugGone.frame = geometry.rect(Art.mug, on: "desk")
        mugGone.backgroundColor = NSColor.black.cgColor  // the strip is see-through where nothing stands, so the bar shows
        mugGone.contents = ArtFiles.image("mug-gone")
        mugGone.magnificationFilter = .nearest
        world.addSublayer(mugGone)
        droopingPlants = Art.plantProps.enumerated().map { i, plant in
            let layer = CALayer()
            let top = plant.y ?? Art.height - Art.floor - Int(Art.plant.height)
            layer.frame = geometry.rect(CGRect(x: CGFloat(plant.x), y: CGFloat(top), width: Art.plant.width, height: Art.plant.height), on: plant.strip)
            layer.backgroundColor = NSColor.black.cgColor  // see-through where nothing stands, like the desk under the mug
            layer.contents = ArtFiles.image("plant-thirsty")
            layer.contentsRect = slot(i, of: Art.plantProps.count)
            layer.magnificationFilter = .nearest
            layer.isHidden = true
            world.addSublayer(layer)
            return layer
        }
        monitors = Art.monitors.map { scrollingCode(in: geometry.rect($0, on: "desk"), fps: room.fps) }
        monitors.forEach(world.addSublayer)
        halloween.build(in: world, geometry: geometry, frameRange: frameRange)  // Halloween

        pix.anchorPoint = CGPoint(x: 0.5, y: 0)
        pix.bounds = CGRect(x: 0, y: 0, width: px(Art.frame), height: px(Art.frame))
        body.frame = pix.bounds
        let screen = Art.faceScreen
        face.frame = CGRect(x: px(screen.minX), y: px(CGFloat(Art.frame) - screen.maxY), width: px(screen.width), height: px(screen.height))
        face.contents = ArtFiles.image("pix-face")
        faceHome = face.position
        faceGlow.frame = face.frame  // the monitors' light on the face-screen, at the desk
        faceGlow.backgroundColor = color(0x79c0ff, 0.22)
        // Beside the head, not above it: Pix's head is 3 points from the top of the bar.
        emote.frame = CGRect(x: pix.bounds.width - 4, y: pix.bounds.height - px(Art.emote) - 4, width: px(Art.emote), height: px(Art.emote))
        emote.contents = ArtFiles.image("emotes")
        emote.opacity = 0
        // Over the head, rising into the free rows above the frame.
        hatLayer.frame = CGRect(x: px(Art.hat.minX), y: px(CGFloat(Art.frame) - Art.hat.maxY), width: px(Art.hat.width), height: px(Art.hat.height))
        showHat()
        for sublayer in [body, face, faceGlow, hatLayer, emote] { pix.addSublayer(sublayer) }
        world.addSublayer(pix)

        // The lamp's light goes over everything, Pix included.
        buildLampGlow()
        world.addSublayer(lampGlow)
        buildHUD()

        // Start where Pix was last seen, so it walks into view if the Spot changed while the scene was away.
        let start = routine.lastSpot ?? room.spot
        withoutAnimation {
            world.position.x = geometry.scroll(for: start)
            pix.position = geometry.rest(at: start)
        }
        shown = room
        skyDaylight = nil
        blink(in: room.mood)  // the face has its Mood even if the scene opens with a Moment or the needle
        log.info("scene started: \(room.spot.rawValue, privacy: .public) · \(room.activity.rawValue, privacy: .public) · \(room.mood.rawValue, privacy: .public) at \(room.fps) fps")
        send(.sceneStarted(room))
        paintTime()
    }

    private func update(to room: Room) {
        let fpsChanged = room.fps != shown?.fps
        let looksChanged = room.agentWorking != shown?.agentWorking || room.hot != shown?.hot
        shown = room
        if fpsChanged { for screen in monitors { recap(screen.sublayers?.first, key: "scroll", fps: room.fps) } }
        if let next = handle(.roomChanged(room)) {
            run(next)
        } else if fpsChanged || looksChanged, let step, case .idle = step {
            run(step)  // its loops and particles take the new cap or typing speed; a busy step takes it when it ends
        }
    }

    /// Re-adds an animation that loops forever with a new frame-rate cap.
    private func recap(_ layer: CALayer?, key: String, fps: Int) {
        guard let layer, let animation = layer.animation(forKey: key)?.copy() as? CAAnimation else { return }
        animation.preferredFrameRateRange = capped(fps)
        layer.add(animation, forKey: key)
    }

    private func teardown() {
        pendingTap?.cancel()
        pendingTap = nil
        guard let world else { return }
        send(.sceneStopped)  // a Greeting must not replay long after the fact
        _ = takeOver()
        clearAmbient()
        for layer in [skyBox, lampGlow, pix, hud] { layer.removeFromSuperlayer() }
        caption.removeAllAnimations()
        world.removeFromSuperlayer()
        for layer in [pix, body, face, emote] { layer.removeAllAnimations() }
        skyLife.sublayers = nil
        monitors = []
        (self.world, shown, step, skyDaylight) = (nil, nil, nil, nil)
        log.info("scene stopped")
    }

    /// Starts a new step: stale completions and rests stop, and Pix freezes where it stands.
    private func takeOver() -> Int {
        token += 1
        let x = pix.presentation()?.position.x ?? pix.position.x
        withoutAnimation { pix.position.x = x }
        pix.removeAnimation(forKey: "slide-position.x")
        pix.removeAnimation(forKey: "hop")
        pix.removeAnimation(forKey: "bounce")
        look(0)
        emote.removeAllAnimations()
        momentParticles.forEach { $0.removeFromSuperlayer() }
        momentParticles = []
        return token
    }

    // MARK: - Performing the Routine's steps

    /// Tells the Routine what happened, and performs the step it asks for, if any.
    private func send(_ event: Routine.Event) {
        if let next = handle(event) { run(next) } else { paintDeskSteam() }
    }

    /// Tells the Routine what happened, and moves the wake timer to its new deadline.
    private func handle(_ event: Routine.Event) -> Routine.Step? {
        defer {
            scheduleWake()
            paintProps()
            if routine.garden != savedGarden { (Settings.garden, savedGarden) = (routine.garden, routine.garden) }
        }
        return routine.handle(event, at: Date())
    }

    /// The lamp's glow, the desk's bare patch and the drooping plants follow what the Routine says the Props show.
    private func paintProps() {
        let props = routine.props(at: Date())
        withoutAnimation {
            lampGlow.isHidden = !props.lampLit
            mugGone.isHidden = !props.mugAway
            for (layer, plant) in zip(droopingPlants, Art.plantProps) {
                layer.isHidden = !props.thirstyPlants.contains(Plant(plant))
            }
        }
    }

    private func scheduleWake() {
        wakeTask?.cancel()
        wakeTask = routine.nextWake.map { deadline in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                self?.send(.wake)  // early, by the wall clock: the Routine ignores it and the timer is set again
            }
        }
    }

    private func run(_ step: Routine.Step) {
        self.step = step
        switch step {
        case .walk(let spot):
            walk(.spot(spot))
        case .idle(let spot, let look):
            idle(at: spot, look: look)
        case .moment(let moment):
            log.notice("moment: \(String(describing: moment), privacy: .public)")
            playMoment(moment.look)
        case .fidget(let fidget):
            log.info("fidget: \(fidget.rawValue, privacy: .public)")
            perform(fidget.rawValue, loops: 1)
        case .errand(let errand):
            log.info("errand: \(errand.body, privacy: .public)")
            walk(.errand(to: geometry.standingPoint(for: errand).x))
        case .use(let errand):
            withoutAnimation { pix.transform = geometry.standingPoint(for: errand).facingLeft ? facingLeft : CATransform3DIdentity }
            perform(errand.body, loops: 1)
        case .walkBack(let spot):
            walk(.errand(to: geometry.rest(at: spot).x))
        case .dropNeedle:
            withoutAnimation { faceGlow.isHidden = true }
            place(at: geometry.rest(at: .musicCorner), facing: CATransform3DIdentity)
            perform("needle", loops: 1)
        case .stroll(let end, let restLook):
            log.info("stroll: \(String(describing: end), privacy: .public)")
            apply(restLook, at: .window)
            walk(.stroll(to: geometry.strollEnd(end)))
        case .stop(let end, let body, let restLook):
            log.info("stop: \(String(describing: end), privacy: .public)")
            stop(body: body, restLook: restLook)
        case .relook(let restLook):
            log.info("relook")
            apply(restLook, at: .window)
        case .pastime(let pastime):
            log.info("pastime: \(pastime.rawValue, privacy: .public)")
            found(at: pastime)
        }
    }

    /// The resting loop for the Spot and Look, plus its particles.
    private func idle(at spot: Spot, look: RestLook) {
        guard let world else { return }
        log.info("idle: \(spot.rawValue, privacy: .public) · \(look.mood.rawValue, privacy: .public)")
        _ = takeOver()
        apply(look, at: spot)
        place(at: geometry.rest(at: spot), facing: CATransform3DIdentity)
        breathe(true)
        switch spot {
        case .desk:
            setDeskSteam(routine.props(at: Date()).mugSteams, in: world)
        case .call, .couch:
            break
        case .musicCorner:
            let record = geometry.rect(Art.turntable, on: "desk")
            ambient += spinningRecord(record)
            ambient += particles("note", count: 3, every: 2.4, from: CGPoint(x: record.midX, y: record.maxY), in: world, rise: 10)
        case .window:
            break
        }
    }

    /// The scene opens with Pix at the Pastime's place, doing it for two seconds; then the step is finished.
    private func found(at pastime: Pastime) {
        guard let world else { return }
        let mine = takeOver()
        withoutAnimation { world.position.x = geometry.scroll(for: pastime.spot) }
        place(at: geometry.place(of: pastime), facing: CATransform3DIdentity)
        if pastime == .doze {
            apply(RestLook(spot: .couch, mood: .sleepy), at: .couch)  // the TV's glow and the 💤
        } else {
            resetRestingEffects()
            showSkyLife(pastime == .gaze)
        }
        setBody(pastime.body)
        breathe(true)
        after(2, token: mine) { [weak self] in self?.send(.finished) }
    }

    /// Applies the at-rest Look carried by the Step: face, glow, sky life, particles and body.
    private func apply(_ look: RestLook, at spot: Spot) {
        blink(in: look.mood)
        clearAmbient()
        withoutAnimation { faceGlow.isHidden = !look.faceGlows }
        if spot == .couch { tvLight() } else { faceGlow.removeAnimation(forKey: "tv") }
        showSkyLife(spot == .window)
        for particle in look.particles {
            ambient += particle == "zzz" ? particles(particle, count: 2, every: 3.5, from: besideHead, in: pix, rise: 10, life: 2.5)
                                         : particles(particle, count: 2, every: 2.5, from: besideHead, in: pix, rise: 8)
        }
        if let body = look.body { setBody(body, speedUp: look.speedUp) }
    }

    /// A Moment's body, Emote, Caption and extra.
    private func playMoment(_ look: MomentLook) {
        showCaption(look.caption)
        perform(look.body, loops: look.loops, emote: look.emote) { view, duration in
            switch look.extra {
            case .hop: view.hop(every: duration / Double(look.loops), times: look.loops)
            case .hearts: view.burst("heart")
            case .zzz: view.burst("zzz")
            case .steam: view.steam(for: duration)
            case .turnAway: view.turnAway()
            case nil: break
            }
        }
    }

    /// Plays a body once, with optional extras; when it ends, the step is finished.
    private func perform(_ sheet: String, loops: Float, emote symbol: String? = nil, extras: ((PixView, Double) -> Void)? = nil) {
        let mine = takeOver()
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.token == mine else { return }
                self.send(.finished)
            }
        }
        let duration = setBody(sheet, loops: loops)  // finite, so the completion fires when it ends
        if let symbol { showEmote(symbol, for: duration) } else { emote.removeAllAnimations() }
        extras?(self, duration)
        CATransaction.commit()
    }

    /// The Stroll's stop at an end: a beat looking back, a look around (one way, the other, then back at the user), then
    /// the end's body, or standing a while. One token covers all of it, so a Moment or a Fidget that takes over drops
    /// the rest; when it ends, the step is finished.
    private func stop(body: String?, restLook: RestLook) {
        let mine = takeOver()
        apply(restLook, at: .window)
        setBody("idle")
        breathe(true)
        look(-1)
        after(0.5, token: mine) { [weak self] in
            guard let self else { return }
            let facing = pix.position.x < (geometry.stripX("window") + CGFloat(Art.stripWidth) / 2) ? CATransform3DIdentity : facingLeft
            withoutAnimation { pix.transform = facing }
            look(0)
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, mine == self.token else { return }
                    if let body {
                        self.perform(body, loops: 1)
                    } else {
                        self.after(2.5, token: mine) { [weak self] in self?.send(.finished) }
                    }
                }
            }
            glance()
            CATransaction.commit()
        }
    }

    /// Runs `work` after `seconds`, unless a newer step has taken over by then.
    private func after(_ seconds: Double, token mine: Int, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, self?.token == mine else { return }
            work()
        }
    }

    private enum WalkKind {
        case spot(Spot)
        case errand(to: CGFloat)
        case stroll(to: CGFloat)

        var speedUp: Double {
            switch self {
            case .spot, .errand: 1.3
            case .stroll: 1
            }
        }
    }

    /// Clears any ambient particles and face glow from resting at a Spot.
    private func resetRestingEffects() {
        clearAmbient()
        faceGlow.removeAnimation(forKey: "tv")
        withoutAnimation { faceGlow.isHidden = true }
    }

    /// Pix walks: to a Spot (scrolling the Room), on an Errand (to or from a Prop), or along the Stroll.
    private func walk(_ kind: WalkKind) {
        guard let world else { return }
        let mine = takeOver()
        breathe(false)
        withoutAnimation { pix.position.y = px(Art.floor) }

        let fromX = pix.position.x
        let toX: CGFloat
        let duration: Double
        let scrollTarget: CGFloat?

        switch kind {
        case .spot(let spot):
            resetRestingEffects()
            if spot == .window { showSkyLife(true) }  // the window comes into view during the walk
            toX = geometry.rest(at: spot).x
            duration = geometry.walkDuration(from: fromX, to: toX)
            scrollTarget = geometry.scroll(for: spot)

        case .errand(let to):
            resetRestingEffects()
            toX = to
            duration = RoomGeometry.errandWalkDuration(from: fromX, to: toX)
            scrollTarget = nil

        case .stroll(let to):
            toX = to
            duration = RoomGeometry.strollDuration(from: fromX, to: toX)
            scrollTarget = nil
        }

        guard abs(toX - fromX) >= 1 else { return send(.finished) }

        withoutAnimation {
            pix.transform = toX < fromX ? facingLeft : CATransform3DIdentity
        }
        startWalking(speedUp: kind.speedUp)  // loops forever, so it stays outside the completion's transaction

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                guard let self, mine == self.token else { return }
                self.pix.removeAnimation(forKey: "bounce")
                self.look(0)
                self.send(.finished)
            }
        }
        slide(pix, keyPath: "position.x", to: toX, duration: duration)
        if let scrollTarget {
            slide(world, keyPath: "position.x", to: scrollTarget, duration: duration)
        }
        CATransaction.commit()
    }

    private func place(at point: CGPoint, facing: CATransform3D) {
        withoutAnimation {
            pix.position = point
            pix.transform = facing
        }
    }

    private func turnAway() {
        withoutAnimation { pix.transform = CATransform3DEqualToTransform(pix.transform, facingLeft) ? CATransform3DIdentity : facingLeft }
    }

    /// Shows a body sheet and steps through its frames (as many as the image is wide) at the contract's speed.
    /// Returns how long it plays (one pass if it loops forever).
    @discardableResult
    private func setBody(_ sheet: String, loops: Float = .infinity, speedUp: Double = 1) -> Double {
        let image = ArtFiles.image("pix-\(sheet)")
        let frames = max(1, (image?.width ?? Art.frame) / Art.frame)
        let hatChanges = Art.wearsHat(sheet) != Art.wearsHat(bodySheet)
        bodySheet = sheet
        if hatChanges { showHat() }
        withoutAnimation {
            body.contents = image
            body.contentsRect = slot(0, of: frames)  // what shows between animations
        }
        let step = CAKeyframeAnimation(keyPath: "contentsRect")
        step.values = (0..<frames).map { NSValue(rect: slot($0, of: frames)) }
        step.calculationMode = .discrete
        step.duration = Double(frames) / (Art.fps(of: sheet) * speedUp)
        step.repeatCount = loops
        step.preferredFrameRateRange = frameRange
        body.add(step, forKey: "frames")
        return step.duration * Double(loops.isFinite ? loops : 1)
    }

    /// A 1-point rise and fall every 3 seconds, so Pix is never perfectly still.
    private func breathe(_ on: Bool) {
        guard on else { return body.removeAnimation(forKey: "breath") }
        let breath = CAKeyframeAnimation(keyPath: "transform.translation.y")
        breath.values = [0, 1]
        breath.keyTimes = [0, 0.5, 1]
        breath.calculationMode = .discrete
        breath.duration = 3
        breath.repeatCount = .infinity
        breath.preferredFrameRateRange = frameRange
        body.add(breath, forKey: "breath")
    }

    /// Shows the Mood's face, closing the eyes for a moment at two irregular points every ~10 s.
    private func blink(in mood: Mood) {
        let count = Art.faces.count
        let open = slot(Art.faces.firstIndex(of: mood.rawValue) ?? 0, of: count), shut = slot(count - 1, of: count)
        withoutAnimation { face.contentsRect = open }
        let blink = CAKeyframeAnimation(keyPath: "contentsRect")
        blink.values = [open, shut, open, shut, open].map { NSValue(rect: $0) }
        blink.keyTimes = [0, 0.31, 0.326, 0.78, 0.795, 1]
        blink.calculationMode = .discrete
        blink.duration = 9.7
        blink.repeatCount = .infinity
        blink.preferredFrameRateRange = frameRange
        face.add(blink, forKey: "blink")
    }

    /// Each jump crouches, rises and lands in a squash, in time with the jump sheet's four frames. The crouch and
    /// squash frames have shorter legs, so Pix drops a point for them: its feet stay on the floor and its head dips.
    private func hop(every jump: Double, times: Float) {
        let floor = pix.position.y  // the floor, or the couch's seat
        let hop = CAKeyframeAnimation(keyPath: "position.y")
        hop.values = [floor - 1, floor - 1, floor + 3, floor - 1, floor - 1]
        hop.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        hop.duration = jump
        hop.repeatCount = times
        hop.preferredFrameRateRange = frameRange
        pix.add(hop, forKey: "hop")
    }

    /// The walk cycle with its bounce, eyes leading. Both loop forever.
    private func startWalking(speedUp: Double = 1) {
        look(1)
        bounce(stepEvery: setBody(routine.props(at: Date()).walkBody, speedUp: speedUp) / 2)
    }

    /// Up a point on every footstep while walking. The head never moves inside a frame, so the bob happens here:
    /// each step is three walk frames, and Pix is up on the third, as one foot passes the other.
    private func bounce(stepEvery step: Double) {
        let bob = CAKeyframeAnimation(keyPath: "position.y")
        bob.values = [px(Art.floor), px(Art.floor) + 1]
        bob.keyTimes = [0, NSNumber(value: 2.0 / 3), 1]
        bob.calculationMode = .discrete
        bob.duration = step
        bob.repeatCount = .infinity
        bob.preferredFrameRateRange = frameRange
        pix.add(bob, forKey: "bounce")
    }

    /// Moves Pix's eyes `offset` points toward its front (1 leads a walk, -1 looks back, 0 looks at the user).
    private func look(_ offset: CGFloat) {
        face.removeAnimation(forKey: "glance")
        withoutAnimation { face.position.x = faceHome.x + offset }
    }

    /// At the end of a stroll Pix stops and looks around: one way, the other, then back at the user.
    private func glance() {
        let around = CAKeyframeAnimation(keyPath: "position.x")
        around.values = [faceHome.x - 1, faceHome.x + 1, faceHome.x]
        around.keyTimes = [0, 0.4, 0.8, 1]
        around.calculationMode = .discrete
        around.duration = 1.5
        around.preferredFrameRateRange = frameRange
        face.add(around, forKey: "glance")
    }

    private func showEmote(_ name: String, for duration: Double) {
        withoutAnimation { emote.contentsRect = emoteSlot(name) }
        let pop = CAKeyframeAnimation(keyPath: "opacity")
        pop.values = [0, 1, 1, 0]
        pop.keyTimes = [0, 0.1, 0.85, 1]
        pop.duration = duration
        pop.preferredFrameRateRange = frameRange
        emote.add(pop, forKey: "emote")
    }

    // MARK: - Using the Room

    /// The screen's light on Pix's face while it watches from the couch: soft blues and whites, changing like a TV's.
    private func tvLight() {
        let flicker = CAKeyframeAnimation(keyPath: "backgroundColor")
        flicker.values = [color(0x79c0ff, 0.22), color(0xffffff, 0.16), color(0x5a7dff, 0.26), color(0xbfe3ff, 0.18),
                          color(0xffd9a0, 0.14), color(0x79c0ff, 0.2)]
        flicker.calculationMode = .discrete
        flicker.duration = 3
        flicker.repeatCount = .infinity
        flicker.preferredFrameRateRange = frameRange
        faceGlow.add(flicker, forKey: "tv")
    }

    /// The record turning: two glints stepping around its surface, half a turn apart.
    private func spinningRecord(_ record: CGRect) -> [CALayer] {
        guard let world else { return [] }
        let turn = 1.2
        return [0.0, 0.5].map { phase in
            let glint = CALayer()
            glint.frame = CGRect(x: record.minX, y: record.minY, width: 1, height: 1)
            glint.backgroundColor = color(0x8f95a3)
            let around = CAKeyframeAnimation(keyPath: "position.x")
            around.values = (0..<Int(record.width)).map { record.minX + CGFloat($0) + 0.5 }
            around.calculationMode = .discrete
            around.duration = turn
            around.repeatCount = .infinity
            around.timeOffset = phase * turn
            around.preferredFrameRateRange = frameRange
            glint.add(around, forKey: "turn")
            world.addSublayer(glint)
            return glint
        }
    }

    // MARK: - Particles

    // Pixel sprites on looping Core Animation paths. (CAEmitterLayer looked the same but ignored the
    // frame-rate cap and tripled TouchBarServer's CPU on battery: 12.7% vs 3.7%.)

    /// Beside Pix's head, low enough that rising particles stay inside the 30-point bar.
    private var besideHead: CGPoint { CGPoint(x: pix.bounds.maxX - 2, y: pix.bounds.maxY - 12) }

    /// `count` sprites rising from `origin` in `host`, staggered over `period`, each making `flights` flights (forever
    /// by default). Inside a Moment they must end: the Moment ends when everything it started has.
    private func particles(_ sprite: String, count: Int, every period: Double, from origin: CGPoint, in host: CALayer?,
                           rise: CGFloat = 8, life: Double = 2, flights: Float = .infinity) -> [CALayer] {
        guard let host else { return [] }
        return (0..<count).map { i in
            let particle = pixelCrisp(ArtFiles.image("emotes"))
            particle.contentsRect = emoteSlot(sprite)
            particle.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
            particle.position = origin
            particle.opacity = 0  // invisible between flights
            let sway = CGFloat.random(in: 2...6) * (Bool.random() ? 1 : -1)
            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = [origin, CGPoint(x: origin.x + sway / 2, y: origin.y + rise / 2), CGPoint(x: origin.x + sway, y: origin.y + rise)]
                .map { NSValue(point: $0) }
            move.duration = life
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.15, 0.6, 1]
            fade.duration = life
            let flight = CAAnimationGroup()
            flight.animations = [move, fade]
            flight.duration = max(period, life)
            flight.repeatCount = flights
            flight.beginTime = CACurrentMediaTime() + Double(i) * period / Double(count)
            flight.preferredFrameRateRange = frameRange
            particle.add(flight, forKey: "flight")
            host.addSublayer(particle)
            return particle
        }
    }

    /// A short puff from beside Pix's head (hearts after a Pet, Zs on a yawn), cleared with the Moment.
    private func burst(_ sprite: String) {
        momentParticles += particles(sprite, count: 3, every: 0.45, from: besideHead, in: pix, rise: 10, life: 1.6, flights: 1)
    }

    /// Steam from the mug Pix holds during a coffee Break, cleared with the Moment.
    private func steam(for duration: Double) {
        let flights = Float(max(1, (duration / 2).rounded(.down)))  // a flight takes 2 s (its life, longer than the 1.5 s period)
        momentParticles += particles("steam", count: 3, every: 1.5, from: CGPoint(x: pix.bounds.width - 4, y: pix.bounds.height - 12), in: pix,
                                     rise: 8, flights: flights)
    }

    private func clearAmbient() {
        ambient.forEach { $0.removeFromSuperlayer() }
        (ambient, deskSteam) = ([], [])
    }

    /// An empty or cold mug doesn't steam. The hour can change that while Pix idles at the desk, so it starts or stops
    /// in place, without restarting the idle.
    private func paintDeskSteam() {
        guard let world, case .idle(.desk, _)? = step else { return }
        setDeskSteam(routine.props(at: Date()).mugSteams, in: world)
    }

    private func setDeskSteam(_ on: Bool, in world: CALayer) {
        let steaming = !deskSteam.isEmpty
        guard on != steaming else { return }
        if on {
            let mug = geometry.rect(Art.mug, on: "desk")
            deskSteam = particles("steam", count: 1, every: 12, from: CGPoint(x: mug.midX, y: mug.maxY), in: world, rise: 7)
            ambient += deskSteam
        } else {
            deskSteam.forEach { $0.removeFromSuperlayer() }
            ambient.removeAll { layer in deskSteam.contains { $0 === layer } }
            deskSteam = []
        }
    }

    // MARK: - The Room

    /// Stars and a rare shooting star at night, drifting clouds by day, and snow in winter, clipped to the window pane.
    private func fillSky(for daylight: Daylight) {
        skyDaylight = daylight
        skyLife.sublayers = nil
        let pane = skyBox.bounds
        switch daylight {
        case .night:
            for _ in 0..<Int(pane.width / 20) {  // one star per 20 points of window
                let star = pixelCrisp(ArtFiles.image("emotes"))
                star.contentsRect = emoteSlot("star")
                star.frame = CGRect(x: .random(in: 0...(pane.width - 8)), y: .random(in: 4...(pane.height - 8)), width: 8, height: 8)
                let twinkle = CAKeyframeAnimation(keyPath: "opacity")
                twinkle.values = [0.3, 1, 0.3]
                twinkle.duration = .random(in: 2...5)
                twinkle.repeatCount = .infinity
                twinkle.timeOffset = .random(in: 0...5)
                twinkle.preferredFrameRateRange = frameRange
                star.add(twinkle, forKey: "twinkle")
                skyLife.addSublayer(star)
            }
            let streak = CALayer()
            streak.bounds = CGRect(x: 0, y: 0, width: 4, height: 1)
            streak.backgroundColor = color(0xffffff)
            streak.opacity = 0
            let every = Double.random(in: 90...120)  // a rare treat, for under a second
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.values = [CGPoint(x: pane.width * 0.2, y: pane.height - 2), CGPoint(x: pane.width * 0.6, y: 4), CGPoint(x: pane.width * 0.6, y: 4)]
            fly.keyTimes = [0, 0.007, 1]
            fly.duration = every
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 0, 0]
            fade.keyTimes = [0, 0.007, 1]
            fade.duration = every
            let shooting = CAAnimationGroup()
            shooting.animations = [fly, fade]
            shooting.duration = every
            shooting.repeatCount = .infinity
            shooting.timeOffset = .random(in: 0...every)
            shooting.preferredFrameRateRange = frameRange
            streak.add(shooting, forKey: "shooting")
            skyLife.addSublayer(streak)
        case .day, .dawn:
            for i in 0..<3 {
                let cloud = pixelCrisp(ArtFiles.image("cloud"))
                cloud.frame = CGRect(x: 0, y: CGFloat(4 + i * 4), width: Art.cloud.width, height: Art.cloud.height)
                let drift = CABasicAnimation(keyPath: "position.x")
                drift.fromValue = -Art.cloud.width
                drift.toValue = pane.width + Art.cloud.width
                drift.duration = .random(in: 50...90)
                drift.repeatCount = .infinity
                drift.timeOffset = .random(in: 0...90)
                drift.preferredFrameRateRange = frameRange
                cloud.add(drift, forKey: "drift")
                skyLife.addSublayer(cloud)
            }
        case .dusk:
            break
        }
        if Occasion.snows(inMonth: Calendar.current.component(.month, from: Date())) { letItSnow(in: pane) }
        halloween.fillSky(daylight, in: skyLife, frameRange: frameRange)  // Halloween
    }

    /// Flakes drifting down past the window: one per 24 points of it, or per 48 below full frame rate (on battery).
    private func letItSnow(in pane: CGRect) {
        for _ in 0..<Int(pane.width / ((shown?.fps ?? 12) < 12 ? 48 : 24)) {
            let flake = CALayer()
            flake.bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
            flake.backgroundColor = color(0xffffff, 0.85)
            let x = CGFloat.random(in: 0...pane.width)
            let fall = CAKeyframeAnimation(keyPath: "position")
            fall.values = [CGPoint(x: x, y: pane.height + 1), CGPoint(x: x + .random(in: -3...3), y: pane.height / 2), CGPoint(x: x, y: -1)]
                .map { NSValue(point: $0) }
            fall.duration = .random(in: 6...10)
            fall.repeatCount = .infinity
            fall.timeOffset = .random(in: 0...10)
            fall.preferredFrameRateRange = frameRange
            flake.add(fall, forKey: "fall")
            skyLife.addSublayer(flake)
        }
    }

    // MARK: - Status corner

    /// The Clock's format: the system's 12/24-hour pattern, or a forced one, without AM/PM to stay compact,
    /// and in Latin digits, which is all the pixel font has.
    private static func format(for style: ClockStyle) -> DateFormatter {
        let format = DateFormatter()
        let pattern = switch style {
        case .system: DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current) ?? "HH:mm"
        case .twelveHour: "h:mm"
        case .twentyFourHour: "HH:mm"
        }
        format.dateFormat = pattern.filter { $0 != "a" && $0 != "B" }.trimmingCharacters(in: .whitespaces)
        format.locale = Locale(identifier: "en_US_POSIX")
        return format
    }

    private static let clockColor = color(0x8f95a3), captionColor = color(0x5ee6ff)
    private static let textHeight: CGFloat = 10, margin: CGFloat = 10

    private func buildHUD() {
        hud.frame = bounds
        hud.zPosition = 1
        captionIcon.contents = ArtFiles.image("emotes")
        caption.opacity = 0
        caption.sublayers = [captionIcon, captionWord]
        hud.sublayers = [clock, caption]
        layer?.addSublayer(hud)
    }

    private func updateClock() {
        let image = pixelText(clockFormat.string(from: Date()), color: Self.clockColor)
        withoutAnimation {
            clock.contents = image
            let width = CGFloat(image?.width ?? 0)
            clock.frame = CGRect(x: bounds.width - Self.margin - width, y: (bounds.height - Self.textHeight) / 2, width: width, height: Self.textHeight)
        }
    }

    /// Shows a Moment's Emote and word beside the clock for a few seconds, then fades them out.
    private func showCaption(_ text: Caption) {
        let image = pixelText(text.word, color: Self.captionColor)
        let wordWidth = CGFloat(image?.width ?? 0), icon = px(Art.emote), gap: CGFloat = 4
        withoutAnimation {
            captionWord.contents = image
            captionIcon.contentsRect = emoteSlot(text.emote)
            caption.frame = CGRect(x: clock.frame.minX - 8 - wordWidth - gap - icon, y: 0, width: icon + gap + wordWidth, height: bounds.height)
            captionIcon.frame = CGRect(x: 0, y: (bounds.height - icon) / 2, width: icon, height: icon)
            captionWord.frame = CGRect(x: icon + gap, y: (bounds.height - Self.textHeight) / 2, width: wordWidth, height: Self.textHeight)
        }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.05, 0.85, 1]
        fade.duration = 5
        fade.preferredFrameRateRange = frameRange
        caption.add(fade, forKey: "caption")
    }

    /// A pixel-stepped cone of warm light under the desk lamp: one row per point, wider and fainter as it falls.
    private func buildLampGlow() {
        lampGlow.sublayers = nil
        let shade = geometry.rect(Art.lamp, on: "desk")
        for row in 0..<10 {
            let pool = CALayer()
            let spread = CGFloat(row)
            pool.frame = CGRect(x: shade.minX - spread, y: shade.minY - 1 - spread, width: shade.width + 2 * spread, height: 1)
            pool.backgroundColor = color(0xffa040, 0.2 * (1 - Double(row) / 10))  // amber: pale yellow reads as gray on black
            lampGlow.addSublayer(pool)
        }
    }

    /// Lines of "code" scrolling up a monitor, forever.
    private func scrollingCode(in rect: CGRect, fps: Int) -> CALayer {
        let screen = CALayer()
        screen.frame = rect
        screen.masksToBounds = true
        let lines = CALayer()
        lines.frame = CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 2)
        let palette: [UInt32] = [0x7ee787, 0x79c0ff, 0xff7b72, 0xd2a8ff, 0xe3b341]
        let rows = Int(rect.height) / 2
        let pattern = (0..<rows).map { _ in (indent: Int.random(in: 1...4), length: Int.random(in: 3...16), color: palette.randomElement()!) }
        for copy in 0..<2 {  // two identical halves: scrolling by one half loops seamlessly
            for (row, line) in pattern.enumerated() {
                let bar = CALayer()
                bar.frame = CGRect(x: px(line.indent), y: rect.height * CGFloat(copy) + px(row * 2),
                                   width: px(min(line.length, Int(rect.width) - line.indent - 1)), height: px(1))
                bar.backgroundColor = color(line.color)
                lines.addSublayer(bar)
            }
        }
        let scroll = CABasicAnimation(keyPath: "position.y")
        scroll.byValue = rect.height
        scroll.duration = 8
        scroll.repeatCount = .infinity
        scroll.preferredFrameRateRange = capped(fps)
        lines.add(scroll, forKey: "scroll")
        screen.addSublayer(lines)
        return screen
    }

    private var frameRange: CAFrameRateRange { capped(shown?.fps ?? 12) }

    private func capped(_ fps: Int) -> CAFrameRateRange {
        CAFrameRateRange(minimum: Float(min(6, fps)), maximum: Float(fps), preferred: Float(fps))
    }

    private func slide(_ layer: CALayer, keyPath: String, to value: CGFloat, duration: Double) {
        let from = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
        withoutAnimation { layer.setValue(value, forKeyPath: keyPath) }
        let move = CABasicAnimation(keyPath: keyPath)
        move.fromValue = from
        move.toValue = value
        move.duration = duration
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        move.preferredFrameRateRange = frameRange
        layer.add(move, forKey: "slide-\(keyPath)")
    }

    private func withoutAnimation(_ change: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        change()
        CATransaction.commit()
    }
}
