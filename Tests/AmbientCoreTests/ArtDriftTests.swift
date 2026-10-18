import Foundation
import Testing
@testable import AmbientCore

// Every art name AmbientCore hands the view must be in the art contract, and every sheet in the contract must be drawn:
// an unknown name doesn't fail on the Touch Bar, it just plays at the wrong speed or shows the wrong Emote.

let everyMoment: [Moment] = [Reaction.allCases.map(Moment.reaction), Break.allCases.map(Moment.pause), Greeting.allCases.map(Moment.greeting),
                             [.charging, .focusStarted, .focusDone, .agentAsks, .agentDone, .agentFailed, .newHat, .overheated]].flatMap { $0 }

/// Adding a Moment or an Errand stops this compiling until it's in the lists above and below.
private func listed(_ moment: Moment, _ errand: Errand) -> Bool {
    switch moment {
    case .reaction, .pause, .greeting, .charging, .focusStarted, .focusDone, .agentAsks, .agentDone, .agentFailed, .newHat, .overheated: break
    }
    switch errand { case .switchLamp, .waterPlant, .refillMug: return true }
}

let everyRoom: [Room] = Spot.allCases.flatMap { spot in
    Mood.allCases.flatMap { mood in [false, true].map { Room(spot: spot, activity: .other, mood: mood, fps: 12, agentWorking: $0, hot: $0) } }
}

let bodies = Set(Art.bodies.map(\.name))

@Test(arguments: everyMoment)
func everyMomentIsDrawnFromTheArtContract(moment: Moment) {
    let look = moment.look
    #expect(bodies.contains(look.body), "body \(look.body)")
    for emote in [look.emote, look.caption.emote].compactMap({ $0 }) { #expect(Art.emotes.contains(emote), "emote \(emote)") }
}

@Test func everyRestLookIsDrawnFromTheArtContract() {
    for room in everyRoom {
        let look = RestLook(spot: room.spot, mood: room.mood, agentWorking: room.agentWorking, hot: room.hot)
        if let body = look.body { #expect(bodies.contains(body), "body \(body)") }
        for sprite in look.particles { #expect(Art.emotes.contains(sprite), "particle \(sprite)") }
    }
}

@Test func everyFidgetErrandAndStrollStopIsABody() {
    for fidget in Fidget.allCases where fidget != .water && fidget != .refill { #expect(bodies.contains(fidget.rawValue), "fidget \(fidget)") }  // water and refill are Errands
    #expect(Set(everyRoom.flatMap { room in [0, 1].flatMap { Routine.fidgets(for: room, sipsLeft: $0, coffee: true) } }) == Set(Fidget.allCases))
    for errand in [Errand.switchLamp, .waterPlant(at: 0, fromRight: true), .refillMug] { #expect(bodies.contains(errand.body), "errand \(errand.body)") }
    for end in [WindowEnd.left, .right] { if let body = end.stopBody { #expect(bodies.contains(body), "stroll stop \(body)") } }
}

@Test func everyMoodHasAFaceAndEveryHatACell() {
    for mood in Mood.allCases { #expect(Art.faces.contains(mood.rawValue), "face \(mood.rawValue)") }
    #expect(Set(Hat.allCases.map(\.rawValue)) == Set(Art.hats))
}

@Test func everySheetInTheArtContractIsDrawn() {
    let art = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Art").standardized
    let sheets = Art.strips.map { "room-\($0)" } + Art.bodies.map { "pix-\($0.name)" } + ["pix-face", "emotes", "hats", "cloud"]
    for sheet in sheets {
        #expect(FileManager.default.fileExists(atPath: art.appendingPathComponent(Art.file(sheet)).path), "missing Art/\(Art.file(sheet))")
    }
}
