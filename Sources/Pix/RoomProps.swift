import AppKit
import AmbientCore

/// Owns stationary Prop drawings, as the Routine's Props say they show.
@MainActor
final class RoomProps {
    private let art: ArtFiles
    let patches = CALayer(), lampGlow = CALayer()
    private let mugGone = CALayer()
    private var plants: [CALayer] = []
    private var steam: CALayer?
    private weak var world: CALayer?
    private var geometry = RoomGeometry(barWidth: CGFloat(Art.stripWidth))
    private var steamFPS: Int?

    init(art: ArtFiles = ArtFiles()) { self.art = art }

    func build(in world: CALayer, geometry: RoomGeometry) {
        stop()
        self.world = world
        self.geometry = geometry
        mugGone.name = "mugGone"
        mugGone.frame = geometry.rect(Art.mug, on: "desk")
        mugGone.backgroundColor = NSColor.black.cgColor
        mugGone.contents = art.image("mug-gone")
        mugGone.magnificationFilter = .nearest
        patches.name = "propPatches"
        patches.frame = world.bounds
        patches.addSublayer(mugGone)
        world.addSublayer(patches)
        plants = Art.plantProps.enumerated().map { i, plant in
            let layer = pixelCrisp(art.image("plant-thirsty"))
            layer.name = "thirstyPlant"
            let top = plant.y ?? Art.height - Art.floor - Int(Art.plant.height)
            layer.frame = geometry.rect(CGRect(x: CGFloat(plant.x), y: CGFloat(top), width: Art.plant.width, height: Art.plant.height), on: plant.strip)
            layer.backgroundColor = NSColor.black.cgColor
            layer.contentsRect = slot(i, of: Art.plantProps.count)
            layer.isHidden = true
            patches.addSublayer(layer)
            return layer
        }
        lampGlow.name = "lampGlow"
        lampGlow.sublayers = nil
        let shade = geometry.rect(Art.lamp, on: "desk")
        for row in 0..<10 {
            let pool = CALayer()
            let spread = CGFloat(row)
            pool.frame = CGRect(x: shade.minX - spread, y: shade.minY - 1 - spread, width: shade.width + 2 * spread, height: 1)
            pool.backgroundColor = color(0xffa040, 0.2 * (1 - Double(row) / 10))
            lampGlow.addSublayer(pool)
        }
        world.addSublayer(lampGlow)
    }

    func update(_ props: Props, fps: Int) {
        withoutAnimation {
            lampGlow.isHidden = !props.lampLit
            mugGone.isHidden = !props.mugAway
            for (layer, plant) in zip(plants, Art.plantProps) {
                layer.isHidden = !props.thirstyPlants.contains(Plant(plant))
            }
        }
        guard props.mugSteams, let world else {
            steam?.removeFromSuperlayer()
            steam = nil
            steamFPS = nil
            return
        }
        guard steam == nil || steamFPS != fps else { return }
        steam?.removeFromSuperlayer()
        let mug = geometry.rect(Art.mug, on: "desk")
        let origin = CGPoint(x: mug.midX, y: mug.maxY)
        let particle = Particles.draw("steam", count: 1, every: 12, from: origin, in: world, rise: 7, fps: fps, art: art)[0]
        particle.name = "deskSteam"
        steam = particle
        steamFPS = fps
    }

    func stop() {
        for layer in plants + [patches, lampGlow, mugGone] { layer.removeFromSuperlayer() }
        steam?.removeFromSuperlayer()
        steam = nil
        steamFPS = nil
        plants = []
        world = nil
    }
}
