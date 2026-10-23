// Renders the MonitorBar app icon as an .iconset and converts it to AppIcon.icns.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icon"
let iconsetDir = "\(outDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Rounded-square body with the macOS icon margin.
    let inset = size * 0.085
    let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = body.width * 0.225
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.52, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.78, alpha: 1),
    ])!
    gradient.draw(in: shape, angle: -70)

    // Monitor glyph.
    let config = NSImage.SymbolConfiguration(pointSize: body.width * 0.46, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "display", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let s = symbol.size
        let rect = NSRect(x: body.midX - s.width / 2, y: body.midY - s.height / 2 + body.height * 0.05,
                          width: s.width, height: s.height)
        symbol.draw(in: rect)
    }

    // Brightness bar under the monitor.
    let barHeight = body.height * 0.055
    let barWidth = body.width * 0.46
    let barY = body.minY + body.height * 0.2
    let track = NSBezierPath(roundedRect: NSRect(x: body.midX - barWidth / 2, y: barY, width: barWidth, height: barHeight),
                             xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSColor.white.withAlphaComponent(0.3).setFill()
    track.fill()
    let fill = NSBezierPath(roundedRect: NSRect(x: body.midX - barWidth / 2, y: barY, width: barWidth * 0.7, height: barHeight),
                            xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSColor.white.setFill()
    fill.fill()

    image.unlockFocus()

    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

// Standard iconset: 16, 32, 128, 256, 512 at 1x and 2x.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for variant in variants {
    try! renderIcon(pixels: variant.pixels).write(to: URL(fileURLWithPath: "\(iconsetDir)/\(variant.name).png"))
}
print("Wrote \(iconsetDir)")
