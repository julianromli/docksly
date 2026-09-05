#!/usr/bin/swift
import AppKit

/// Finder content size in points. Keep this in sync with the DMG window.
let width = 660.0
let height = 420.0
let pixelsWide = 1320
let pixelsHigh = 840

let windowFill = NSColor(srgbRed: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
let shelfFill = NSColor(srgbRed: 42 / 255, green: 42 / 255, blue: 44 / 255, alpha: 1)
let shelfStroke = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.09)
let titleColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.94)
let subtitleColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55)
let footerColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.38)
let arrowColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28)
let dots = [
    NSColor(srgbRed: 56 / 255, green: 132 / 255, blue: 255 / 255, alpha: 1),
    NSColor(srgbRed: 52 / 255, green: 211 / 255, blue: 153 / 255, alpha: 1),
    NSColor(srgbRed: 251 / 255, green: 146 / 255, blue: 60 / 255, alpha: 1)
]

func yFromTop(_ top: CGFloat, _ boxHeight: CGFloat) -> CGFloat {
    height - top - boxHeight
}

func drawText(
    _ string: String,
    font: NSFont,
    color: NSColor,
    in rect: NSRect,
    alignment: NSTextAlignment
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: font.pointSize >= 22 ? -0.3 : 0
    ]
    (string as NSString).draw(in: rect, withAttributes: attributes)
}

func drawArrow(in rect: NSRect) {
    let path = NSBezierPath()
    path.lineWidth = 2
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    let midY = rect.midY
    let startX = rect.minX
    let endX = rect.maxX - 5
    path.move(to: NSPoint(x: startX, y: midY))
    path.line(to: NSPoint(x: endX, y: midY))
    path.move(to: NSPoint(x: endX - 8, y: midY - 6.5))
    path.line(to: NSPoint(x: endX, y: midY))
    path.line(to: NSPoint(x: endX - 8, y: midY + 6.5))
    arrowColor.setStroke()
    path.stroke()
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelsWide,
    pixelsHigh: pixelsHigh,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
) else {
    fputs("Could not create a bitmap.\n", stderr)
    exit(1)
}

rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("Could not create a graphics context.\n", stderr)
    exit(1)
}
NSGraphicsContext.current = graphics

// Bitmap context is flipped (y = 0 at the top) and uses point size 660×420.
let bounds = NSRect(x: 0, y: 0, width: width, height: height)
windowFill.setFill()
bounds.fill()

if let gradient = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.05),
    NSColor.clear
]) {
    gradient.draw(
        from: NSPoint(x: width / 2, y: height),
        to: NSPoint(x: width / 2, y: height - 140),
        options: []
    )
}

let shelf = NSRect(x: 40, y: yFromTop(98, 196), width: 580, height: 196)
let shelfPath = NSBezierPath(roundedRect: shelf, xRadius: 22, yRadius: 22)
shelfFill.setFill()
shelfPath.fill()
shelfStroke.setStroke()
shelfPath.lineWidth = 1
shelfPath.stroke()

let titleFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
let subtitleFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let footerFont = NSFont.systemFont(ofSize: 9, weight: .regular)

drawText(
    "Docksly",
    font: titleFont,
    color: titleColor,
    in: NSRect(x: 40, y: yFromTop(36, 28), width: 580, height: 28),
    alignment: .center
)

let dotY = yFromTop(74, 0)
let dotR = 3.5
let gap = 11.0
let dotsWidth = dotR * 2 * 3 + gap * 2
var dotX = (width - dotsWidth) / 2 + dotR
for color in dots {
    let dot = NSBezierPath(ovalIn: NSRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
    color.setFill()
    dot.fill()
    dotX += dotR * 2 + gap
}

drawText(
    "Drag to Applications",
    font: subtitleFont,
    color: subtitleColor,
    in: NSRect(x: 40, y: yFromTop(124, 16), width: 580, height: 16),
    alignment: .center
)

drawArrow(in: NSRect(x: 280, y: yFromTop(186, 20), width: 100, height: 20))

drawText(
    "If macOS blocks the app, open Privacy & Security and choose Open Anyway.",
    font: footerFont,
    color: footerColor,
    in: NSRect(x: 60, y: yFromTop(318, 28), width: 540, height: 28),
    alignment: .center
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fputs("Could not encode the DMG background.\n", stderr)
    exit(1)
}

let output = CommandLine.arguments.dropFirst().first
    ?? FileManager.default.currentDirectoryPath + "/scripts/dmg/background.png"
let url = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: url)
print("Wrote \(url.path)")
