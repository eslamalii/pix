import CoreGraphics
import Testing
import AmbientCore

// Expected values come from the art contract's numbers (art pixels = points), worked out by hand.

let m1 = RoomGeometry(barWidth: 1004)   // the 13" M1's whole Touch Bar
let wide = RoomGeometry(barWidth: 1085)  // a wider bar
let narrow = RoomGeometry(barWidth: 900)

@Test func onTheM1sBarTheStripsSitSideBySide() {
    #expect(m1.stripPitch == 1004)
    #expect(m1.scroll(for: .desk) == 0)
    #expect(m1.scroll(for: .window) == -1004)
}

@Test func onAWiderBarTheStripsSitFurtherApartSoTheNeighborStaysOutOfView() {
    #expect(wide.stripPitch == 1085)
    #expect(wide.rest(at: .window).x == 1590)  // 1085 + 505
}

@Test func theCurrentStripIsCenteredOnAWiderOrNarrowerBar() {
    #expect(wide.scroll(for: .desk) == 40.5)        // (1085 - 1004) / 2 of black on each side
    #expect(wide.scroll(for: .window) == -1085 + 40.5)
    #expect(narrow.scroll(for: .desk) == -52)       // 52 points cropped from each end
}

@Test func pixRestsAtEachSpotsPlaceOnTheFloor() {
    #expect(m1.rest(at: .desk) == CGPoint(x: 492, y: 3))
    #expect(m1.rest(at: .musicCorner) == CGPoint(x: 804, y: 3))
    #expect(m1.rest(at: .window) == CGPoint(x: 1004 + 505, y: 3))
}

@Test func onTheCouchPixIsLiftedSoItsSeatMeetsTheCushion() {
    #expect(m1.rest(at: .couch) == CGPoint(x: 192, y: 6))
}

@Test func pixReachesUpToTheLampSwitchWithItsRaisedHand() {
    #expect(m1.standingPoint(for: .switchLamp, from: desk) == ErrandStand(x: 654, facingLeft: false))  // 656 + 6 - 8
}

@Test func pixHoldsTheMugUnderTheCoffeeMachinesSpout() {
    #expect(m1.standingPoint(for: .refillMug, from: desk) == ErrandStand(x: 613, facingLeft: false))  // 618 - 5
}

/// Where Pix rests at the desk, in world points: between the desk's two plants.
private let desk = m1.rest(at: .desk).x

@Test func pixStandsBesideAPlantOnTheSideItComesFromFacingIt() {
    #expect(m1.standingPoint(for: .waterPlant(deskPlant), from: desk) == ErrandStand(x: 424, facingLeft: true))  // 404 + 6 + 14
    #expect(m1.standingPoint(for: .waterPlant(otherDeskPlant), from: desk) == ErrandStand(x: 722, facingLeft: false))  // 730 + 6 - 14
}

@Test func atEitherEndOfTheStrollPixWatersTheWindowPlantFromThatSide() {
    #expect(m1.standingPoint(for: .waterPlant(windowPlant), from: m1.strollEnd(.left)) == ErrandStand(x: 1674, facingLeft: false))  // 1004 + 678 + 6 - 14
    #expect(m1.standingPoint(for: .waterPlant(windowPlant), from: m1.strollEnd(.right)) == ErrandStand(x: 1702, facingLeft: true))  // 1004 + 678 + 6 + 14
}

@Test func errandsStandInTheSamePlaceOnAWiderBarBecauseTheDeskStripComesFirst() {
    #expect(wide.standingPoint(for: .switchLamp, from: desk) == ErrandStand(x: 654, facingLeft: false))
    #expect(narrow.standingPoint(for: .waterPlant(otherDeskPlant), from: desk) == ErrandStand(x: 722, facingLeft: false))  // 730 + 6 - 14
}

@Test func theDaysOccasionPropsAreDrawnAtTheirStopsInWorldPoints() {
    #expect(m1.occasionPropRect(stop: 0) == CGRect(x: 121, y: 11, width: 12, height: 12))  // on the bookcase: 30 - (7 + 12)
    #expect(m1.occasionPropRect(stop: 2) == CGRect(x: 822, y: 0, width: 12, height: 12))   // on the cabinet, down to the strip's last row
    #expect(wide.occasionPropRect(stop: 3) == CGRect(x: 1085 + 392, y: 2, width: 12, height: 12))  // on the windowsill
}

@Test func pixReachesEachStopWithItsRaisedHandFromTheSideItComesFrom() {
    // The tour, left to right from the desk: the bookcase from the right, then each next stop from the left.
    #expect(m1.occasionStand(stop: 0, from: desk) == ErrandStand(x: 135, facingLeft: true))    // 121 + 6 + 8
    #expect(m1.occasionStand(stop: 1, from: 135) == ErrandStand(x: 278, facingLeft: false))    // 280 + 6 - 8
    #expect(m1.occasionStand(stop: 2, from: 278) == ErrandStand(x: 820, facingLeft: false))    // 822 + 6 - 8
    #expect(m1.occasionStand(stop: 3, from: 820) == ErrandStand(x: 1394, facingLeft: false))   // 1004 + 392 + 6 - 8
    #expect(m1.occasionStand(stop: 3, from: m1.strollEnd(.right)) == ErrandStand(x: 1410, facingLeft: true))  // 1004 + 392 + 6 + 8
}

@Test func theStrollAtTheWindowGoesBetweenItsEnds() {
    #expect(m1.strollEnd(.left) == 1154)  // 1004 + 150
    #expect(m1.strollEnd(.right) == 1864)  // 1004 + 860
}

@Test func propsAreFlippedIntoWorldPointsOnTheirStrip() {
    #expect(m1.rect(Art.lamp, on: "desk") == CGRect(x: 656, y: 26, width: 14, height: 3))
    #expect(wide.rect(Art.windowPane, on: "window") == CGRect(x: 1085 + 382, y: 9, width: 240, height: 18))
}

@Test func walkingToAnotherStripScrollsTheRoomIn1point6Seconds() {
    #expect(m1.walkDuration(from: 492, to: m1.rest(at: .window).x) == 1.6)  // not 6.8 s: the 9-second walk
    #expect(wide.walkDuration(from: wide.rest(at: .window).x, to: 492) == 1.6)
}

@Test func longerWalksWithinAStripTakeLonger() {
    #expect(m1.walkDuration(from: 192, to: 804) == 612.0 / 150)  // couch to music corner
    #expect(m1.walkDuration(from: 492, to: 600) == 1.6)        // a short one still takes 1.6 s
}

@Test func errandWalksGo40PointsASecondAndStrollsGo12() {
    #expect(RoomGeometry.errandWalkDuration(from: 492, to: 412) == 2)
    #expect(RoomGeometry.errandWalkDuration(from: 492, to: 492.5) == 0.1)  // never instant
    #expect(RoomGeometry.strollDuration(from: 1154, to: 1864) == 710.0 / 12)
}

// MARK: - The art contract

@Test func everyMoodHasAFace() {
    for mood in Mood.allCases { #expect(Art.faces.contains(mood.rawValue)) }
}

@Test func thePlantIsAWorkingPropSoADrawingOfItMustKeepItsSize() {
    #expect(Art.workingProps["plant"] == CGSize(width: 12, height: 19))
}

// MARK: - Skins

@Test func aSkinsBodySheetMayHaveAnyNumberOfFramesButMustBeAFrameTall() {
    #expect(Art.skinFits("pix-walk", width: 24 * 9, height: 24, bundled: (144, 24)))
    #expect(!Art.skinFits("pix-walk", width: 100, height: 24, bundled: (144, 24)))
    #expect(!Art.skinFits("pix-walk", width: 144, height: 30, bundled: (144, 24)))
}

@Test func everyOtherSkinFileMustMatchTheBundledSize() {
    #expect(Art.skinFits("pix-face", width: 60, height: 7, bundled: (60, 7)))
    #expect(!Art.skinFits("pix-face", width: 72, height: 7, bundled: (60, 7)))
    #expect(Art.skinFits("hats", width: 80, height: 6, bundled: (80, 6)))
    #expect(!Art.skinFits("room-desk", width: 1000, height: 30, bundled: (1004, 30)))
}

@Test func pixIsFoundWhereItsPastimeIs() {
    #expect(m1.place(of: .doze) == m1.rest(at: .couch))  // sitting on the couch
    #expect(m1.place(of: .gaze) == m1.rest(at: .window))
    #expect(m1.place(of: .coffee) == CGPoint(x: 613, y: 3))  // beside the coffee machine: 618 - 5, on the floor
}
