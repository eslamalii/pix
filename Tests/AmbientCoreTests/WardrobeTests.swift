import Testing
@testable import AmbientCore

@Test func wardrobeRestoresOnlyAWearableHatWithoutOwingANewHat() {
    let memory = remembering(arrivals: (0..<3).map { day($0, 9) })
    var wardrobe = Wardrobe(wearing: .cap, memory: memory, allHats: false)
    #expect(wardrobe.worn == .cap)
    #expect(wardrobe.wearable(by: memory) == [.cap])
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == nil)
    #expect(Wardrobe(wearing: .crown, memory: memory, allHats: false).worn == nil)
}

@Test func wardrobeAllowsEarnedHatChoicesAndTakingTheHatOff() {
    let memory = remembering(arrivals: (0..<3).map { day($0, 9) })
    var wardrobe = Wardrobe(wearing: .cap, memory: memory, allHats: false)
    wardrobe.choose(.crown, memory: memory)
    #expect(wardrobe.worn == .cap)
    wardrobe.choose(nil, memory: memory)
    #expect(wardrobe.worn == nil)
    wardrobe.choose(.cap, memory: memory)
    #expect(wardrobe.worn == .cap)
}

@Test func wardrobeWearsANewHatAndCelebratesInsteadOfTheEarningMomentOnlyOnce() {
    var memory = Memory()
    for _ in 0..<24 { memory.petted(at: day(0, 12), calendar: enUS) }
    let before = memory
    var wardrobe = Wardrobe(wearing: nil, memory: before, allHats: false)
    memory.petted(at: day(0, 12), calendar: enUS)
    #expect(wardrobe.moment(.reaction(.pet), from: before, to: memory, onRoom: true) == .newHat)
    #expect(wardrobe.worn == .party)
    #expect(wardrobe.moment(.reaction(.pet), from: memory, to: memory, onRoom: true) == .reaction(.pet))
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == nil)
}

@Test func wardrobeKeepsTheGreetingAndOtherMomentsAheadOfAnOwedNewHat() {
    let before = remembering(arrivals: [day(0, 9), day(1, 9)])
    var memory = before
    var wardrobe = Wardrobe(wearing: nil, memory: before, allHats: false)
    memory.arrive(at: day(2, 9), calendar: enUS)
    let greeting = Moment.greeting(.hello, after: .gaze)
    #expect(wardrobe.moment(greeting, from: before, to: memory, onRoom: true) == greeting)
    #expect(wardrobe.worn == .cap)
    #expect(wardrobe.moment(.reaction(.wave), from: memory, to: memory, onRoom: true) == .reaction(.wave))
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == .newHat)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == nil)
}

@Test func wardrobeWaitsForTheRoomToCelebrateAHatEarnedOnTheDefaultBar() {
    var memory = Memory()
    for _ in 0..<9 { memory.finishedFocus() }
    let before = memory
    var wardrobe = Wardrobe(wearing: nil, memory: before, allHats: false)
    memory.finishedFocus()
    #expect(wardrobe.moment(nil, from: before, to: memory, onRoom: false) == nil)
    #expect(wardrobe.worn == .headband)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: false) == nil)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == .newHat)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == nil)
}

@Test func wardrobeWearsTheLastOfHatsEarnedTogetherAndOwesOneCelebration() {
    let before = remembering(arrivals: [day(17, 9), day(18, 9)])
    var memory = before
    var wardrobe = Wardrobe(wearing: nil, memory: before, allHats: false)
    memory.arrive(at: day(19, 9), calendar: enUS) // Halloween and the third day together.
    #expect(wardrobe.moment(.greeting(.halloween), from: before, to: memory, onRoom: true) == .greeting(.halloween))
    #expect(wardrobe.wearable(by: memory) == [.cap, .witch])
    #expect(wardrobe.worn == .witch)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == .newHat)
    #expect(wardrobe.moment(nil, from: memory, to: memory, onRoom: true) == nil)
}

@Test func wardrobeGivesBackAForgottenHatAndCancelsItsOwedCelebration() {
    let before = Memory()
    var memory = before
    var wardrobe = Wardrobe(wearing: nil, memory: before, allHats: false)
    memory.arrive(at: day(19, 9), calendar: enUS)
    #expect(wardrobe.moment(.greeting(.halloween), from: before, to: memory, onRoom: true) == .greeting(.halloween))
    #expect(wardrobe.worn == .witch)
    let forgotten = Memory()
    #expect(wardrobe.moment(nil, from: memory, to: forgotten, onRoom: true) == nil)
    #expect(wardrobe.worn == nil)
    #expect(wardrobe.wearable(by: forgotten).isEmpty)
    #expect(wardrobe.moment(nil, from: forgotten, to: forgotten, onRoom: true) == nil)
}

@Test func wardrobeWithAllHatsAllowsEveryChoiceButStillCancelsForgottenCelebrations() {
    let before = Memory()
    var memory = before
    var wardrobe = Wardrobe(wearing: .crown, memory: before, allHats: true)
    #expect(wardrobe.worn == .crown)
    #expect(wardrobe.wearable(by: before) == Hat.allCases)
    wardrobe.choose(.topHat, memory: before)
    #expect(wardrobe.worn == .topHat)
    #expect(wardrobe.moment(nil, from: before, to: before, onRoom: true) == nil)
    memory.arrive(at: day(19, 9), calendar: enUS)
    #expect(wardrobe.moment(.greeting(.halloween), from: before, to: memory, onRoom: true) == .greeting(.halloween))
    #expect(wardrobe.worn == .witch)
    let forgotten = Memory()
    #expect(wardrobe.moment(nil, from: memory, to: forgotten, onRoom: true) == nil)
    #expect(wardrobe.worn == .witch)
    #expect(wardrobe.wearable(by: forgotten) == Hat.allCases)
}
