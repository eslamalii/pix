import Foundation
import Testing
import AmbientCore

/// A calendar with Saturday and Sunday as the weekend, whatever the machine's region.
let enUS: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    (calendar.timeZone, calendar.locale) = (utc, Locale(identifier: "en_US"))
    return calendar
}()

/// `days` after Monday 2026-10-12, at hh:mm UTC: 4 is Friday, 5 Saturday, 7 the next Monday.
func day(_ days: Int, _ h: Int, _ m: Int = 0) -> Date { at(h, m) + Double(days) * 86_400 }

func remembering(arrivals: [Date]) -> Memory {
    var memory = Memory()
    for time in arrivals { memory.arrive(at: time, calendar: enUS) }
    return memory
}

/// What the arrival at `time` would be greeted with, leaving `memory` as it was.
func firstGreeting(_ memory: Memory, at time: Date) -> Greeting? {
    var memory = memory
    return memory.arrive(at: time, calendar: enUS)
}

@Test func theFirstArrivalEverIsNotSpecialAndPixRemembersTheDayAndTime() {
    var memory = Memory()
    #expect(memory.arrive(at: day(0, 9), calendar: enUS) == nil)
    #expect(memory.days == ["2026-10-12"])
    #expect(memory.arrivals == ["2026-10-12": 540])
}

@Test func onlyTheDaysFirstArrivalCanBeSpecialOrNoteItsTime() {
    var memory = remembering(arrivals: [day(-5, 9)])  // last seen the Wednesday before
    #expect(memory.arrive(at: day(0, 9), calendar: enUS) == .missedYou)
    #expect(memory.arrive(at: day(0, 14), calendar: enUS) == nil)
    #expect(memory.arrivals["2026-10-12"] == 540)
}

@Test func backAfterFourDaysAwayButNotAfterAWeekend() {
    #expect(firstGreeting(remembering(arrivals: [day(-4, 9)]), at: day(0, 9)) == .missedYou)  // Thursday to Monday
    #expect(firstGreeting(remembering(arrivals: [day(-3, 9)]), at: day(0, 9)) == nil)        // Friday to Monday
}

@Test func theWeekendGetsItsOwnGreetingAndNoArrivalTime() {
    var memory = remembering(arrivals: [day(4, 9)])
    #expect(memory.arrive(at: day(5, 10), calendar: enUS) == .weekend)
    #expect(memory.days.last == "2026-10-17")
    #expect(memory.arrivals["2026-10-17"] == nil)
}

@Test func earlyIsFortyFiveMinutesBeforeTheUsualArrivalOnceThereAreFive() {
    let week = remembering(arrivals: (0...4).map { day($0, 9) })
    #expect(week.usualArrival == 540)
    #expect(firstGreeting(week, at: day(7, 8, 15)) == .early)
    #expect(firstGreeting(week, at: day(7, 8, 16)) == nil)
    let fourDays = remembering(arrivals: (0...3).map { day($0, 9) })
    #expect(fourDays.usualArrival == nil)
    #expect(firstGreeting(fourDays, at: day(4, 6)) == nil)
}

@Test func anOccasionBeatsWhatPixRemembersOnTheDaysFirstArrivalOnly() {
    var memory = remembering(arrivals: [day(9, 9)])  // last seen ten days before Halloween
    #expect(memory.arrive(at: day(19, 9), calendar: enUS) == .halloween)
    #expect(memory.arrive(at: day(19, 14), calendar: enUS) == nil)
    #expect(memory.occasions == [.halloween])
}

@Test func theUsualArrivalIsTheMedian() {
    let times = [day(0, 8), day(1, 9), day(2, 9, 30), day(3, 10), day(4, 11)]
    #expect(remembering(arrivals: times).usualArrival == 570)
}

@Test func aDayOfPetsMakesTheNextMorningCheerful() {
    var memory = remembering(arrivals: [day(0, 9)])
    for i in 1...4 { memory.petted(at: day(0, 10, i), calendar: enUS) }
    #expect(firstGreeting(memory, at: day(1, 9)) == nil)
    memory.petted(at: day(0, 11), calendar: enUS)
    #expect(firstGreeting(memory, at: day(1, 9)) == .cheerful)
    #expect(firstGreeting(memory, at: day(2, 9)) == nil)  // only the day after
}

@Test func backBeatsEarlyAndEarlyBeatsPets() {
    var memory = remembering(arrivals: (0...4).map { day($0, 9) })
    for i in 1...5 { memory.petted(at: day(6, 10, i), calendar: enUS) }  // a Sunday of Pets, without arriving
    #expect(firstGreeting(memory, at: day(7, 8)) == .early)
    #expect(firstGreeting(memory, at: day(9, 8)) == .missedYou)
}

@Test func pixRemembersSixtyDaysTwentyArrivalsAndFourteenDaysOfPets() {
    var memory = Memory()
    for d in 0..<70 {
        memory.arrive(at: day(d, 9), calendar: enUS)
        memory.petted(at: day(d, 10), calendar: enUS)
    }
    #expect(memory.days.count == 60)
    #expect(memory.days.last == "2026-12-20")
    #expect(memory.arrivals.count == 20)
    #expect(memory.pets.count == 14)
    #expect(memory.pets["2026-12-20"] == 1)
}

@Test func memoryRoundTripsThroughJSON() throws {
    var memory = remembering(arrivals: [day(0, 9), day(1, 9, 30)])
    memory.petted(at: day(1, 10), calendar: enUS)
    let copy = try JSONDecoder().decode(Memory.self, from: JSONEncoder().encode(memory))
    #expect(copy == memory)
}

// MARK: - Hats

@Test func hatsAreEarnedByDaysTogetherOrPets() {
    var memory = Memory()
    for d in 0..<2 { memory.arrive(at: day(d, 9), calendar: enUS) }
    #expect(Hat.earned(by: memory) == [])
    memory.arrive(at: day(2, 9), calendar: enUS)
    #expect(Hat.earned(by: memory) == [.cap])
    for i in 0..<25 { memory.petted(at: day(2, 10) + Double(i), calendar: enUS) }
    #expect(Hat.earned(by: memory) == [.cap, .party])
    #expect(Hat.crown.howToEarn == "30 days together")
    #expect(Hat.flower.howToEarn == "100 Pets")
}

@Test func flyingBackOverTheDateLineToADayAlreadySeenIsNotANewDayTogether() {
    var memory = remembering(arrivals: [day(0, 9)])  // Monday
    var auckland = enUS, honolulu = enUS
    auckland.timeZone = TimeZone(secondsFromGMT: 13 * 3600)!
    honolulu.timeZone = TimeZone(secondsFromGMT: -10 * 3600)!
    memory.arrive(at: day(0, 12), calendar: auckland)                  // already Tuesday in Auckland
    #expect(memory.arrive(at: day(0, 22), calendar: honolulu) == nil)  // and still Monday on landing in Honolulu
    #expect(memory.days == ["2026-10-12", "2026-10-13"])
    #expect(memory.totalDays == 2)
}

@Test func theTotalsOutliveTheTrimmedDays() {
    var memory = Memory()
    for d in 0..<70 { memory.arrive(at: day(d, 9), calendar: enUS) }
    #expect(memory.days.count == 60)
    #expect(memory.totalDays == 70)
    #expect(Hat.earned(by: memory).contains(.crown))
}

@Test func aMemorySavedBeforeTheTotalsStillReadsAndCountsWhatItHas() throws {
    let saved = #"{"days":["2026-10-12","2026-10-13","2026-10-14"],"arrivals":{},"pets":{"2026-10-14":4}}"#
    let memory = try JSONDecoder().decode(Memory.self, from: Data(saved.utf8))
    #expect(memory.totalDays == 3)
    #expect(memory.totalPets == 4)
    #expect(Hat.earned(by: memory) == [.cap])
}

@Test func aMemorySavedBeforeFocusSessionsAndOccasionsStillReads() throws {
    let saved = #"{"days":["2026-10-12"],"arrivals":{},"pets":{},"totalDays":12,"totalPets":40}"#
    let memory = try JSONDecoder().decode(Memory.self, from: Data(saved.utf8))
    #expect(memory.totalFocusSessions == 0)
    #expect(memory.occasions.isEmpty)
    #expect(Hat.earned(by: memory) == [.cap, .beanie, .party])
}

@Test func focusSessionsAndOccasionsRoundTripThroughJSON() throws {
    var memory = Memory()
    memory.saw(at: day(19, 9), calendar: enUS)  // Halloween
    memory.finishedFocus()
    let copy = try JSONDecoder().decode(Memory.self, from: JSONEncoder().encode(memory))
    #expect(copy == memory)
    #expect(copy.occasions == [.halloween])
    #expect(copy.totalFocusSessions == 1)
}

@Test func everyHatSaysHowToEarnIt() {
    #expect(Hat.allCases.map(\.howToEarn) == [
        "3 days together", "7 days together", "25 Pets", "100 Pets", "30 days together",
        "10 Focus sessions", "Halloween together", "the holidays together", "New Year's Day together",
    ])
}

@Test func pixWearsItsHatInEveryPoseButTheCallsHeadset() {
    #expect(Art.bodies.map(\.name).filter { !Art.wearsHat($0) } == ["call"])
}

@Test(arguments: [(16, true), (80, true), (144, true), (0, false), (40, false), (160, false)])
func aSkinsHatsMayStopEarlyButNotRunPastPixsOwn(width: Int, fits: Bool) {
    #expect(Art.skinFits("hats", width: width, height: 6, bundled: (144, 6)) == fits)
    #expect(!Art.skinFits("hats", width: 80, height: 7, bundled: (144, 6)))
}
