import AppKit
import AmbientCore
import os

private let log = Logger(subsystem: appID, category: "scene")

/// The Touch Bar view: the Room, with Pix in it. Everything moves on Core Animation; the app only
/// does work when something changes. It runs only while it's actually on the Touch Bar (in a window).
/// RoomComposition performs the Routine; this view owns Touch Bar lifecycle and the Status corner.
final class PixView: NSView {
    var onPixTapped: () -> Void = {}
    var onPixPetted: () -> Void = {}
    var onTappedElsewhere: () -> Void = {}

    private var room: Room?        // what the Controller wants shown
    private var shown: Room?       // what the layers currently show
    private let effects: RoutineEffects
    private let art: ArtFiles
    private let composition: RoomComposition
    private var pix: CALayer { composition.pix }
    private var world: CALayer? { composition.world }
    // The status corner at the right end of the bar: the clock, and a caption beside it while a Moment plays.
    // It sits outside the world, so it stays put while Pix walks between Spots, on the bar's black so the Room
    // scrolling under it is hidden rather than drawn through.
    private let hud = CALayer(), clock = pixelCrisp(nil), caption = CALayer(), captionIcon = pixelCrisp(nil), captionWord = pixelCrisp(nil)
    private let clockBacking = CALayer()
    private var builtSize: CGSize = .zero
    private let timing: PixViewTiming
    private var cancelTap: (() -> Void)?
    private var tapGeneration = 0

    /// The bar's width. It starts at one Room strip and takes the real width once the view is on the bar.
    private lazy var barWidth = widthAnchor.constraint(equalToConstant: CGFloat(Art.stripWidth))

    /// The hat Pix wears; nil for none.
    var hat: Hat? {
        get { composition.hat }
        set { composition.hat = newValue }
    }

    /// The chosen skin's folder (nil for Pix's own art). Changing it rebuilds the scene in the new art.
    var skin: URL? {
        didSet {
            art.skin = skin
            guard world != nil else { return }
            teardown()
            scheduleRefresh()
        }
    }

    /// How the Clock reads; set from the menu.
    var clockStyle: ClockStyle = .system {
        didSet {
            let zone = clockFormat.timeZone
            clockFormat = Self.format(for: clockStyle)
            clockFormat.timeZone = zone
            if world != nil { updateClock(at: effects.now()) }
        }
    }
    private var clockFormat = PixView.format(for: .system)

    convenience override init(frame: NSRect) {
        let garden = Settings.garden
        self.init(frame: frame, routine: Routine(timeZone: .current, garden: garden), effects: RoutineEffects())
    }

    init(frame: NSRect, routine: Routine, effects: RoutineEffects, timeZone: TimeZone = .current, art: ArtFiles = ArtFiles(), timing: PixViewTiming = .live) {
        self.timing = timing
        self.art = art
        self.skin = art.skin
        self.composition = RoomComposition(routine: routine, effects: effects, timeZone: timeZone, art: art)
        self.effects = effects
        super.init(frame: frame)
        clockFormat.timeZone = timeZone
        barWidth.isActive = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        allowedTouchTypes = .direct
        composition.onTime = { [weak self] time, zone in
            guard let self else { return }
            clockFormat.timeZone = zone
            updateClock(at: time)
        }
        composition.onCaption = { [weak self] in self?.showCaption($0) }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - What the app tells the view

    func show(_ room: Room) {
        self.room = room
        scheduleRefresh()
    }

    func hide() {
        cancelPendingTap()
        room = nil
        if world == nil { composition.stop() }  // a Moment still waiting for the scene is dropped; a built one stops in teardown
        scheduleRefresh()
    }

    /// Plays a Moment once, then goes back to idling: now, after the walk Pix is on, or once the scene is ready.
    func play(_ moment: Moment) {
        guard room != nil else { return }
        composition.play(moment)
    }

    /// macOS moved to another time zone: all drawings and Routine decisions share this observation.
    func timeZoneChanged(_ zone: TimeZone) {
        clockFormat.timeZone = zone
        composition.timeZoneChanged(zone)
    }

    /// One sampled time drives the Clock, sky, Occasion Props and Routine on every minute.
    func refreshTime() {
        composition.refreshTime()
    }

    // MARK: - Touch: Pix (tap or double-tap) vs anywhere else

    override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .began, in: self).first else { return }
        self.touch(at: touch.location(in: self))
    }

    /// A Touch Bar touch in view coordinates, after AppKit supplies its location.
    func touch(at point: CGPoint) {
        guard room != nil, world != nil else { return }
        guard pixHitArea.contains(point) else {
            cancelPendingTap()
            return onTappedElsewhere()
        }
        if cancelTap != nil {
            cancelPendingTap()
            onPixPetted()
        } else {
            tapGeneration += 1
            let mine = tapGeneration
            cancelTap = timing.after(0.3) { [weak self] in
                guard let self, tapGeneration == mine else { return }
                cancelPendingTap()
                onPixTapped()
            }
        }
    }

    private func cancelPendingTap() {
        tapGeneration += 1
        cancelTap?()
        cancelTap = nil
    }

    /// Pix's on-screen frame as it is right now (mid-animation), padded because fingers are bigger than Pix.
    private var pixHitArea: CGRect {
        guard let root = layer, let world else { return .null }
        let onScreen = (root.presentation() ?? root).convert((pix.presentation() ?? pix).frame, from: world.presentation() ?? world)
        return onScreen.insetBy(dx: -10, dy: -4)
    }

    // MARK: - Building and updating

    override func viewDidMoveToWindow() {
        if window == nil { cancelPendingTap() }
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
        timing.refresh { [weak self] in
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
        guard let host = layer else { return }
        builtSize = bounds.size
        buildHUD()
        shown = room
        composition.build(in: host, geometry: geometry, room: room)
        log.info("scene started: \(room.spot.rawValue, privacy: .public) · \(room.activity.rawValue, privacy: .public) · \(room.mood.rawValue, privacy: .public) at \(room.fps) fps")
    }

    private func update(to room: Room) {
        shown = room
        composition.update(to: room)
    }

    private func teardown() {
        cancelPendingTap()
        guard world != nil else { return }
        composition.stop()
        hud.removeFromSuperlayer()
        caption.removeAllAnimations()
        shown = nil
        log.info("scene stopped")
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
    private static let textHeight: CGFloat = 10, margin: CGFloat = 10, captionGap: CGFloat = 8

    private func buildHUD() {
        hud.name = "statusCorner"
        caption.name = "caption"
        captionWord.name = "captionWord"
        clock.name = "clock"
        hud.frame = bounds
        hud.zPosition = 1
        captionIcon.name = "captionIcon"
        captionIcon.contents = art.image("emotes")
        caption.opacity = 0
        caption.backgroundColor = NSColor.black.cgColor
        caption.sublayers = [captionIcon, captionWord]
        clockBacking.backgroundColor = NSColor.black.cgColor
        hud.sublayers = [clockBacking, clock, caption]
        layer?.addSublayer(hud)
    }

    private func updateClock(at time: Date) {
        let image = pixelText(clockFormat.string(from: time), color: Self.clockColor)
        withoutAnimation {
            clock.contents = image
            let width = CGFloat(image?.width ?? 0)
            clock.frame = CGRect(x: bounds.width - Self.margin - width, y: (bounds.height - Self.textHeight) / 2, width: width, height: Self.textHeight)
            clockBacking.frame = CGRect(x: clock.frame.minX - Self.captionGap / 2, y: 0, width: bounds.width - clock.frame.minX + Self.captionGap / 2, height: bounds.height)
        }
    }

    /// Shows a Moment's Emote and word beside the clock for a few seconds, then fades them out.
    private func showCaption(_ text: Caption) {
        let image = pixelText(text.word, color: Self.captionColor)
        let wordWidth = CGFloat(image?.width ?? 0), icon = px(Art.emote), gap: CGFloat = 4
        withoutAnimation {
            captionWord.contents = image
            captionIcon.contentsRect = emoteSlot(text.emote)
            // Its black runs on to the clock's, a gap's half either side of the text.
            let pad = Self.captionGap / 2
            caption.frame = CGRect(x: clock.frame.minX - Self.captionGap - wordWidth - gap - icon - pad, y: 0,
                                   width: pad + icon + gap + wordWidth + pad, height: bounds.height)
            captionIcon.frame = CGRect(x: pad, y: (bounds.height - icon) / 2, width: icon, height: icon)
            captionWord.frame = CGRect(x: pad + icon + gap, y: (bounds.height - Self.textHeight) / 2, width: wordWidth, height: Self.textHeight)
        }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.05, 0.85, 1]
        fade.duration = 5
        fade.preferredFrameRateRange = frameRange
        caption.add(fade, forKey: "caption")
    }

    private var frameRange: CAFrameRateRange { capped(composition.fps) }

}
