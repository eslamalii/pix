/// A hat Pix earns by spending time with the user, worn by choice from the menu. Nothing to buy or trade.
/// (Its own file: the art generator compiles it with the art contract; what earns a hat lives in Wardrobe.swift.)
public enum Hat: String, CaseIterable, Sendable {
    // Only ever add hats at the end: skins draw them by position (see Art.hats).
    case cap, beanie, party, flower, crown, headband, witch, santa, topHat
}
