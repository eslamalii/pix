import Foundation
import Testing
import AmbientCore

let deskPlant = Plant(strip: "desk", x: 404)
let otherDeskPlant = Plant(strip: "desk", x: 730)
let windowPlant = Plant(strip: "window", x: 678)
let allPlants = [deskPlant, otherDeskPlant, windowPlant]

@Test func aFreshGardenStartsWithEveryPlantWatered() {
    var garden = Garden()
    garden.adopt(allPlants, at: at(12), random: { 0.5 })
    #expect(garden.thirsty(at: at(12)).isEmpty)
}

@Test(arguments: [(0.0, 10_800.0), (0.5, 16_200.0), (0.99, 21_492.0)])  // 3 h, 4.5 h, just under 6 h
func aPlantTurnsThirstyThreeToSixHoursAfterItWasWatered(roll: Double, seconds: Double) {
    var garden = Garden()
    garden.adopt([deskPlant], at: at(12), random: { roll })
    #expect(garden.thirsty(at: at(12).addingTimeInterval(seconds - 1)).isEmpty)
    #expect(garden.thirsty(at: at(12).addingTimeInterval(seconds)) == [deskPlant])
}

@Test func wateringAThirstyPlantQuenchesItAndLeavesTheOthersThirsty() {
    var garden = Garden()
    garden.adopt(allPlants, at: at(0), random: { 0 })  // all thirsty from 03:00
    garden.watered(deskPlant, at: at(4), random: { 0 })
    #expect(Set(garden.thirsty(at: at(4))) == [otherDeskPlant, windowPlant])
    #expect(garden.thirsty(at: at(6, 59)).contains(deskPlant) == false)
    #expect(garden.thirsty(at: at(7)).contains(deskPlant))
}

@Test func theGardenKeepsItsThirstAcrossALaunchAndAMonthAwayLooksLikeAWeekend() throws {
    var garden = Garden()
    garden.adopt(allPlants, at: at(12), random: { 0.5 })
    let saved = try JSONEncoder().encode(garden)
    var relaunched = try JSONDecoder().decode(Garden.self, from: saved)
    relaunched.adopt(allPlants, at: at(12).addingTimeInterval(30 * 86_400), random: { 0 })  // known plants stay as they were
    let weekend = relaunched.thirsty(at: at(12).addingTimeInterval(3 * 86_400))
    let month = relaunched.thirsty(at: at(12).addingTimeInterval(30 * 86_400))
    #expect(Set(weekend) == Set(allPlants))
    #expect(Set(month) == Set(allPlants))
}
