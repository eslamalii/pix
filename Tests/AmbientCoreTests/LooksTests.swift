import Testing
import AmbientCore

// The values Pix looks by: the Moment table and the time-of-day tables must not change how Pix looks.

@Test func aPetPlaysThreeTimesWithHeartsAndIsCaptionedPet() {
    #expect(Moment.reaction(.pet).look == MomentLook(body: "pet", loops: 3, extra: .hearts, caption: Caption(emote: "heart", word: "PET")))
}

@Test func aHuffTurnsAwayAndIsCaptionedHmph() {
    #expect(Moment.reaction(.huff).look == MomentLook(body: "huff", loops: 3, extra: .turnAway, caption: Caption(emote: "steam", word: "HMPH")))
}

@Test func shhAndHelloShowTheExclaimEmoteOverPixsHead() {
    #expect(Moment.reaction(.shh).look.emote == "exclaim")
    #expect(Moment.greeting(.hello).look == MomentLook(body: "wave", loops: 2, emote: "exclaim", caption: Caption(emote: "exclaim", word: "HELLO")))
}

@Test func aCoffeeBreakSteamsForEightLoops() {
    #expect(Moment.pause(.coffee).look == MomentLook(body: "coffee", loops: 8, extra: .steam, caption: Caption(emote: "coffee", word: "BREAK")))
}

@Test func pluggingInHopsWithABoltCaptionedCharge() {
    #expect(Moment.charging.look == MomentLook(body: "jump", loops: 2, emote: "bolt", extra: .hop, caption: Caption(emote: "bolt", word: "CHARGE")))
    #expect(Art.emotes.contains("bolt"))
}

@Test func focusOpensWithFocusAndEndsWithAStretchCaptionedDone() {
    #expect(Moment.focusStarted.look.caption == Caption(emote: "exclaim", word: "FOCUS"))
    #expect(Moment.focusDone.look == MomentLook(body: "stretch", loops: 4, extra: .hearts, caption: Caption(emote: "star", word: "DONE")))
}

@Test func theMemoryGreetingsAreCaptionedBackEarlyAndWeekend() {
    #expect(Moment.greeting(.missedYou).look == MomentLook(body: "wave", loops: 3, extra: .hearts, caption: Caption(emote: "heart", word: "BACK")))
    #expect(Moment.greeting(.early).look.caption == Caption(emote: "exclaim", word: "EARLY"))
    #expect(Moment.greeting(.weekend).look.caption == Caption(emote: "star", word: "WEEKEND"))
}

@Test func occasionsAreCaptionedBooHoHoAndCheers() {
    #expect(Moment.greeting(.halloween).look == MomentLook(body: "jump", loops: 2, emote: "pumpkin", extra: .hop, caption: Caption(emote: "pumpkin", word: "BOO")))
    #expect(Moment.greeting(.holidays).look.caption == Caption(emote: "star", word: "HO HO"))
    #expect(Moment.greeting(.newYear).look.caption == Caption(emote: "star", word: "CHEERS"))
    #expect(Art.emotes.contains("pumpkin"))
}

@Test func theAgentAskingWavesWithExclaimAndItsDoneHopsWithAStar() {
    #expect(Moment.agentAsks.look == MomentLook(body: "wave", loops: 3, emote: "exclaim", caption: Caption(emote: "exclaim", word: "ASKING")))
    #expect(Moment.agentDone.look.caption == Caption(emote: "star", word: "DONE"))
}

@Test func aFailedAgentScratchesItsHeadWithOops() {
    #expect(Moment.agentFailed.look == MomentLook(body: "scratch", loops: 3, emote: "exclaim", caption: Caption(emote: "exclaim", word: "OOPS")))
}

@Test func aNewHatHopsWithAStarCaptionedNewHat() {
    #expect(Moment.newHat.look == MomentLook(body: "jump", loops: 3, emote: "star", extra: .hop, caption: Caption(emote: "star", word: "NEW HAT")))
}

@Test func overheatingHuffsInSteamCaptionedHot() {
    #expect(Moment.overheated.look == MomentLook(body: "huff", loops: 3, emote: "steam", extra: .steam, caption: Caption(emote: "steam", word: "HOT")))
}

@Test func aJumpHops() {
    #expect(Moment.reaction(.jump).look.extra == .hop)
}

@Test(arguments: [(5, Daylight.night), (6, .dawn), (7, .dawn), (8, .day), (16, .day), (17, .dusk), (19, .dusk), (20, .night), (0, .night)])
func theSkyFollowsTheHour(hour: Int, daylight: Daylight) {
    #expect(Daylight(hour: hour) == daylight)
}

// MARK: - At rest

@Test(arguments: [(Spot.desk, "type"), (.call, "call"), (.couch, "couch"), (.musicCorner, "bob")])
func atRestEachSpotHasItsBody(spot: Spot, body: String) {
    #expect(RestLook(spot: spot, mood: .content).body == body)
}

@Test func atTheWindowPixStrollsRatherThanRestingInOnePose() {
    #expect(RestLook(spot: .window, mood: .content).body == nil)
}

@Test func sleepyAtTheMusicCornerPixDozes() {
    #expect(RestLook(spot: .musicCorner, mood: .sleepy).body == "idle")
}

@Test func whileAnAgentWorksPixTypesTwiceAsFast() {
    #expect(RestLook(spot: .desk, mood: .content).speedUp == 1)
    #expect(RestLook(spot: .desk, mood: .content, agentWorking: true).speedUp == 2)
}

@Test(arguments: [(Spot.desk, true), (.call, true), (.couch, true), (.musicCorner, false), (.window, false)])
func theFaceGlowsWhereAScreenLightsIt(spot: Spot, glows: Bool) {
    #expect(RestLook(spot: spot, mood: .content).faceGlows == glows)
}

@Test func sleepyPixDriftsZzzAndAHotOneSteams() {
    #expect(RestLook(spot: .window, mood: .sleepy).particles == ["zzz"])
    #expect(RestLook(spot: .desk, mood: .content, hot: true).particles == ["steam"])
    #expect(RestLook(spot: .desk, mood: .sleepy, hot: true).particles == ["zzz", "steam"])
    #expect(RestLook(spot: .desk, mood: .content).particles.isEmpty)
}
