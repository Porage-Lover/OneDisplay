import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

let rect = NSRect(origin: .zero, size: size)
let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 60, dy: 60), xRadius: 220, yRadius: 220)
let colors = [
    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.10, alpha: 1.0).cgColor
] as CFArray
let space = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0])!
ctx.saveGState()
bgPath.addClip()
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 964), end: CGPoint(x: 512, y: 60), options: [])
ctx.restoreGState()

NSColor(calibratedRed: 0.3, green: 0.5, blue: 1.0, alpha: 0.5).setStroke()
bgPath.lineWidth = 12
bgPath.stroke()

let screenRect = NSRect(x: 200, y: 380, width: 624, height: 420)
let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 36, yRadius: 36)
NSColor(calibratedRed: 0.15, green: 0.2, blue: 0.3, alpha: 0.9).setFill()
screenPath.fill()
NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 0.8).setStroke()
screenPath.lineWidth = 10
screenPath.stroke()

let sunRect = NSRect(x: 432, y: 510, width: 160, height: 160)
let sunPath = NSBezierPath(ovalIn: sunRect)
NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.2, alpha: 1.0).setFill()
sunPath.fill()

let standStem = NSRect(x: 482, y: 260, width: 60, height: 120)
NSColor(calibratedRed: 0.4, green: 0.45, blue: 0.55, alpha: 1.0).setFill()
standStem.fill()

let standBase = NSRect(x: 362, y: 230, width: 300, height: 35)
let basePath = NSBezierPath(roundedRect: standBase, xRadius: 16, yRadius: 16)
NSColor(calibratedRed: 0.4, green: 0.45, blue: 0.55, alpha: 1.0).setFill()
basePath.fill()

image.unlockFocus()

let fm = FileManager.default
let iconsetPath = "scripts/OneDisplay.iconset"
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, s) in sizes {
    let resized = NSImage(size: NSSize(width: s, height: s))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: s, height: s), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    if let data = resized.tiffRepresentation,
       let bmp = NSBitmapImageRep(data: data),
       let p = bmp.representation(using: .png, properties: [:]) {
        try? p.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
    }
}

print("Iconset created successfully.")
