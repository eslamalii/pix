// Draws Pix's app icon from its own art in Art/: its head off the idle sheet, wearing the content face,
// on the Room's black. Run: scripts/make-icon.sh
import AppKit

let (art, out) = (CommandLine.arguments[1], CommandLine.arguments[2])
func load(_ name: String) -> CGImage {
    NSImage(contentsOfFile: "\(art)/\(Art.file(name))")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
func context(_ size: Int) -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

// Pix in art pixels (CGContext's origin is bottom-left, so y counts up)
let f = Art.frame, screen = Art.faceScreen
let pix = context(f)
pix.draw(load("pix-idle").cropping(to: CGRect(x: 0, y: 0, width: f, height: f))!, in: CGRect(x: 0, y: 0, width: f, height: f))
let face = load("pix-face").cropping(to: CGRect(x: 0, y: 0, width: screen.width, height: screen.height))!  // content
pix.draw(face, in: CGRect(x: screen.minX, y: CGFloat(f) - screen.maxY, width: screen.width, height: screen.height))
let head = pix.makeImage()!.cropping(to: CGRect(x: 4, y: 0, width: 16, height: 13))!  // antenna, ears and head; image y counts down

// Apple's icon grid: an 824-point squircle centered on 1024
let size = 1024, scale = 36, icon = context(size)
icon.addPath(CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 186, cornerHeight: 186, transform: nil))
icon.setFillColor(CGColor(srgbRed: 0.04, green: 0.045, blue: 0.06, alpha: 1))
icon.fillPath()
icon.interpolationQuality = .none
let (w, h) = (head.width * scale, head.height * scale)
icon.draw(head, in: CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, icon.makeImage()!, nil)
CGImageDestinationFinalize(dest)
