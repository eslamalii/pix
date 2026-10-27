import AppKit
import AmbientCore
import os

private let log = Logger(subsystem: appID, category: "playback")

/// Performs the Routine's steps. Owns interruption, completion and the effects that live with each step.
/// Routine decisions remain in AmbientCore; Core Animation and its finite-effect completion stay here.
@MainActor
final class Playback {
    let pix = CALayer()
    private let body = pixelCrisp(nil), face = pixelCrisp(nil), faceGlow = CALayer(), emote = pixelCrisp(nil)
    private let hatLayer = pixelCrisp(nil)
    private var bodySheet = "idle"
    private var faceHome: CGPoint = .zero
    private weak var world: CALayer?
    private var geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    private var ambient: [CALayer] = []
    private var momentParticles: [CALayer] = []
    private var token = 0
    private var completed = false
    private var delayed: [() -> Void] = []
    private let timing: PlaybackTiming
    private let art: ArtFiles
    /// The body Pix walks in during this step: with the mug held out in front while it carries it.
    private var walkBody = "walk"
    private(set) var step: Routine.Step?
    /// The cap for animations started from now on; RoomComposition re-caps what already loops.
    var fps = 12
    var hat: Hat? { didSet { showHat() } }
    var onFinished: () -> Void = {}
    var showSkyLife: (Bool) -> Void = { _ in }
    var showCaption: (Caption) -> Void = { _ in }
    private var frameRange: CAFrameRateRange { capped(fps) }

    init(timing: PlaybackTiming = .live, art: ArtFiles = ArtFiles()) {
        self.timing = timing
        self.art = art
    }

    func build(in world: CALayer, geometry: RoomGeometry, at spot: Spot, mood: Mood) {
        self.world = world
        self.geometry = geometry
        pix.name = "pix"
        pix.anchorPoint = CGPoint(x: 0.5, y: 0)
        // Particles come and go mid-walk. By default that cross-fades Pix from a snapshot taken at the walk's end.
        pix.actions = ["sublayers": NSNull()]
        pix.bounds = CGRect(x: 0, y: 0, width: px(Art.frame), height: px(Art.frame))
        body.frame = pix.bounds
        let screen = Art.faceScreen
        face.frame = CGRect(x: px(screen.minX), y: px(CGFloat(Art.frame) - screen.maxY), width: px(screen.width), height: px(screen.height))
        face.contents = art.image("pix-face")
        faceHome = face.position
        faceGlow.frame = face.frame  // the monitors' light on the face-screen, at the desk
        faceGlow.backgroundColor = color(0x79c0ff, 0.22)
        // Beside the head, not above it: Pix's head is 3 points from the top of the bar.
        emote.frame = CGRect(x: pix.bounds.width - 4, y: pix.bounds.height - px(Art.emote) - 4, width: px(Art.emote), height: px(Art.emote))
        emote.contents = art.image("emotes")
        emote.opacity = 0
        // Over the head, rising into the free rows above the frame.
        hatLayer.name = "hat"
        hatLayer.frame = CGRect(x: px(Art.hat.minX), y: px(CGFloat(Art.frame) - Art.hat.maxY), width: px(Art.hat.width), height: px(Art.hat.height))
        showHat()
        for sublayer in [body, face, faceGlow, hatLayer, emote] { pix.addSublayer(sublayer) }
        world.addSublayer(pix)

        place(at: geometry.rest(at: spot), facing: CATransform3DIdentity)
        blink(in: mood)
    }

    func stop() {
        _ = takeOver()
        clearAmbient()
        for layer in [pix, body, face, faceGlow, emote, hatLayer] { layer.removeAllAnimations() }
        pix.removeFromSuperlayer()
        world = nil
        step = nil
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        onFinished()
    }

    private func transaction(token mine: Int, then completion: @escaping @MainActor () -> Void, animations: () -> Void) {
        timing.transaction(animations) { [weak self] in
            guard let self, self.token == mine, !self.completed else { return }
            completion()
        }
    }

    /// The hat, from the skin when it draws that one, otherwise Pix's own; hidden for a body that can't wear it.
    private func showHat() {
        withoutAnimation {
            hatLayer.isHidden = hat == nil || !Art.wearsHat(bodySheet)
            guard let hat, let drawing = art.hat(hat) else { return }
            (hatLayer.contents, hatLayer.contentsRect) = (drawing.image, drawing.rect)
        }
    }

    /// Starts a new step: stale completions and rests stop, and Pix freezes where it stands.
    private func takeOver() -> Int {
        token += 1
        completed = false
        delayed.forEach { $0() }
        delayed = []
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

    func run(_ step: Routine.Step, walkBody: String = "walk") {
        guard world != nil else { return }
        self.walkBody = walkBody
        // Relook changes the active step's appearance; it does not replace its lifetime.
        switch step {
        case .relook: break
        default: self.step = step
        }
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
        case .desk, .call, .couch:
            break
        case .musicCorner:
            let record = geometry.rect(Art.turntable, on: "desk")
            ambient += spinningRecord(record)
            ambient += Particles.draw("note", count: 3, every: 2.4, from: CGPoint(x: record.midX, y: record.maxY), in: world, rise: 10, fps: fps, art: art)
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
        after(2, token: mine) { [weak self] in self?.finish() }
    }

    /// Applies the at-rest Look carried by the Step: face, glow, sky life, particles and body.
    private func apply(_ look: RestLook, at spot: Spot) {
        blink(in: look.mood)
        clearAmbient()
        withoutAnimation { faceGlow.isHidden = !look.faceGlows }
        if spot == .couch { tvLight() } else { faceGlow.removeAnimation(forKey: "tv") }
        showSkyLife(spot == .window)
        for particle in look.particles {
            ambient += particle == "zzz" ? Particles.draw(particle, count: 2, every: 3.5, from: besideHead, in: pix, rise: 10, life: 2.5, fps: fps, art: art)
                                         : Particles.draw(particle, count: 2, every: 2.5, from: besideHead, in: pix, rise: 8, fps: fps, art: art)
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
    private func perform(_ sheet: String, loops: Float, emote symbol: String? = nil, extras: ((Playback, Double) -> Void)? = nil) {
        let mine = takeOver()
        transaction(token: mine, then: { [weak self] in self?.finish() }) {
            let duration = setBody(sheet, loops: loops)  // finite, so the completion fires when it ends
            if let symbol { showEmote(symbol, for: duration) } else { emote.removeAllAnimations() }
            extras?(self, duration)
        }
    }

    /// The Stroll's stop at an end: a beat looking back, a look around (one way, the other, then back at the user), then
    /// the end's body, or standing a while. A Moment or a Fidget that takes over drops the remaining work;
    /// when the sequence ends, the step is finished.
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
            transaction(token: mine, then: { [weak self] in
                guard let self else { return }
                if let body {
                    self.perform(body, loops: 1)
                } else {
                    self.after(2.5, token: mine) { [weak self] in self?.finish() }
                }
            }) { glance() }
        }
    }

    /// Runs `work` after `seconds`, unless a newer step has taken over by then.
    private func after(_ seconds: Double, token mine: Int, _ work: @escaping @MainActor () -> Void) {
        delayed.append(timing.after(seconds) { [weak self] in
            guard let self, self.token == mine, !self.completed else { return }
            work()
        })
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

        guard abs(toX - fromX) >= 1 else { return finish() }

        withoutAnimation {
            pix.transform = toX < fromX ? facingLeft : CATransform3DIdentity
        }
        startWalking(speedUp: kind.speedUp)  // loops forever, so it stays outside the completion's transaction

        transaction(token: mine, then: { [weak self] in
            guard let self else { return }
            self.pix.removeAnimation(forKey: "bounce")
            self.look(0)
            self.finish()
        }) {
            slide(pix, keyPath: "position.x", to: toX, duration: duration)
            if let scrollTarget {
                slide(world, keyPath: "position.x", to: scrollTarget, duration: duration)
            }
        }
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
        let image = art.image("pix-\(sheet)")
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
        bounce(stepEvery: setBody(walkBody, speedUp: speedUp) / 2)
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

    /// A short puff from beside Pix's head (hearts after a Pet, Zs on a yawn), cleared with the Moment.
    private func burst(_ sprite: String) {
        momentParticles += Particles.draw(sprite, count: 3, every: 0.45, from: besideHead, in: pix, rise: 10, life: 1.6, flights: 1, fps: fps, art: art)
    }

    /// Steam from the mug Pix holds during a coffee Break, cleared with the Moment.
    private func steam(for duration: Double) {
        let flights = Float(max(1, (duration / 2).rounded(.down)))  // a flight takes 2 s (its life, longer than the 1.5 s period)
        momentParticles += Particles.draw("steam", count: 3, every: 1.5, from: CGPoint(x: pix.bounds.width - 4, y: pix.bounds.height - 12), in: pix,
                                     rise: 8, flights: flights, fps: fps, art: art)
    }

    private func clearAmbient() {
        ambient.forEach { $0.removeFromSuperlayer() }
        ambient = []
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

}
