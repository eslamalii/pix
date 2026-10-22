import Foundation
import Testing
import AmbientCore

let selfID = "io.github.eslamalii.Pix"
let charger = Power(onBattery: false, lowPowerMode: false)
let battery = Power(onBattery: true, lowPowerMode: false)
let utc = TimeZone(identifier: "UTC")!

/// Monday 2026-10-12 at hh:mm:ss UTC. Noon is a plain "content" hour.
func at(_ h: Int, _ m: Int = 0, _ s: Int = 0) -> Date {
    Date(timeIntervalSince1970: 1_791_763_200 + Double(h * 3600 + m * 60 + s))
}

func launched(in frontApp: String?, at time: Date = at(12), power: Power = charger) -> Controller {
    Controller(selfBundleID: selfID, frontApp: frontApp, power: power, at: time, timeZone: utc)
}

func room(_ spot: Spot, _ activity: Activity, _ mood: Mood = .content, fps: Int = 12) -> Bar {
    .room(Room(spot: spot, activity: activity, mood: mood, fps: fps))
}

// MARK: - Activity, power and the clock

@Test func launchingInACodingAppOnTheChargerShowsPixAtTheDeskAt12fps() {
    #expect(launched(in: "com.microsoft.VSCode").bar == room(.desk, .coding))
}

@Test func onBatteryPixAnimatesAt10fps() {
    #expect(launched(in: "com.microsoft.VSCode", power: battery).bar == room(.desk, .coding, fps: 10))
}

@Test func lowPowerModeAnimatesAt6fpsEvenOnBattery() {
    let lowPowerOnBattery = Power(onBattery: true, lowPowerMode: true)
    #expect(launched(in: "com.microsoft.VSCode", power: lowPowerOnBattery).bar == room(.desk, .coding, fps: 6))
}

@Test func tappingAnywhereButPixHandsBackTheDefaultBar() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.tappedElsewhere, at: at(12, 1))
    #expect(c.bar == .defaultBar)
}

@Test func switchingAppsAfterHandingBackBringsPixBackAtTheNewAppsSpot() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.tappedElsewhere, at: at(12, 1))
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 2))
    #expect(c.bar == room(.window, .browsing))
}

@Test(arguments: [
    ("com.microsoft.VSCode", Activity.coding), ("com.apple.dt.Xcode", .coding), ("com.apple.Terminal", .coding),
    ("com.googlecode.iterm2", .coding), ("dev.warp.Warp-Stable", .coding), ("dev.zed.Zed", .coding),
    ("com.mitchellh.ghostty", .coding), ("com.todesktop.230313mzl4w4u92", .coding), ("com.jetbrains.intellij", .coding),
    ("com.jetbrains.WebStorm", .coding),
    ("com.apple.Safari", .browsing), ("com.google.Chrome", .browsing), ("company.thebrowser.Browser", .browsing),
    ("org.mozilla.firefox", .browsing), ("com.brave.Browser", .browsing), ("com.microsoft.edgemac", .browsing),
    ("com.spotify.client", .music), ("com.apple.Music", .music), ("com.apple.podcasts", .music),
    ("com.apple.finder", .other), ("com.apple.mail", .other),
])
func eachAppMapsToItsActivity(app: String, activity: Activity) {
    var c = launched(in: "com.apple.finder")
    c.handle(.frontAppChanged(app), at: at(12, 1))
    guard case .room(let shown) = c.bar else { Issue.record("expected the Room"); return }
    #expect(shown.activity == activity)
}

@Test(arguments: ["us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams", "com.apple.FaceTime", "Cisco-Systems.Spark"])
func aMeetingAppPutsPixOnACallAtTheDesk(app: String) {
    #expect(launched(in: app).bar == room(.call, .meeting))
}

@Test(arguments: [at(7), at(12), at(23, 30)])  // cheerful, content and sleepy hours
func onACallATapOnPixAlwaysGetsShh(time: Date) {
    var c = launched(in: "com.apple.FaceTime", at: time)
    #expect(c.handle(.pixTapped, at: time + 1) == .reaction(.shh))
}

@Test func onACallFiveQuickTapsStillMakePixDizzyAndAPetIsStillAPet() {
    var c = launched(in: "us.zoom.xos")
    for i in 0..<4 { c.handle(.pixTapped, at: at(12, 1) + Double(i) * 0.5) }
    #expect(c.handle(.pixTapped, at: at(12, 1) + 2) == .reaction(.dizzy))
    #expect(c.handle(.pixPetted, at: at(12, 2)) == .reaction(.pet))
}

@Test func anUnknownFrontAppIsOtherAtTheWindow() {
    #expect(launched(in: nil).bar == room(.window, .other))
}

@Test func ourOwnAppComingToTheFrontChangesNothing() {
    var showing = launched(in: "com.microsoft.VSCode")
    showing.handle(.frontAppChanged(selfID), at: at(12, 1))
    #expect(showing.bar == room(.desk, .coding))

    var handedBack = launched(in: "com.microsoft.VSCode")
    handedBack.handle(.tappedElsewhere, at: at(12, 1))
    handedBack.handle(.frontAppChanged(selfID), at: at(12, 2))
    #expect(handedBack.bar == .defaultBar)
}

@Test func tappingSparklesBringsPixBackWithoutSwitchingApps() {
    var c = launched(in: "com.spotify.client")
    c.handle(.tappedElsewhere, at: at(12, 1))
    c.handle(.sparklesTapped, at: at(12, 2))
    #expect(c.bar == room(.musicCorner, .music))
}

@Test func unpluggingDropsTheFrameRateRightAway() {
    var c = launched(in: "com.microsoft.VSCode", power: charger)
    c.handle(.powerChanged(battery), at: at(12, 1))
    #expect(c.bar == room(.desk, .coding, fps: 10))
}

@Test func aPowerChangeWhileHandedBackKeepsTheDefaultBarButIsRemembered() {
    var c = launched(in: "com.microsoft.VSCode", power: charger)
    c.handle(.tappedElsewhere, at: at(12, 1))
    c.handle(.powerChanged(battery), at: at(12, 2))
    #expect(c.bar == .defaultBar)
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 3))
    #expect(c.bar == room(.window, .browsing, fps: 10))
}

@Test func sleepingHidesPixAndWakingBringsItBack() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.screenSlept, at: at(12, 1))
    #expect(c.bar == .defaultBar)
    c.handle(.screenWoke, at: at(12, 2))
    #expect(c.bar == room(.desk, .coding))
}

@Test func wakingAfterHandingBackKeepsTheDefaultBar() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.tappedElsewhere, at: at(12, 1))
    c.handle(.screenSlept, at: at(12, 2))
    c.handle(.screenWoke, at: at(12, 3))
    #expect(c.bar == .defaultBar)
}

@Test func switchingAppsWhileAsleepShowsTheNewSpotOnlyAfterWaking() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.screenSlept, at: at(12, 1))
    c.handle(.frontAppChanged("com.spotify.client"), at: at(12, 2))
    #expect(c.bar == .defaultBar)
    c.handle(.screenWoke, at: at(12, 3))
    #expect(c.bar == room(.musicCorner, .music))
}

@Test func theScreenWakingWhileStillLockedKeepsTheDefaultBar() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.locked, at: at(12, 1))
    c.handle(.screenSlept, at: at(12, 2))
    c.handle(.screenWoke, at: at(12, 3))
    #expect(c.bar == .defaultBar)
    c.handle(.unlocked, at: at(12, 4))
    #expect(c.bar == room(.desk, .coding))
}

// MARK: - Mood

@Test(arguments: [(at(22, 59), Mood.content), (at(23, 0), .sleepy), (at(2, 30), .sleepy), (at(4, 59), .sleepy), (at(5, 0), .content)])
func pixIsSleepyFrom23To5(time: Date, mood: Mood) {
    #expect(launched(in: "com.apple.finder", at: time).bar == room(.window, .other, mood))
}

@Test(arguments: [(at(5, 59), Mood.content), (at(6, 0), .cheerful), (at(9, 59), .cheerful), (at(10, 0), .content)])
func pixIsCheerfulFrom6To10(time: Date, mood: Mood) {
    #expect(launched(in: "com.apple.finder", at: time).bar == room(.window, .other, mood))
}

@Test func theClockTickMovesTheMoodWithTheTimeOfDay() {
    var c = launched(in: "com.apple.finder", at: at(22, 58))
    #expect(c.bar == room(.window, .other, .content))
    c.handle(.clockTick, at: at(23, 0))
    #expect(c.bar == room(.window, .other, .sleepy))
}

// MARK: - Session and focus

@Test func pixBecomesFocusedAfter45MinutesOfCoding() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.clockTick, at: at(12, 44, 59))
    #expect(c.bar == room(.desk, .coding, .content))
    c.handle(.clockTick, at: at(12, 45))
    #expect(c.bar == room(.desk, .coding, .focused))
}

@Test func onlyCodingSessionsMakePixFocused() {
    var c = launched(in: "com.apple.Safari", at: at(12, 0))
    c.handle(.clockTick, at: at(13, 30))
    #expect(c.bar == room(.window, .browsing, .content))
}

@Test func aShortTripAwayKeepsTheCodingSessionButTheTimeAwayDoesNotCount() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))       // 40 min of coding…
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 40))     // …4:59 in the browser…
    c.handle(.frontAppChanged("com.microsoft.VSCode"), at: at(12, 44, 59))
    c.handle(.clockTick, at: at(12, 49, 58))                            // 44:59 coded
    #expect(c.bar == room(.desk, .coding, .content))
    c.handle(.clockTick, at: at(12, 49, 59))                            // 45:00 coded
    #expect(c.bar == room(.desk, .coding, .focused))
}

@Test func fiveMinutesAwayStartsTheSessionOver() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 40))
    c.handle(.frontAppChanged("com.microsoft.VSCode"), at: at(12, 45))
    c.handle(.clockTick, at: at(13, 29, 59))
    #expect(c.bar == room(.desk, .coding, .content))
    c.handle(.clockTick, at: at(13, 30))
    #expect(c.bar == room(.desk, .coding, .focused))
}

@Test func sleepingCountsAsTimeAwayFromTheSession() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.screenSlept, at: at(12, 30))
    c.handle(.screenWoke, at: at(20, 0))       // a long night: the Session starts over
    c.handle(.clockTick, at: at(20, 44, 59))
    #expect(c.bar == room(.desk, .coding, .content))

    var nap = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    nap.handle(.locked, at: at(12, 30))
    nap.handle(.unlocked, at: at(12, 32))      // a quick lock keeps it, minus the 2 minutes
    nap.handle(.clockTick, at: at(12, 47))
    #expect(nap.bar == room(.desk, .coding, .focused))
}

@Test func anAppSwitchWhileAsleepDoesNotStartTheSessionClock() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.screenSlept, at: at(12, 1))
    c.handle(.frontAppChanged("com.microsoft.VSCode"), at: at(12, 2))
    c.handle(.screenWoke, at: at(20, 0))
    c.handle(.clockTick, at: at(20, 44, 59))
    #expect(c.bar == room(.desk, .coding, .content))
}

// MARK: - Grumpy

/// Scattered switching: cycles Mail, Notes and Finder (all "other"), so only the switching itself changes.
func switches(_ c: inout Controller, at times: [Date]) {
    let apps = ["com.apple.mail", "com.apple.Notes", "com.apple.finder"]
    for (i, time) in times.enumerated() { c.handle(.frontAppChanged(apps[i % apps.count]), at: time) }
}

/// Normal work: back and forth between the same two apps.
func pingPong(_ c: inout Controller, at times: [Date]) {
    for (i, time) in times.enumerated() { c.handle(.frontAppChanged(i.isMultiple(of: 2) ? "com.apple.mail" : "com.apple.finder"), at: time) }
}

@Test func sixSwitchesWithinTwoMinutesMakePixGrumpy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: [at(12, 0, 10), at(12, 0, 30), at(12, 0, 50), at(12, 1, 10), at(12, 1, 30)])
    #expect(c.bar == room(.window, .other, .content))
    switches(&c, at: [at(12, 1, 50)])
    #expect(c.bar == room(.window, .other, .grumpy))
}

@Test func switchesSpreadOverMoreThanTwoMinutesDoNotCount() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: [at(12, 0, 0), at(12, 0, 30), at(12, 1, 0), at(12, 1, 30), at(12, 2, 0), at(12, 2, 1)])
    #expect(c.bar == room(.window, .other, .content))
}

@Test func grumpyCalmsDownAfterTwoMinutesWithoutSwitching() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...6).map { at(12, 0, $0 * 10) })   // last switch at 12:01:00
    c.handle(.clockTick, at: at(12, 2, 59))
    #expect(c.bar == room(.window, .other, .grumpy))
    c.handle(.clockTick, at: at(12, 3, 0))
    #expect(c.bar == room(.window, .other, .content))
}

@Test func oneSwitchAfterCalmingDownDoesNotMakePixGrumpyAgain() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...6).map { at(12, 0, $0 * 10) })   // grumpy, last switch at 12:01:00
    switches(&c, at: [at(12, 5, 0)])                        // calm for 4 minutes, then one switch
    #expect(c.bar == room(.window, .other, .content))
}

// MARK: - Which Mood wins

@Test func codingLateAtNightIsSleepyNotFocused() {
    var c = launched(in: "com.microsoft.VSCode", at: at(0, 10))
    c.handle(.clockTick, at: at(1, 0))   // 50 minutes of coding at 01:00
    #expect(c.bar == room(.desk, .coding, .sleepy))
}

@Test func switchingALotInTheMorningIsGrumpyNotCheerful() {
    var c = launched(in: "com.apple.finder", at: at(7, 0))
    switches(&c, at: (1...6).map { at(7, 0, $0 * 10) })
    #expect(c.bar == room(.window, .other, .grumpy))
}

@Test func grumpyBeatsSleepy() {
    var c = launched(in: "com.apple.finder", at: at(1, 0))
    switches(&c, at: (1...6).map { at(1, 0, $0 * 10) })
    #expect(c.bar == room(.window, .other, .grumpy))
}

@Test func focusedBeatsAMorningCheer() {
    var c = launched(in: "com.microsoft.VSCode", at: at(7, 0))
    c.handle(.clockTick, at: at(7, 45))
    #expect(c.bar == room(.desk, .coding, .focused))
}

// MARK: - Reactions

@Test func aTapOnPixGetsTheReactionForItsMood() {
    var content = launched(in: "com.apple.finder", at: at(12, 0))
    #expect(content.handle(.pixTapped, at: at(12, 1)) == .reaction(.wave))

    var cheerful = launched(in: "com.apple.finder", at: at(7, 0))
    #expect(cheerful.handle(.pixTapped, at: at(7, 1)) == .reaction(.jump))

    var focused = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    focused.handle(.clockTick, at: at(12, 45))
    #expect(focused.handle(.pixTapped, at: at(12, 46)) == .reaction(.shh))

    var sleepy = launched(in: "com.apple.finder", at: at(1, 0))
    #expect(sleepy.handle(.pixTapped, at: at(1, 1)) == .reaction(.yawn))

    var grumpy = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&grumpy, at: (1...6).map { at(12, 0, $0 * 10) })
    #expect(grumpy.handle(.pixTapped, at: at(12, 1, 30)) == .reaction(.huff))
}

@Test func theFifthTapWithinThreeSecondsMakesPixDizzy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    let start = at(12, 1)
    for offset in [0, 0.5, 1, 1.5] { #expect(c.handle(.pixTapped, at: start + offset) == .reaction(.wave)) }
    #expect(c.handle(.pixTapped, at: start + 2) == .reaction(.dizzy))
}

@Test func tapsSpreadOverMoreThanThreeSecondsDoNotMakePixDizzy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    let start = at(12, 1)
    for offset in [0.0, 1, 2, 3] { c.handle(.pixTapped, at: start + offset) }
    #expect(c.handle(.pixTapped, at: start + 3.1) == .reaction(.wave))
}

@Test func aPetShowsAHeartAndMakesPixCheerfulForTenMinutes() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    #expect(c.handle(.pixPetted, at: at(12, 1)) == .reaction(.pet))
    #expect(c.bar == room(.window, .other, .cheerful))
    c.handle(.clockTick, at: at(12, 10, 59))
    #expect(c.bar == room(.window, .other, .cheerful))
    c.handle(.clockTick, at: at(12, 11))
    #expect(c.bar == room(.window, .other, .content))
}

@Test func aPetDoesNotOutrankAStrongerMood() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.clockTick, at: at(12, 45))
    #expect(c.handle(.pixPetted, at: at(12, 46)) == .reaction(.pet))
    #expect(c.bar == room(.desk, .coding, .focused))
}

// MARK: - Breaks

@Test func pixTakesABreakAtEvery45MinuteMarkAlternatingCoffeeAndStretch() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    #expect(c.handle(.clockTick, at: at(12, 44)) == nil)
    #expect(c.handle(.clockTick, at: at(12, 45)) == .pause(.coffee))
    #expect(c.handle(.clockTick, at: at(12, 46)) == nil)
    #expect(c.handle(.clockTick, at: at(13, 30)) == .pause(.stretch))
    #expect(c.handle(.clockTick, at: at(14, 15)) == .pause(.coffee))
}

@Test func breaksStartOverWithANewSession() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.clockTick, at: at(12, 45))                              // coffee
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 50))
    c.handle(.frontAppChanged("com.microsoft.VSCode"), at: at(13, 0)) // 10 minutes away: new Session
    #expect(c.handle(.clockTick, at: at(13, 44)) == nil)
    #expect(c.handle(.clockTick, at: at(13, 45)) == .pause(.coffee))
}

@Test func onlyCodingSessionsHaveBreaks() {
    var c = launched(in: "com.apple.Safari", at: at(12, 0))
    #expect(c.handle(.clockTick, at: at(12, 45)) == nil)
}

@Test func pixsLifeKeepsGoingWhileTheDefaultBarShows() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.tappedElsewhere, at: at(12, 5))
    c.handle(.clockTick, at: at(12, 45))
    c.handle(.sparklesTapped, at: at(12, 46))
    #expect(c.bar == room(.desk, .coding, .focused))
}

// MARK: - Review follow-ups

@Test func aPetCountsAsTwoTapsSoPokingFastAlsoMakesPixDizzy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    let start = at(12, 1)
    #expect(c.handle(.pixPetted, at: start) == .reaction(.pet))           // 2 taps
    #expect(c.handle(.pixPetted, at: start + 0.4) == .reaction(.pet))     // 4 taps
    #expect(c.handle(.pixTapped, at: start + 0.8) == .reaction(.dizzy))   // 5th tap
}

@Test func theFifthTapExactlyThreeSecondsAfterTheFirstStillCounts() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    let start = at(12, 1)
    for offset in [0.0, 1, 2, 2.5] { c.handle(.pixTapped, at: start + offset) }
    #expect(c.handle(.pixTapped, at: start + 3) == .reaction(.dizzy))
}

@Test func switchingToPixItselfDoesNotCountTowardGrumpy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...5).map { at(12, 0, $0 * 10) })
    c.handle(.frontAppChanged(selfID), at: at(12, 1))
    #expect(c.bar == room(.window, .other, .content))
}

// MARK: - Grumpy means scattered

@Test func pingPongingBetweenTwoAppsIsNotGrumpy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    pingPong(&c, at: (1...10).map { at(12, 0, $0 * 10) })   // Mail, Finder, Mail, … ten times
    #expect(c.bar == room(.window, .other, .content))
}

// MARK: - Greeting

@Test(arguments: [(at(12, 0), Greeting.hello), (at(7, 0), .cheerful), (at(1, 0), .sleepy)])
func pixGreetsYouWhenTheAppStartsInItsMood(time: Date, greeting: Greeting) {
    var c = launched(in: "com.apple.finder", at: time)
    #expect(c.handle(.appStarted, at: time) == .greeting(greeting))
}

@Test func pixGreetsYouAfterFiveMinutesAsleepButNotSooner() {
    var long = launched(in: "com.apple.finder", at: at(12, 0))
    long.handle(.screenSlept, at: at(12, 1))
    #expect(long.handle(.screenWoke, at: at(12, 6)) == .greeting(.hello, after: .gaze))

    var short = launched(in: "com.apple.finder", at: at(12, 0))
    short.handle(.screenSlept, at: at(12, 1))
    #expect(short.handle(.screenWoke, at: at(12, 5, 59)) == nil)
}

@Test func pixGreetsYouAfterALongLock() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.locked, at: at(12, 1))
    #expect(c.handle(.unlocked, at: at(12, 6)) == .greeting(.hello, after: .gaze))
}

@Test func sleepThenLockCountsAsOneAbsenceThatEndsOnUnlock() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.screenSlept, at: at(12, 1))
    c.handle(.locked, at: at(12, 2))
    #expect(c.handle(.screenWoke, at: at(12, 6)) == nil)              // still at the lock screen
    #expect(c.handle(.unlocked, at: at(12, 7)) == .greeting(.hello, after: .gaze))  // away since 12:01
}

@Test func noGreetingIfYouHadHandedBackTheBar() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.tappedElsewhere, at: at(12, 1))
    #expect(c.handle(.appStarted, at: at(12, 1)) == nil)
    c.handle(.screenSlept, at: at(12, 2))
    #expect(c.handle(.screenWoke, at: at(12, 30)) == nil)
    #expect(c.bar == .defaultBar)
}

@Test func comingBackLateAtNightGetsASleepyGreeting() {
    var c = launched(in: "com.apple.finder", at: at(0, 30))
    c.handle(.locked, at: at(0, 31))
    #expect(c.handle(.unlocked, at: at(1, 0)) == .greeting(.sleepy, after: .doze))
}

@Test func settlingIntoPingPongAfterScatteredSwitchingLetsPixCalmDown() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...6).map { at(12, 0, $0 * 10) })              // scattered: grumpy, last at 12:01:00
    pingPong(&c, at: (1...20).map { at(12, 1, 0) + Double($0 * 15) })  // then normal back-and-forth until 12:06
    // The last scattered moment was 12:02:45 (when Notes was still in the 2-minute window), so calm by 12:04:45.
    #expect(c.bar == room(.window, .other, .content))
}

@Test func sixSwitchesAcrossExactlyTwoAppsAreNotGrumpy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    pingPong(&c, at: (1...6).map { at(12, 0, $0 * 10) })
    #expect(c.bar == room(.window, .other, .content))
}

@Test func noGreetingAfterALockShorterThanFiveMinutes() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.locked, at: at(12, 1))
    #expect(c.handle(.unlocked, at: at(12, 5, 59)) == nil)
}

// MARK: - Pix uses its Room

@Test(arguments: ["com.colliderli.iina", "org.videolan.vlc", "com.apple.QuickTimePlayerX", "com.apple.TV", "com.firecore.infuse"])
func aVideoAppInFrontMeansWatchingOnTheCouch(app: String) {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.frontAppChanged(app), at: at(12, 1))
    #expect(c.bar == room(.couch, .watching))
}

@Test(arguments: ["com.spotify.client", "com.apple.Music", "com.apple.podcasts"])
func aMusicAppInFrontSendsPixToTheMusicCorner(app: String) {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.frontAppChanged(app), at: at(12, 1))
    #expect(c.bar == room(.musicCorner, .music))
}

@Test func aVideoInABrowserIsStillBrowsingAtTheWindow() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 1))
    #expect(c.bar == room(.window, .browsing))
}

@Test func aPetMakesUpWithAGrumpyPix() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...6).map { at(12, 0, $0 * 10) })   // grumpy, last switch at 12:01:00
    #expect(c.handle(.pixPetted, at: at(12, 1, 30)) == .reaction(.pet))
    #expect(c.bar == room(.window, .other, .cheerful))
}

@Test func afterMakingUpOneMoreSwitchIsForgivenButFreshScatteringIsNot() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...6).map { at(12, 0, $0 * 10) })   // grumpy, last switch at 12:01:00
    c.handle(.pixPetted, at: at(12, 1, 10))
    c.handle(.frontAppChanged("com.apple.mail"), at: at(12, 1, 20))
    #expect(c.bar == room(.window, .other, .cheerful))
    switches(&c, at: (1...6).map { at(12, 2, $0 * 5) })    // a fresh scattered round
    #expect(c.bar == room(.window, .other, .grumpy))
}

@Test func aPetAtNightLeavesPixSleepy() {
    var c = launched(in: "com.apple.finder", at: at(23, 30))
    #expect(c.handle(.pixPetted, at: at(23, 31)) == .reaction(.pet))
    #expect(c.bar == room(.window, .other, .sleepy))
}

// MARK: - Hide Pix

@Test func hidingPixGivesTheDefaultBarAndAppSwitchesLeaveItThere() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.hidePix, at: at(12, 1))
    #expect(c.bar == .defaultBar)
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 2))
    #expect(c.bar == .defaultBar)
}

@Test func aHiddenPixStaysHiddenThroughSleepAndLockAndNeverGreets() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12, 0))
    c.handle(.hidePix, at: at(12, 0, 30))
    c.handle(.screenSlept, at: at(12, 1))
    #expect(c.handle(.screenWoke, at: at(12, 20)) == nil)   // away long enough for a Greeting, but hidden
    #expect(c.bar == .defaultBar)
    c.handle(.locked, at: at(12, 21))
    #expect(c.handle(.unlocked, at: at(12, 40)) == nil)
    #expect(c.bar == .defaultBar)
}

@Test func aPixHiddenWhenTheAppQuitStartsHiddenWithoutAGreeting() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.microsoft.VSCode", power: charger, at: at(12), timeZone: utc, saved: Saved(hidden: true))
    #expect(c.handle(.appStarted, at: at(12)) == nil)
    #expect(c.bar == .defaultBar)
}

/// One way an event makes a Moment: events at minutes after noon, the last one's Moment being the one checked.
struct MomentMaker: Sendable, CustomTestStringConvertible {
    var testDescription: String
    var events: [(event: Event, minute: Int)]
    init(_ name: String, _ events: [(event: Event, minute: Int)]) { (testDescription, self.events) = (name, events) }
}

let momentMakers = [
    MomentMaker("Greeting at start", [(.appStarted, 0)]),
    MomentMaker("Greeting after a long absence", [(.screenSlept, 1), (.screenWoke, 20)]),
    MomentMaker("Reaction to a tap", [(.pixTapped, 1)]),
    MomentMaker("Pet", [(.pixPetted, 1)]),
    MomentMaker("Charging", [(.powerChanged(charger), 1)]),
    MomentMaker("Focus started", [(.startFocus, 1)]),
    MomentMaker("Focus done", [(.startFocus, 1), (.clockTick, 26)]),
    MomentMaker("Break", [(.clockTick, 45)]),
    MomentMaker("Overheated", [(.thermalChanged(hot: true), 1)]),
    MomentMaker("Agent asks", [(.agent(.waiting), 1)]),
    MomentMaker("Agent done", [(.agent(.done), 1)]),
    MomentMaker("Agent failed", [(.agent(.failed), 1)]),
]

/// Shown, each one plays its Moment; hidden, none does.
@Test(arguments: momentMakers, [false, true])
func aMomentPlaysOnlyWhilePixIsShown(maker: MomentMaker, hidden: Bool) {
    var c = Controller(selfBundleID: selfID, frontApp: "com.microsoft.VSCode", power: battery, at: at(12), timeZone: utc, saved: Saved(hidden: hidden))
    let played = maker.events.map { c.handle($0.event, at: at(12, $0.minute)) }
    #expect((played.last! == nil) == hidden)
    #expect((c.bar == .defaultBar) == hidden)
}

@Test(arguments: [Event.showPix, .sparklesTapped])
func showPixAndSparklesBringAHiddenPixBack(event: Event) {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.hidePix, at: at(12, 1))
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 2))
    c.handle(event, at: at(12, 3))
    #expect(c.bar == room(.window, .browsing))
}

// MARK: - Per-app overrides

@Test func pixsGuessIsTheAppsTableOrJetBrainsOrElseOther() {
    #expect(Activity(guessing: "com.apple.FaceTime") == .meeting)
    #expect(Activity(guessing: "com.jetbrains.pycharm") == .coding)
    #expect(Activity(guessing: "com.apple.finder") == .other)
    #expect(Activity(guessing: nil) == .other)
}

@Test func anOverrideBeatsPixsGuessEvenForJetBrains() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.jetbrains.intellij", power: charger, at: at(12), timeZone: utc,
                       saved: Saved(overrides: ["com.jetbrains.intellij": .activity(.music), "com.apple.finder": .activity(.watching)]))
    #expect(c.bar == room(.musicCorner, .music))
    c.handle(.frontAppChanged("com.apple.finder"), at: at(12, 1))
    #expect(c.bar == room(.couch, .watching))
}

@Test func overridingTheFrontAppMovesPixAtOnceAndClearingItGoesBackToTheGuess() {
    var c = launched(in: "com.apple.finder")
    c.handle(.override("com.apple.finder", .activity(.coding)), at: at(12, 1))
    #expect(c.bar == room(.desk, .coding))
    c.handle(.override("com.apple.finder", nil), at: at(12, 2))
    #expect(c.bar == room(.window, .other))
}

@Test func anOverrideForAnotherAppChangesNothingUntilThatAppIsInFront() {
    var c = launched(in: "com.apple.finder")
    c.handle(.override("com.apple.mail", .activity(.music)), at: at(12, 1))
    #expect(c.bar == room(.window, .other))
    c.handle(.frontAppChanged("com.apple.mail"), at: at(12, 2))
    #expect(c.bar == room(.musicCorner, .music))
}

@Test func aShortOverrideAndBackKeepsTheCodingSession() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12))
    c.handle(.override("com.microsoft.VSCode", .activity(.other)), at: at(12, 40))
    c.handle(.override("com.microsoft.VSCode", nil), at: at(12, 41))
    c.handle(.clockTick, at: at(12, 46))  // 40 + 5 minutes of coding
    #expect(c.bar == room(.desk, .coding, .focused))
}

@Test func anOverrideIsNotASwitchSoItCannotTipPixIntoGrumpy() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    switches(&c, at: (1...5).map { at(12, 0, $0 * 10) })  // one switch short of grumpy, ending in Notes
    c.handle(.override("com.apple.Notes", .activity(.music)), at: at(12, 1))
    #expect(c.bar == room(.musicCorner, .music, .content))
}

@Test func inAnAppGivenItsOwnTouchBarPixStepsAsideAndComesBackElsewhere() {
    var c = launched(in: "com.apple.finder")
    c.handle(.override("com.apple.finder", .defaultBar), at: at(12, 1))
    #expect(c.bar == .defaultBar)
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 2))
    #expect(c.bar == room(.window, .browsing))
    c.handle(.frontAppChanged("com.apple.finder"), at: at(12, 3))
    #expect(c.bar == .defaultBar)
}

@Test func sparklesShowPixInAnAppGivenItsOwnTouchBarUntilTheNextVisit() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.finder", power: charger, at: at(12), timeZone: utc,
                       saved: Saved(overrides: ["com.apple.finder": .defaultBar]))
    #expect(c.bar == .defaultBar)
    c.handle(.sparklesTapped, at: at(12, 1))
    #expect(c.bar == room(.window, .other))
    c.handle(.frontAppChanged("com.apple.Safari"), at: at(12, 2))
    c.handle(.frontAppChanged("com.apple.finder"), at: at(12, 3))
    #expect(c.bar == .defaultBar)
}

@Test func choosingOneAppsOverrideKeepsTheOthersAndPixsGuessForgetsIt() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.finder", power: charger, at: at(12), timeZone: utc,
                       saved: Saved(overrides: ["com.apple.mail": .activity(.music)]))
    c.handle(.override("com.apple.finder", .activity(.coding)), at: at(12, 1))
    #expect(c.bar == room(.desk, .coding))
    #expect(c.saved.overrides == ["com.apple.mail": .activity(.music), "com.apple.finder": .activity(.coding)])
    c.handle(.override("com.apple.finder", nil), at: at(12, 2))
    #expect(c.bar == room(.window, .other))
    #expect(c.saved.overrides == ["com.apple.mail": .activity(.music)])
}

@Test func anOverrideIsStoredAsTheActivityOrDefaultBarAndUnknownOnesAreDropped() {
    #expect(Override.activity(.meeting).stored == "meeting")
    #expect(Override(stored: "defaultBar") == .defaultBar)
    #expect(Override(stored: "coding") == .activity(.coding))
    #expect(Override(stored: "gaming") == nil)
}

// MARK: - Battery

func onBattery(at level: Int?) -> Power { Power(onBattery: true, lowPowerMode: false, level: level) }

@Test func onALowBatteryPixIsSleepyAndOnTheChargerItIsNot() {
    var c = launched(in: "com.apple.Safari", power: onBattery(at: 21))
    #expect(c.bar == room(.window, .browsing, fps: 10))
    c.handle(.powerChanged(onBattery(at: 20)), at: at(12, 1))
    #expect(c.bar == room(.window, .browsing, .sleepy, fps: 6))  // and it rests at Low Power Mode's frame rate
    #expect(launched(in: "com.apple.Safari", power: Power(onBattery: false, lowPowerMode: false, level: 10)).bar == room(.window, .browsing))
    #expect(launched(in: "com.apple.Safari", power: onBattery(at: nil)).bar == room(.window, .browsing, fps: 10))
}

@Test func pluggingInIsAMomentAndWakesALowBatteryPix() {
    var c = launched(in: "com.apple.Safari", power: onBattery(at: 8))
    #expect(c.handle(.powerChanged(Power(onBattery: false, lowPowerMode: false, level: 8)), at: at(12, 1)) == .charging)
    #expect(c.bar == room(.window, .browsing))
    #expect(c.handle(.powerChanged(onBattery(at: 8)), at: at(12, 2)) == nil)  // unplugging is no Moment
    #expect(c.handle(.powerChanged(onBattery(at: 7)), at: at(12, 3)) == nil)  // nor is the level going down
}

@Test func pluggingInOnTheDefaultBarIsNoMoment() {
    var c = launched(in: "com.apple.Safari", power: onBattery(at: 50))
    c.handle(.tappedElsewhere, at: at(12, 1))
    #expect(c.handle(.powerChanged(charger), at: at(12, 2)) == nil)
}

// MARK: - Focus with Pix

@Test func focusSendsPixToTheDeskFocusedForTwentyFiveMinutesThenItsDone() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.handle(.startFocus, at: at(12, 0, 30)) == .focusStarted)
    #expect(c.bar == room(.desk, .browsing, .focused))
    #expect(c.focusMinutesLeft(at: at(12, 1)) == 25)
    #expect(c.handle(.clockTick, at: at(12, 25)) == nil)
    #expect(c.focusMinutesLeft(at: at(12, 25)) == 1)
    #expect(c.handle(.clockTick, at: at(12, 26)) == .focusDone)
    #expect(c.bar == room(.window, .browsing))
    #expect(c.focusMinutesLeft(at: at(12, 26)) == nil)
}

@Test func stoppingFocusEarlyIsNoMoment() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.startFocus, at: at(12))
    #expect(c.handle(.stopFocus, at: at(12, 10)) == nil)
    #expect(c.bar == room(.window, .browsing))
    #expect(c.handle(.clockTick, at: at(12, 30)) == nil)
}

@Test func aCallDuringFocusStillPutsPixOnTheCall() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.startFocus, at: at(12))
    c.handle(.frontAppChanged("us.zoom.xos"), at: at(12, 5))
    #expect(c.bar == room(.call, .meeting, .focused))
}

@Test func noCodingBreakInterruptsFocusItWaitsUntilFocusIsDone() {
    var c = launched(in: "com.microsoft.VSCode", at: at(12))
    c.handle(.startFocus, at: at(12, 30))
    #expect(c.handle(.clockTick, at: at(12, 45)) == nil)  // the first Break would be due now
    #expect(c.handle(.clockTick, at: at(12, 55)) == .focusDone)
    #expect(c.handle(.clockTick, at: at(12, 56)) == .pause(.coffee))
}

@Test func startingFocusOnTheDefaultBarIsNoMomentButPixStillFocuses() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.tappedElsewhere, at: at(12))
    #expect(c.handle(.startFocus, at: at(12, 1)) == nil)
    c.handle(.frontAppChanged("com.apple.finder"), at: at(12, 2))
    #expect(c.bar == room(.desk, .other, .focused))
}

// MARK: - Memory

@Test func pixRemembersTheFirstArrivalAndGreetsAsUsual() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.handle(.appStarted, at: at(12)) == .greeting(.hello))
    #expect(c.memory.days == ["2026-10-12"])
    #expect(c.memory.arrivals == ["2026-10-12": 720])
}

@Test func backAfterDaysAwayIsTheDaysFirstGreetingButNotTheNext() {
    var memory = Memory()
    memory.arrive(at: at(9) - 5 * 86_400, calendar: enUS)  // the Wednesday before
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(memory: memory))
    #expect(c.handle(.appStarted, at: at(12)) == .greeting(.missedYou))
    c.handle(.screenSlept, at: at(12, 10))
    #expect(c.handle(.screenWoke, at: at(13)) == .greeting(.hello, after: .gaze))
}

@Test func aDayOfPetsMakesTomorrowsFirstGreetingCheerfulUnlessPixIsSleepy() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.appStarted, at: at(12))
    for i in 1...5 { c.handle(.pixPetted, at: at(12, i)) }
    c.handle(.screenSlept, at: at(13))
    var late = c
    #expect(c.handle(.screenWoke, at: at(11) + 86_400) == .greeting(.cheerful, after: .doze))
    #expect(late.handle(.screenWoke, at: at(23, 30) + 86_400) == .greeting(.sleepy, after: .doze))
}

@Test func onTheDefaultBarThereIsNoGreetingButTheArrivalIsRemembered() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(hidden: true))
    #expect(c.handle(.appStarted, at: at(12)) == nil)
    #expect(c.memory.days == ["2026-10-12"])
}

@Test func workingPastMidnightCountsAsBeingThereTheNextDay() {
    var c = launched(in: "com.apple.Safari", at: at(23))
    c.handle(.appStarted, at: at(23))
    c.handle(.frontAppChanged("com.apple.finder"), at: at(0, 30) + 86_400)
    #expect(c.memory.days == ["2026-10-12", "2026-10-13"])
    #expect(c.memory.arrivals["2026-10-13"] == nil)  // no Greeting, so no arrival time
}

@Test func forgettingStartsTheMemoryOver() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.appStarted, at: at(12))
    c.handle(.pixPetted, at: at(12, 1))
    c.handle(.forgetMemory, at: at(12, 2))
    #expect(c.memory == Memory())
}

// MARK: - Occasions

@Test(arguments: [(10, 31, Occasion.halloween), (12, 24, .holidays), (12, 26, .holidays), (1, 1, .newYear)])
func occasionsFallOnTheirDays(month: Int, day: Int, occasion: Occasion) {
    #expect(Occasion(month: month, day: day)?.greeting == occasion.greeting)
}

@Test func ordinaryDaysAreNoOccasionAndSnowFallsOnlyInDecemberAndJanuary() {
    #expect(Occasion(month: 10, day: 30) == nil)
    #expect(Occasion(month: 12, day: 27) == nil)
    #expect((1...12).filter(Occasion.snows(inMonth:)) == [1, 12])
}

@Test func anOccasionIsTheDaysFirstGreetingEvenOverMemory() {
    let halloween = at(12) + 19 * 86_400  // Saturday 2026-10-31
    var memory = Memory()
    memory.arrive(at: halloween - 10 * 86_400, calendar: enUS)  // long enough away to be missed
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: halloween, timeZone: utc, saved: Saved(memory: memory))
    #expect(c.handle(.appStarted, at: halloween) == .greeting(.halloween))
    c.handle(.screenSlept, at: halloween + 600)
    #expect(c.handle(.screenWoke, at: halloween + 3600) == .greeting(.hello, after: .gaze))
}

@Test(arguments: [
    (Power(onBattery: false, lowPowerMode: false, level: 5), 12),   // on the charger, however low
    (Power(onBattery: true, lowPowerMode: false, level: 21), 10),
    (Power(onBattery: true, lowPowerMode: false, level: 20), 6),    // a low battery rests like Low Power Mode
    (Power(onBattery: true, lowPowerMode: true, level: 90), 6),
])
func theFrameRateFollowsThePower(power: Power, fps: Int) {
    #expect(power.fps == fps)
}

// MARK: - The user's AI agent

func agentRoom(_ spot: Spot, _ activity: Activity, _ mood: Mood = .content) -> Bar {
    .room(Room(spot: spot, activity: activity, mood: mood, fps: 12, agentWorking: true))
}

@Test(arguments: [("pix://agent/working", AgentState.working), ("pix://agent/waiting", .waiting), ("PIX://Agent/Done", .done),
                   ("pix://agent/failed", .failed)])
func agentLinksNameTheState(link: String, state: AgentState) {
    #expect(AgentReport(url: URL(string: link)!) == AgentReport(state: state, agent: nil))
}

@Test(arguments: [
    ("pix://agent/working?session=3f2a9c1e-77b0-4d1e-9a51-0c2b8e6f4d10", "3f2a9c1e-77b0-4d1e-9a51-0c2b8e6f4d10"),
    ("pix://agent/done?other=1&session=thread_42.b", "thread_42.b"),
    ("pix://agent/waiting?session=w-1", "w-1"),
    ("pix://agent/failed?session=f-1", "f-1"),
    ("pix://agent/done?session=", nil),  // empty: no ID, the nameless Agent
])
func anAgentLinkCanNameItsAgent(link: String, agent: String?) {
    #expect(AgentReport(url: URL(string: link)!)?.agent == agent)
}

@Test(arguments: ["pix://agent/sleeping", "pix://agent", "pix://agent/done/extra", "pix://focus/done", "https://agent/done",
                  "pix://agent/done?session=has%20space", "pix://agent/done?session=a/b",
                  "pix://agent/done?session=" + String(repeating: "a", count: 129)])
func anyOtherLinkIsIgnored(link: String) {
    #expect(AgentReport(url: URL(string: link)!) == nil)
}

@Test func anAgentIDCanBe128CharactersLong() {
    let id = String(repeating: "a", count: 128)
    #expect(AgentReport(url: URL(string: "pix://agent/working?session=" + id)!)?.agent == id)
}

@Test func whileTheAgentWorksPixTypesAlongAtTheDeskThenCheersWhenItsDone() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.handle(.agent(.working), at: at(12, 1)) == nil)
    #expect(c.bar == agentRoom(.desk, .browsing))
    #expect(c.handle(.agent(.done), at: at(12, 5)) == .agentDone)
    #expect(c.bar == room(.window, .browsing))
}

@Test func whenTheAgentNeedsYouPixSaysSoAndStopsTyping() {
    var c = launched(in: "com.microsoft.VSCode")
    c.handle(.agent(.working), at: at(12, 1))
    #expect(c.handle(.agent(.waiting), at: at(12, 2)) == .agentAsks)
    #expect(c.bar == room(.desk, .coding))
    c.handle(.agent(.working), at: at(12, 3))  // the user answered; back at it
    #expect(c.bar == agentRoom(.desk, .coding))
}

@Test func anAgentSilentForTenMinutesHasStopped() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working), at: at(12))
    c.handle(.clockTick, at: at(12, 9))
    #expect(c.bar == agentRoom(.desk, .browsing))
    c.handle(.agent(.working), at: at(12, 9, 30))  // still at it: the ten minutes start again
    c.handle(.clockTick, at: at(12, 19))
    #expect(c.bar == agentRoom(.desk, .browsing))
    c.handle(.clockTick, at: at(12, 20))
    #expect(c.bar == room(.window, .browsing))
}

@Test func whenOneOfTwoAgentsFinishesPixCheersAndKeepsTypingForTheOther() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working, agent: "a"), at: at(12, 1))
    c.handle(.agent(.working, agent: "b"), at: at(12, 2))
    #expect(c.handle(.agent(.done, agent: "a"), at: at(12, 3)) == .agentDone)
    #expect(c.bar == agentRoom(.desk, .browsing))
    #expect(c.handle(.agent(.done, agent: "b"), at: at(12, 4)) == .agentDone)
    #expect(c.bar == room(.window, .browsing))
}

@Test func whenOneAgentNeedsYouPixAsksAndKeepsTypingForTheOther() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working, agent: "a"), at: at(12, 1))
    c.handle(.agent(.working, agent: "b"), at: at(12, 2))
    #expect(c.handle(.agent(.waiting, agent: "a"), at: at(12, 3)) == .agentAsks)
    #expect(c.bar == agentRoom(.desk, .browsing))
}

@Test func eachAgentGoesQuietOnItsOwnTenMinutes() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working, agent: "a"), at: at(12))
    c.handle(.agent(.working, agent: "b"), at: at(12, 5))
    c.handle(.clockTick, at: at(12, 10))  // a has gone quiet; b hasn't
    #expect(c.bar == agentRoom(.desk, .browsing))
    c.handle(.agent(.done, agent: "b"), at: at(12, 11))
    #expect(c.bar == room(.window, .browsing))  // a is gone, not brought back by b's news
}

@Test func linksWithoutAnIDAreOneNamelessAgentBesideTheOthers() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working), at: at(12, 1))
    c.handle(.agent(.working, agent: "a"), at: at(12, 2))
    c.handle(.agent(.done), at: at(12, 3))
    #expect(c.bar == agentRoom(.desk, .browsing))
    c.handle(.agent(.done, agent: "a"), at: at(12, 4))
    #expect(c.bar == room(.window, .browsing))
}

@Test func onTheDefaultBarAgentsAreStillFollowedSoPixTypesWhenItComesBack() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working, agent: "a"), at: at(12, 1))
    c.handle(.agent(.working, agent: "b"), at: at(12, 2))
    c.handle(.tappedElsewhere, at: at(12, 3))
    #expect(c.handle(.agent(.done, agent: "a"), at: at(12, 4)) == nil)
    c.handle(.sparklesTapped, at: at(12, 5))
    #expect(c.bar == agentRoom(.desk, .browsing))
}

@Test func whenAnAgentFailsPixSaysOopsAndKeepsTypingOnlyForTheOthers() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.agent(.working, agent: "a"), at: at(12, 1))
    c.handle(.agent(.working, agent: "b"), at: at(12, 2))
    #expect(c.handle(.agent(.failed, agent: "a"), at: at(12, 3)) == .agentFailed)
    #expect(c.bar == agentRoom(.desk, .browsing))
    #expect(c.handle(.agent(.failed, agent: "b"), at: at(12, 4)) == .agentFailed)
    #expect(c.bar == room(.window, .browsing))
}

@Test func anAgentPixWasntFollowingStillGetsItsMoment() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.handle(.agent(.done, agent: "late"), at: at(12, 1)) == .agentDone)
    #expect(c.handle(.agent(.failed, agent: "late"), at: at(12, 2)) == .agentFailed)
    #expect(c.bar == room(.window, .browsing))
}

@Test func onACallTheAgentWorkingKeepsPixOnTheCall() {
    var c = launched(in: "us.zoom.xos")
    c.handle(.agent(.working), at: at(12, 1))
    #expect(c.bar == agentRoom(.call, .meeting))
}

@Test func onTheDefaultBarTheAgentsNewsIsNoMoment() {
    var c = launched(in: "com.apple.Safari")
    c.handle(.tappedElsewhere, at: at(12))
    #expect(c.handle(.agent(.done), at: at(12, 1)) == nil)
    #expect(c.handle(.agent(.waiting), at: at(12, 2)) == nil)
}

// MARK: - Hats

@Test func whatPixKeepsFollowsHidingEarningAHatAndForgetting() {
    var memory = Memory()
    for d in 1...2 { memory.arrive(at: at(9) - Double(d) * 86_400, calendar: enUS) }  // Saturday and Sunday
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(memory: memory))
    c.handle(.appStarted, at: at(12))  // the third day earns the cap
    c.handle(.hidePix, at: at(12, 1))
    #expect(c.saved.hidden && c.saved.hat == .cap && c.saved.memory.days.count == 3)
    c.handle(.forgetMemory, at: at(12, 2))
    #expect(c.saved == Saved(hidden: true, lastSeen: at(12, 2)))  // forgetting the Memory doesn't forget when you were last here
}

@Test func theThirdDayTogetherEarnsACapAndItsNewHatFollowsTheGreeting() {
    var memory = Memory()
    for d in 1...2 { memory.arrive(at: at(9) - Double(d) * 86_400, calendar: enUS) }  // Saturday and Sunday
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(memory: memory))
    #expect(c.handle(.appStarted, at: at(12)) == .greeting(.hello))
    #expect(Hat.earned(by: c.memory) == [.cap])
    #expect(c.handle(.pixTapped, at: at(12, 0, 30)) == .reaction(.wave))  // a Moment of its own goes first
    #expect(c.handle(.clockTick, at: at(12, 1)) == .newHat)
}

@Test func theTwentyFifthPetEarnsThePartyHat() {
    var c = launched(in: "com.apple.Safari")
    for i in 0..<24 { #expect(c.handle(.pixPetted, at: at(12) + Double(i) * 10) == .reaction(.pet)) }
    #expect(c.handle(.pixPetted, at: at(12, 5)) == .newHat)
    #expect(c.handle(.pixPetted, at: at(12, 6)) == .reaction(.pet))
}

@Test func halloweenTogetherEarnsTheWitchHatAfterTheGreeting() {
    let halloween = at(12) + 19 * 86_400  // Saturday 2026-10-31
    var c = launched(in: "com.apple.Safari", at: halloween)
    #expect(c.handle(.appStarted, at: halloween) == .greeting(.halloween))
    #expect(Hat.earned(by: c.memory) == [.witch])
    #expect(c.handle(.clockTick, at: halloween + 60) == .newHat)
    #expect(c.handle(.clockTick, at: halloween + 120) == nil)
}

@Test(arguments: [73, 74, 75])  // December 24, 25 and 26
func anyDayOfTheHolidaysTogetherEarnsTheSantaHat(daysAfter: Int) {
    let holiday = at(12) + Double(daysAfter) * 86_400
    var c = launched(in: "com.apple.Safari", at: holiday)
    #expect(c.handle(.appStarted, at: holiday) == .greeting(.holidays))
    #expect(c.handle(.clockTick, at: holiday + 60) == .newHat)
    #expect(Hat.earned(by: c.memory) == [.santa])
}

@Test func workingPastMidnightIntoNewYearsDayEarnsTheTopHatThereAndThen() {
    let newYearsEve = at(23, 50) + 80 * 86_400  // 2026-12-31
    var c = launched(in: "com.apple.Safari", at: newYearsEve)
    c.handle(.appStarted, at: newYearsEve)
    #expect(c.handle(.frontAppChanged("com.apple.finder"), at: newYearsEve + 20 * 60) == .newHat)  // no Greeting to wait for
    #expect(Hat.earned(by: c.memory) == [.topHat])
    #expect(Hat.topHat.howToEarn == "New Year's Day together")
}

@Test func tenFinishedFocusSessionsEarnTheHeadbandButStoppedOnesDoNot() {
    var c = launched(in: "com.apple.Safari")
    var time = at(12, 1)
    func focus(finishing: Bool) -> Moment? {
        c.handle(.startFocus, at: time)
        defer { time += 30 * 60 }
        if !finishing { return c.handle(.stopFocus, at: time + 10 * 60) }
        return c.handle(.clockTick, at: time + 25 * 60)
    }
    for _ in 0..<5 { _ = focus(finishing: false) }
    for _ in 0..<9 { #expect(focus(finishing: true) == .focusDone) }
    #expect(!Hat.earned(by: c.memory).contains(.headband))
    #expect(focus(finishing: true) == .newHat)
    #expect(Hat.earned(by: c.memory).contains(.headband))
    #expect(Hat.headband.howToEarn == "10 Focus sessions")
}

@Test func aFocusSessionThatEndsOnTheDefaultBarStillCountsAndItsNewHatWaitsForTheRoom() {
    var c = launched(in: "com.apple.Safari")
    var time = at(12, 1)
    for _ in 0..<9 {
        c.handle(.startFocus, at: time)
        c.handle(.clockTick, at: time + 25 * 60)
        time += 30 * 60
    }
    c.handle(.startFocus, at: time)
    c.handle(.tappedElsewhere, at: time + 60)
    #expect(c.handle(.clockTick, at: time + 25 * 60) == nil)  // nobody sees DONE on the Default bar
    #expect(Hat.earned(by: c.memory).contains(.headband))
    #expect(c.handle(.sparklesTapped, at: time + 26 * 60) == .newHat)
}

@Test func forgettingTheMemoryGivesBackTheOccasionHatAndItsNewHatIsNoLongerOwed() {
    let halloween = at(12) + 19 * 86_400
    var c = launched(in: "com.apple.Safari", at: halloween)
    c.handle(.appStarted, at: halloween)
    #expect(c.handle(.forgetMemory, at: halloween + 30) == nil)
    #expect(Hat.earned(by: c.memory) == [])
    #expect(c.handle(.clockTick, at: halloween + 60) == nil)
}

@Test func anOccasionHatIsKeptLongAfterTheDaysAreTrimmedAndNotEarnedTwice() {
    let halloween = at(12) + 19 * 86_400
    var c = launched(in: "com.apple.Safari", at: halloween)
    c.handle(.appStarted, at: halloween)
    c.handle(.clockTick, at: halloween + 60)
    var time = halloween
    for _ in 0..<70 { time += 86_400; c.handle(.frontAppChanged("com.apple.finder"), at: time); c.handle(.frontAppChanged("com.apple.Safari"), at: time + 60) }
    #expect(c.memory.days.count == 60)
    #expect(Hat.earned(by: c.memory).contains(.witch))
    let nextHalloween = halloween + 365 * 86_400
    c.handle(.frontAppChanged("com.apple.finder"), at: nextHalloween)
    #expect(c.handle(.clockTick, at: nextHalloween + 60) != .newHat)
}

@Test func aHatJustEarnedGoesStraightOn() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.hat == nil)
    for i in 0..<25 { c.handle(.pixPetted, at: at(12) + Double(i) * 10) }
    #expect(c.hat == .party)
}

@Test func twoHatsEarnedTogetherPutTheLastOneOn() {
    let halloween = at(12) + 19 * 86_400  // and the third day together
    var memory = Memory()
    for d in 1...2 { memory.arrive(at: halloween - Double(d) * 86_400, calendar: enUS) }
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: halloween, timeZone: utc, saved: Saved(memory: memory))
    c.handle(.appStarted, at: halloween)
    #expect(Hat.earned(by: c.memory) == [.cap, .witch])
    #expect(c.hat == .witch)
}

@Test func choosingAHatWearsItOnlyOnceItsEarned() {
    let halloween = at(12) + 19 * 86_400
    var c = launched(in: "com.apple.Safari", at: halloween)
    c.handle(.chooseHat(.crown), at: halloween)
    #expect(c.hat == nil)
    c.handle(.appStarted, at: halloween)
    c.handle(.chooseHat(nil), at: halloween + 10)
    #expect(c.hat == nil)
    c.handle(.chooseHat(.witch), at: halloween + 20)
    #expect(c.hat == .witch)
    #expect(c.wearableHats == [.witch])
}

@Test func forgettingTheMemoryTakesOffAHatNoLongerEarned() {
    let halloween = at(12) + 19 * 86_400
    var c = launched(in: "com.apple.Safari", at: halloween)
    c.handle(.appStarted, at: halloween)
    c.handle(.forgetMemory, at: halloween + 30)
    #expect(c.hat == nil)
    #expect(c.wearableHats == [])
}

@Test func theHatWornAtLaunchStaysOnIfItsEarned() {
    var memory = Memory()
    for d in 1...3 { memory.arrive(at: at(9) - Double(d) * 86_400, calendar: enUS) }
    let c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(memory: memory, hat: .cap))
    #expect(c.hat == .cap)
    let notEarned = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(hat: .crown))
    #expect(notEarned.hat == nil)
}

@Test func withAllHatsEveryHatCanBeWornAndForgettingKeepsIt() {
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.Safari", power: charger, at: at(12), timeZone: utc, saved: Saved(hat: .crown), allHats: true)
    #expect(c.hat == .crown)
    #expect(c.wearableHats == Hat.allCases)
    c.handle(.chooseHat(.topHat), at: at(12, 1))
    c.handle(.forgetMemory, at: at(12, 2))
    #expect(c.hat == .topHat)
}

// MARK: - Time zones

@Test func afterATimeZoneChangePixGetsSleepyByTheNewHour() {
    var c = launched(in: "com.apple.Safari", at: at(22, 30))
    #expect(c.bar == room(.window, .browsing))
    c.handle(.timeZoneChanged(TimeZone(identifier: "Africa/Lagos")!), at: at(22, 31))  // 23:31 there
    #expect(c.bar == room(.window, .browsing, .sleepy))
}

@Test func aGreetingAfterATimeZoneChangeIsForTheNewDate() {
    let halloweenEve = at(23, 30) + 18 * 86_400  // Friday 2026-10-30, 23:30 UTC
    var c = launched(in: "com.apple.Safari", at: halloweenEve)
    c.handle(.timeZoneChanged(TimeZone(identifier: "Africa/Lagos")!), at: halloweenEve)  // already Halloween there
    guard case .greeting(let greeting, _)? = c.handle(.appStarted, at: halloweenEve + 60) else { Issue.record("no Greeting"); return }
    #expect(greeting == .halloween)
}

// MARK: - A hot Mac

@Test func aHotMacMakesPixGrumpyAndSlowerUntilItCools() {
    var c = launched(in: "com.apple.Safari")
    #expect(c.handle(.thermalChanged(hot: true), at: at(12, 1)) == .overheated)
    #expect(c.bar == .room(Room(spot: .window, activity: .browsing, mood: .grumpy, fps: 6, hot: true)))
    #expect(c.handle(.thermalChanged(hot: true), at: at(12, 2)) == nil)  // still hot: no new Moment
    #expect(c.handle(.thermalChanged(hot: false), at: at(12, 3)) == nil)
    #expect(c.bar == room(.window, .browsing))
}

@Test func runningHotOnTheDefaultBarIsNoMomentButPixStillFeelsIt() {
    var c = launched(in: "com.apple.Safari", power: battery)
    c.handle(.tappedElsewhere, at: at(12))
    #expect(c.handle(.thermalChanged(hot: true), at: at(12, 1)) == nil)
    c.handle(.frontAppChanged("com.apple.finder"), at: at(12, 2))
    #expect(c.bar == .room(Room(spot: .window, activity: .other, mood: .grumpy, fps: 6, hot: true)))
}

// MARK: - Pastime

@Test func comingBackAfterALongAbsenceAtNightFindsPixDozing() {
    var c = launched(in: "com.apple.finder", at: at(20, 0))
    c.handle(.locked, at: at(20, 1))
    #expect(c.handle(.unlocked, at: at(23, 30)) == .greeting(.sleepy, after: .doze))
}

@Test func comingBackInTheMorningAfterAWeekendFindsPixMakingCoffee() {
    var c = launched(in: "com.apple.finder", at: at(17, 0))
    c.handle(.locked, at: at(17, 1))
    #expect(c.handle(.unlocked, at: at(8, 0) + 3 * 86_400) == .greeting(.cheerful, after: .coffee))
}

@Test func lastSeenFollowsYouWhileYouAreHereAndStopsWhenYouGoAway() {
    var c = launched(in: "com.apple.finder", at: at(12, 0))
    c.handle(.clockTick, at: at(12, 5))
    #expect(c.saved.lastSeen == at(12, 5))
    c.handle(.locked, at: at(12, 6))
    c.handle(.clockTick, at: at(12, 7))
    c.handle(.clockTick, at: at(18, 0))  // Pix keeps running at the lock screen, but you aren't there
    #expect(c.saved.lastSeen == at(12, 6))
}

@Test func relaunchingMeasuresTheAbsenceFromWhenYouWereLastHere() {
    var before = launched(in: "com.apple.finder", at: at(9, 30))
    before.handle(.locked, at: at(10, 0))
    before.handle(.clockTick, at: at(12, 30))  // Pix keeps running at the lock screen; then it is quit and started again
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.finder", power: charger, at: at(12, 35), timeZone: utc, saved: before.saved)
    #expect(c.handle(.appStarted, at: at(12, 35)) == .greeting(.hello, after: .doze))  // away since 10:00, not 12:30
}

@Test func aQuickRelaunchFindsPixGazingAndTheVeryFirstLaunchFindsNothing() {
    var first = launched(in: "com.apple.finder", at: at(12, 0))
    #expect(first.handle(.appStarted, at: at(12, 0)) == .greeting(.hello))  // nothing saved yet: no Pastime
    var c = Controller(selfBundleID: selfID, frontApp: "com.apple.finder", power: charger, at: at(12, 2), timeZone: utc, saved: first.saved)
    #expect(c.handle(.appStarted, at: at(12, 2)) == .greeting(.hello, after: .gaze))
}
