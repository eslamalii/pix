import AppKit
import AmbientCore

/// Owns Routine execution and Room drawings; Routine decisions stay in AmbientCore.
@MainActor
final class RoomComposition {
    private let playback: Playback
    private let propDrawing = RoomProps()
    private let runner: RoutineRunner
    private var calendar: Calendar
    private var room: Room?
    private let halloween = HalloweenLayers()
    private lazy var sky = RoomSky(halloween: halloween)
    private(set) var world: CALayer?
    private var monitors: [CALayer] = []

    var onTime: (Date, TimeZone) -> Void = { _, _ in }
    var onCaption: (Caption) -> Void = { _ in }
    var pix: CALayer { playback.pix }
    var step: Routine.Step? { playback.step }
    var props: Props { runner.props }
    var hat: Hat? {
        get { playback.hat }
        set { playback.hat = newValue }
    }

    init(routine: Routine = Routine(timeZone: .current), effects: RoutineEffects = RoutineEffects(),
         timing: PlaybackTiming = .live, timeZone: TimeZone = .current) {
        runner = RoutineRunner(routine: routine, effects: effects)
        playback = Playback(timing: timing)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        runner.onWake = { [weak self] in self?.send(.wake) }
        playback.onFinished = { [weak self] in self?.send(.finished) }
        playback.showSkyLife = { [weak self] in self?.sky.show($0) }
        playback.showCaption = { [weak self] in self?.onCaption($0) }
    }

    func build(in host: CALayer, geometry: RoomGeometry, room: Room) {
        if world != nil { stop() }
        self.room = room
        let start = runner.lastSpot ?? room.spot
        let world = CALayer()
        world.name = "world"
        world.anchorPoint = .zero
        world.bounds = CGRect(x: 0, y: 0, width: geometry.stripPitch * CGFloat(Art.strips.count), height: px(Art.height))
        // Every drawing owner may mutate this moving host without cross-fading its destination snapshot.
        world.actions = ["sublayers": NSNull()]
        host.addSublayer(world)
        self.world = world
        sky.build(in: world, geometry: geometry)
        var lastStrip: CALayer?
        for name in Art.strips {
            let strip = pixelCrisp(ArtFiles.shared.image("room-\(name)"))
            strip.name = "roomStrip"
            strip.frame = CGRect(x: geometry.stripX(name), y: 0, width: px(Art.stripWidth), height: px(Art.height))
            world.addSublayer(strip)
            lastStrip = strip
        }
        monitors = Art.monitors.map { scrollingCode(in: geometry.rect($0, on: "desk"), fps: room.fps) }
        monitors.forEach(world.addSublayer)
        halloween.build(in: world, geometry: geometry, frameRange: capped(room.fps))
        playback.fps = room.fps
        playback.build(in: world, geometry: geometry, at: start, mood: room.mood)
        propDrawing.build(in: world, geometry: geometry)
        if let lastStrip { world.insertSublayer(propDrawing.patches, above: lastStrip) }
        withoutAnimation { world.position.x = geometry.scroll(for: start) }
        send(.sceneStarted(room))
    }

    func update(to room: Room) {
        let fpsChanged = room.fps != self.room?.fps
        self.room = room
        if fpsChanged { setFrameRate(room.fps) }
        let next = send(.roomChanged(room))
        if next == nil, fpsChanged, let step, case .idle = step {
            playback.run(step, walkBody: runner.props.walkBody) // Busy steps take the new cap when they end.
        }
    }

    func play(_ moment: Moment) { send(.momentArrived(moment)) }

    func refreshTime() {
        guard world != nil else { return }
        send(.minutePassed)
    }

    func timeZoneChanged(_ zone: TimeZone) { send(.timeZoneChanged(zone)) }

    @discardableResult
    private func send(_ event: Routine.Event) -> Routine.Step? {
        if case .timeZoneChanged(let zone) = event { calendar.timeZone = zone }
        let update = runner.handle(event)
        if world != nil {
            switch event {
            case .sceneStarted, .roomChanged, .minutePassed, .timeZoneChanged:
                sky.refresh(at: update.time, calendar: calendar, fps: room?.fps ?? 12)
                onTime(update.time, calendar.timeZone)
            default: break
            }
        }
        paintProps()
        if let next = update.step { playback.run(next, walkBody: update.props.walkBody) }
        return update.step
    }

    private func paintProps() {
        propDrawing.update(runner.props, fps: room?.fps ?? 12)
    }

    private func setFrameRate(_ fps: Int) {
        playback.fps = fps
        for screen in monitors { recap(screen.sublayers?.first, key: "scroll", fps: fps) }
    }

    func stop() {
        send(.sceneStopped)
        guard let world else { return }
        playback.stop()
        sky.stop()
        propDrawing.stop()
        world.removeFromSuperlayer()
        monitors = []
        self.world = nil
        room = nil
    }

    /// Re-adds an animation that loops forever with a new frame-rate cap.
    private func recap(_ layer: CALayer?, key: String, fps: Int) {
        guard let layer, let animation = layer.animation(forKey: key)?.copy() as? CAAnimation else { return }
        animation.preferredFrameRateRange = capped(fps)
        layer.add(animation, forKey: key)
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

}
