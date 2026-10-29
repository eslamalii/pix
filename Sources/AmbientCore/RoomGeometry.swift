import CoreGraphics

/// Where things are in the Room, in world points (bottom-left origin), for a Touch Bar of a given width.
/// The art contract measures in art pixels from the top-left of a strip; one art pixel is one point.
public struct RoomGeometry: Sendable {
    public let barWidth: CGFloat

    public init(barWidth: CGFloat) { self.barWidth = barWidth }

    /// Strips sit this far apart: a strip's width, plus whatever the bar has beyond it, so a wider bar shows
    /// black beside the current strip rather than the start of the next one.
    public var stripPitch: CGFloat { CGFloat(Art.stripWidth) + max(0, barWidth - CGFloat(Art.stripWidth)) }

    public func stripX(_ strip: String) -> CGFloat { stripPitch * CGFloat(Art.strips.firstIndex(of: strip) ?? 0) }

    /// An art-contract rectangle on a strip, in world points.
    public func rect(_ art: CGRect, on strip: String) -> CGRect {
        CGRect(x: stripX(strip) + art.minX, y: CGFloat(Art.height) - art.maxY, width: art.width, height: art.height)
    }

    /// Pix's resting point at a Spot: feet on the floor or, on the couch, lifted so its seat meets the cushion.
    public func rest(at spot: Spot) -> CGPoint {
        let place = Art.spot(spot)
        var y = Art.floor
        if spot == .couch {
            let standingTop = Art.height - Art.floor - Art.frame, sittingTop = Int(Art.couch.minY) + Art.couchSeat - Art.seatRow
            y += standingTop - sittingTop
        }
        return CGPoint(x: stripX(place.strip) + CGFloat(place.x), y: CGFloat(y))
    }

    /// Where the Room scrolls to so the Spot's strip is centered on the bar: on a wider bar its faded ends meet
    /// black, and on a narrower one both ends are cropped evenly.
    public func scroll(for spot: Spot) -> CGFloat { -stripX(Art.spot(spot).strip) + (barWidth - CGFloat(Art.stripWidth)) / 2 }

    /// Where Pix stands at an end of the window, on the Stroll.
    public func strollEnd(_ end: WindowEnd) -> CGFloat {
        stripX(Art.spot(.window).strip) + CGFloat(end == .left ? Art.wanderFrom : Art.wanderTo)
    }

    /// Where Pix, coming from `x`, stands to use an Errand's Prop, and which way it faces.
    public func standingPoint(for errand: Errand, from x: CGFloat) -> ErrandStand {
        let desk = stripX("desk")
        switch errand {
        case .switchLamp:  // the raised right hand meets the switch on the lamp's pole
            return ErrandStand(x: desk + Art.lamp.minX + CGFloat(Art.lampSwitch - Art.raisedHand), facingLeft: false)
        case .waterPlant(let plant):  // beside the plant on the side Pix comes from, the can held out toward it
            let middle = stripX(plant.strip) + CGFloat(plant.middle), reach = CGFloat(Art.wateringReach), fromRight = x > middle
            return ErrandStand(x: fromRight ? middle + reach : middle - reach, facingLeft: fromRight)
        case .refillMug:  // left of the coffee machine, the mug held out under its spout
            return ErrandStand(x: desk + Art.coffeeMachine.minX - CGFloat(Art.pourReach), facingLeft: false)
        }
    }

    /// Where a stop's Occasion Prop for the day is drawn.
    public func occasionPropRect(stop: Int) -> CGRect {
        let at = Art.occasionStops[stop], size = CGFloat(Art.occasionProp)
        return rect(CGRect(x: CGFloat(at.x), y: CGFloat(at.y), width: size, height: size), on: at.strip)
    }

    /// Where Pix, coming from `x`, stands to place or admire a stop's Occasion Prop: beside it on that side, facing it,
    /// its raised hand meeting the cell's middle.
    public func occasionStand(stop: Int, from x: CGFloat) -> ErrandStand {
        let middle = occasionPropRect(stop: stop).midX, reach = CGFloat(Art.raisedHand), fromRight = x > middle
        return ErrandStand(x: fromRight ? middle + reach : middle - reach, facingLeft: fromRight)
    }

    /// Where Pix is found at a Pastime: on the couch, beside the coffee machine with the mug held out, or at the window.
    public func place(of pastime: Pastime) -> CGPoint {
        switch pastime {
        case .doze, .gaze: rest(at: pastime.spot)
        case .coffee: CGPoint(x: standingPoint(for: .refillMug, from: rest(at: .desk).x).x, y: CGFloat(Art.floor))
        }
    }

    /// A walk to a Spot: crossing to another strip scrolls the Room in 1.6 s; within a strip, longer walks take longer.
    public func walkDuration(from: CGFloat, to: CGFloat) -> Double {
        Int(from / stripPitch) == Int(to / stripPitch) ? max(1.6, Double(abs(to - from) / 150)) : 1.6
    }

    /// Walking to and from a Prop: 40 points a second.
    public static func errandWalkDuration(from: CGFloat, to: CGFloat) -> Double { max(Double(abs(to - from) / 40), 0.1) }

    /// Wandering at the window: 12 points a second.
    public static func strollDuration(from: CGFloat, to: CGFloat) -> Double { max(Double(abs(to - from) / 12), 0.1) }
}

public struct ErrandStand: Equatable, Sendable {
    public var x: CGFloat
    public var facingLeft: Bool
    public init(x: CGFloat, facingLeft: Bool) { (self.x, self.facingLeft) = (x, facingLeft) }
}
