import AppKit

// GDC Plugin Manager icon: a puzzle-piece glyph (the universal "plugin"
// shape) in the same teal accent as GDC Production Manager's own UI
// (#35D6BE), on a dark gradient - same "family" look as CursorPro GDC /
// GDC License Manager / DataMover.

let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let colorSpace = CGColorSpaceCreateDeviceRGB()

let bgColors = [
    NSColor(calibratedRed: 0.04, green: 0.09, blue: 0.09, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.13, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.07, alpha: 1).cgColor
]
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 0.55, 1])!
ctx.saveGState()
ctx.addRect(rect)
ctx.clip()
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
ctx.restoreGState()

let center = CGPoint(x: size * 0.5, y: size * 0.5)
let glowColors = [
    NSColor(calibratedRed: 0.208, green: 0.839, blue: 0.745, alpha: 0.38).cgColor,
    NSColor(calibratedRed: 0.208, green: 0.839, blue: 0.745, alpha: 0.0).cgColor
]
let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glowGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size * 0.5, options: [])

let accent = NSColor(calibratedRed: 0.208, green: 0.839, blue: 0.745, alpha: 1).cgColor

// Puzzle-piece silhouette: a rounded square with a circular bump on the
// top edge (unioned into the same fill path) and a circular notch cut
// into the left edge (drawn afterward, in the background color, on top
// of the already-filled shape - NOT combined via even-odd, which was
// found earlier this session to re-fill the whole shape instead of
// punching a hole).
let pieceSize = size * 0.46
let pieceX = center.x - pieceSize / 2 + size * 0.03
let pieceY = center.y - pieceSize / 2 - size * 0.02
let corner = size * 0.05
let bumpRadius = pieceSize * 0.22

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.014), blur: size * 0.035, color: NSColor.black.withAlphaComponent(0.55).cgColor)

let piece = CGMutablePath()
piece.addRoundedRect(in: CGRect(x: pieceX, y: pieceY, width: pieceSize, height: pieceSize),
                      cornerWidth: corner, cornerHeight: corner)
// Bump on the top edge, centered, protruding upward - unioned into the
// same path (non-zero winding, so it merges as one solid shape).
let bumpCenter = CGPoint(x: pieceX + pieceSize * 0.5, y: pieceY + pieceSize)
piece.addEllipse(in: CGRect(x: bumpCenter.x - bumpRadius, y: bumpCenter.y - bumpRadius * 0.55,
                             width: bumpRadius * 2, height: bumpRadius * 2))

ctx.addPath(piece)
ctx.setFillColor(accent)
ctx.fillPath()
ctx.restoreGState()

// Notch on the left edge - a circle in the background color, painted on
// top of the already-filled piece (simple additive pass, safe punch).
// Radius smaller than the top bump so it reads as a side notch, not a
// second bump; centered exactly on the edge line (half in, half out).
ctx.saveGState()
let notchRadius = bumpRadius * 0.75
let notchCenter = CGPoint(x: pieceX, y: pieceY + pieceSize * 0.30)
let notchColor = NSColor(calibratedRed: 0.045, green: 0.1, blue: 0.1, alpha: 1).cgColor
ctx.setFillColor(notchColor)
ctx.addEllipse(in: CGRect(x: notchCenter.x - notchRadius, y: notchCenter.y - notchRadius,
                           width: notchRadius * 2, height: notchRadius * 2))
ctx.fillPath()
ctx.restoreGState()

img.unlockFocus()

guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
