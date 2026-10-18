// Draws Halloween's Occasion Props (Sources/AmbientCore/Halloween.swift) into Art/Halloween: one clear strip per Room
// strip with the Props stamped where the contract puts them, plus the moon and the bat's two wing beats for the night sky.
// Each drawing is a pixel grid, one character per art pixel ('.' is clear), colored from halloweenColors.
import AppKit

let halloweenColors: [Character: CGColor] = [
    "3": hex(0x8a4210), "4": hex(0x5a2a0c), "A": hex(0xd0701e), "B": hex(0x7a7a88), "D": hex(0xd8d8e0), "G": hex(0x6b6b78),
    "H": hex(0xb4b4c0), "K": hex(0x24242b), "L": hex(0x5c9a6e), "N": hex(0xc9a860), "O": hex(0xa06a48), "R": hex(0x5a5a68),
    "S": hex(0x34343e), "U": hex(0x7a68a8), "W": hex(0xeceef3), "X": hex(0x0b0d12), "Y": hex(0xffd84a), "a": hex(0xff9a3c),
    "b": hex(0x2c3e5c), "d": hex(0xa8a8b4), "e": hex(0xff6b6b), "f": hex(0x101018), "i": hex(0x3a4f73), "j": hex(0x3e3060),
    "l": hex(0x3d6b4f), "n": hex(0x9a8450), "o": hex(0x7a4e38), "s": hex(0x6b5226), "t": hex(0x9a7a3a), "u": hex(0x5c4a8a),
    "w": hex(0x4a3024), "y": hex(0xe3b341), "z": hex(0xb8964c),
]

let halloweenArt: [String: [String]] = [
    "jackOLantern": [
        ".......lL.....",
        "......l..L....",
        "...3AaaAaaA3..",
        "..3AaaaAaaaA3.",
        ".3AaYYaAaYYaA3",
        ".3AaaYaAaYaaA3",
        ".3AaaaaYaaaaA3",
        ".3AYaaaaaaaYA3",
        ".3AYYaYYaYYYA3",
        ".3AaYYYYYYYaA3",
        "..3AaaAaaaA3..",
        "...334444433..",
    ],
    "jackSmall": [
        "....lL....",
        "..3AaAa3..",
        ".3AaaAaaA3",
        ".3YYaAaYa3",
        ".3aaaAaaA3",
        ".3AYaYaYA3",
        ".3AaYaYaA3",
        "..3AaAaA3.",
        "...34443..",
    ],
    "pumpkin": [
        "...lL...",
        ".3AaAa3.",
        "3AaaAaaA",
        "3AaaAaaA",
        "3AaaAaaA",
        ".3AaAa3.",
        "..3443..",
    ],
    "broom": [
        "........ow",
        "........ow",
        ".......ow.",
        ".......ow.",
        ".......ow.",
        "......ow..",
        "......ow..",
        "......ow..",
        ".....Oow..",
        ".....ow...",
        ".....ow...",
        "....ow....",
        "....ow....",
        "....ow....",
        "...NnN....",
        "...tzts...",
        "..tzztss..",
        "..ztzzts..",
        ".tzzttzss.",
        ".zztzztts.",
        "tzztzzttss",
        "ztzzttztss",
        "s.ts.ts.s.",
    ],
    "candles": [
        ".Y........",
        ".y...Y....",
        "DdD..y..Y.",
        "DdD.DdD.y.",
        "DdDDDdD.Dd",
        "DdD.DddDDd",
    ],
    "candle": [
        ".Y.",
        ".y.",
        "DdD",
        "Ddd",
        "DdD",
        "DDd",
        "DdD",
        "DdD",
        "SSS",
    ],
    "ghost": [
        "...G...",
        "...G...",
        "...G...",
        "..WWW..",
        ".WWWWH.",
        ".WXWXH.",
        "WWWWWWH",
        "WWWXWWH",
        "WWWWWWH",
        "WWWWWHH",
        "W.WW.WH",
        "..W...H",
    ],
    "hauntedPrint": [
        "RRRRRRRRRRRRRRRRRRRR",
        "SfffffffffffffaaaffS",
        "SfKfKfffffKffaYaaafS",
        "SfKKffKffKjKfaaaaAfS",
        "SffKfKffKjjjKfaAaffS",
        "SfffKKfKjjjjjKfffffS",
        "SfffKfffjYjYjffffffS",
        "SfffKfffjjjjjffffffS",
        "SfffKfffjjYjjffffffS",
        "SbbbbbbfjjyjjfbbbbbS",
        "SbiiibbbbbbbbbbiibbS",
        "SSSSSSSSSSSSSSSSSSSS",
    ],
    "bunting": [
        "GGG............................................GGGGG............................................GG",
        "...GGGGG..................................GGGaAAAA..GGGGG..................................GGGGG..",
        "...aAAAAGGGGGGG....................GGGGGGG...aAAAA..UuuuuGGGGGGG....................GGGGGGG.......",
        "...aAAAA..UuuuuGGGGGGGGGGGGGGGGGGGG...Uuuuu...aAA...Uuuuu..aAAAAGGGGGGGGGGGGGGGGGGGG...aAAAA......",
        "....aAA...Uuuuu..aAAAA..Uuuuu..aAAAA..Uuuuu...aAA....Uuu...aAAAA..Uuuuu..aAAAA..Uuuuu..aAAAA......",
        "....aAA....Uuu...aAAAA..Uuuuu..aAAAA...Uuu.....a.....Uuu....aAA...Uuuuu..aAAAA..Uuuuu...aAA.......",
        ".....a.....Uuu....aAA....Uuu....aAA....Uuu............U.....aAA....Uuu....aAA....Uuu....aAA.......",
        "............U.....aAA....Uuu....aAA.....U....................a.....Uuu....aAA....Uuu.....a........",
        "...................a......U......a..................................U......a......U...............",
        "..................................................................................................",
    ],
    "cobweb": [
        "GGGBGGBGGB",
        "GGGB..B..B",
        "GGB.GGB..B",
        "BB.G.BGG.B",
        "G.G.GB..BG",
        "G.G.BG..B.",
        "BBBB..GB..",
        "G..G..BG..",
        "G...GB....",
        "BBBBB.....",
    ],
    "cobwebRight": [
        "BGGBGGBGGG",
        "B..B..BGGG",
        "B..BGG.BGG",
        "B.GGB.G.BB",
        "GB..BG.G.G",
        ".B..GB.G.G",
        "..BG..BBBB",
        "..GB..G..G",
        "....BG...G",
        ".....BBBBB",
    ],
    "spider": [
        "..G..",
        "..G..",
        "..G..",
        "..G..",
        "..G..",
        "..G..",
        "..G..",
        "..G..",
        "K.G.K",
        ".KSK.",
        "KSeSK",
        ".KSK.",
        "K...K",
    ],
    "moon": [
        "...aaaa...",
        "..aYaaaa..",
        ".aYaaaAaa.",
        "aaaaaaaAaa",
        "aaAaaaaaaa",
        "aaaaaAaaAa",
        "aaaaaaaaAa",
        ".aaAaaaAa.",
        "..aaaaAa..",
        "...aaaa...",
    ],
    "bat": [
        "G.....G",
        "BG.R.GB",
        ".GGRGG.",
        "...G...",
    ],
    "bat2": [
        "...R...",
        ".GGRGG.",
        "B..G..B",
        ".......",
    ],
]

/// A pixel grid drawn on its own canvas.
func grid(_ rows: [String]) -> Canvas {
    let c = Canvas(rows[0].count, rows.count)
    for (y, row) in rows.enumerated() {
        for (x, key) in row.enumerated() where key != "." { c.rect(x, y, 1, 1, halloweenColors[key]!) }
    }
    return c
}

func drawHalloween() {
    try? FileManager.default.createDirectory(at: out.appendingPathComponent(Halloween.folder), withIntermediateDirectories: true)
    for name in Art.strips {
        let c = Canvas(Art.stripWidth, Art.height)
        for prop in Halloween.props where prop.strip == name {
            guard let rows = halloweenArt[prop.name] else {
                warn("no drawing for Occasion Prop \(prop.name)")
                continue
            }
            let image = grid(rows).image, y = prop.y ?? floorY - image.height
            if prop.x < 0 || y < 0 || prop.x + image.width > c.w || y + image.height > Art.height {
                warn("\(prop.name) at x \(prop.x), y \(y) (\(image.width)×\(image.height)) doesn't fit inside the \(name) strip; part of it is cut off")
            }
            c.stamp(image, x: prop.x, y: y)
        }
        c.fadeEdges()
        c.save("\(Halloween.folder)/room-\(name)")
    }
    grid(halloweenArt["moon"]!).save("\(Halloween.folder)/moon")
    let bat = Canvas(Int(Halloween.bat.width) * 2, Int(Halloween.bat.height))
    bat.stamp(grid(halloweenArt["bat"]!).image, x: 0, y: 0)
    bat.stamp(grid(halloweenArt["bat2"]!).image, x: Int(Halloween.bat.width), y: 0)
    bat.save("\(Halloween.folder)/bat")
}
