#!/usr/bin/env swift
import AppKit

// Placeholder art until replaced by a Figma export.
// Icon centers in make-dmg: (140, 190), (360, 190), (580, 190) — 128px icons.
let width = 720
let height = 480
let size = NSSize(width: width, height: height)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let mist = NSColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1)
let panel = NSColor(red: 0.965, green: 0.97, blue: 0.975, alpha: 1)
let ink = NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1)
let inkSecondary = NSColor(red: 0.28, green: 0.32, blue: 0.36, alpha: 1)
let accent = NSColor(red: 0.34, green: 0.61, blue: 0.58, alpha: 1)
let stroke = NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 0.14)

NSGradient(starting: mist, ending: panel)?.draw(in: NSRect(origin: .zero, size: size), angle: 90)

accent.withAlphaComponent(0.08).setFill()
NSBezierPath(rect: NSRect(x: 0, y: height - 120, width: width, height: 120)).fill()

func drawArrow(from startX: CGFloat, to endX: CGFloat, y: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: startX, y: y))
    path.line(to: NSPoint(x: endX - 14, y: y))
    path.lineWidth = 4
    path.lineCapStyle = .round
    accent.withAlphaComponent(0.85).setStroke()
    path.stroke()

    let tip = NSBezierPath()
    tip.move(to: NSPoint(x: endX, y: y))
    tip.line(to: NSPoint(x: endX - 18, y: y + 12))
    tip.line(to: NSPoint(x: endX - 18, y: y - 12))
    tip.close()
    accent.withAlphaComponent(0.85).setFill()
    tip.fill()
}

// Gaps between icon centers 140 → 360 → 580
let arrowY: CGFloat = 190
drawArrow(from: 210, to: 290, y: arrowY)
drawArrow(from: 430, to: 510, y: arrowY)

let titleFont = NSFont(name: "AvenirNextCondensed-Bold", size: 28)
    ?? NSFont(name: "Avenir Next Condensed", size: 28)
    ?? NSFont.boldSystemFont(ofSize: 28)
let bodyFont = NSFont(name: "AvenirNext-Medium", size: 13)
    ?? NSFont(name: "Avenir Next", size: 13)
    ?? NSFont.systemFont(ofSize: 13, weight: .medium)
let footFont = NSFont(name: "AvenirNext-Regular", size: 11)
    ?? NSFont(name: "Avenir Next", size: 11)
    ?? NSFont.systemFont(ofSize: 11)

let title = "SNAPFRAME" as NSString
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: ink,
    .kern: 3.5,
]
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(
    at: NSPoint(x: (CGFloat(width) - titleSize.width) / 2, y: CGFloat(height) - 64),
    withAttributes: titleAttrs
)

let subtitle = "Drag to Applications, then run Dependencies" as NSString
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: bodyFont,
    .foregroundColor: inkSecondary,
]
let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
subtitle.draw(
    at: NSPoint(x: (CGFloat(width) - subtitleSize.width) / 2, y: CGFloat(height) - 92),
    withAttributes: subtitleAttrs
)

stroke.setStroke()
let rule = NSBezierPath()
rule.move(to: NSPoint(x: 40, y: 36))
rule.line(to: NSPoint(x: width - 40, y: 36))
rule.lineWidth = 1
rule.stroke()

let foot = "Dependencies installs Homebrew mpv and clears quarantine" as NSString
let footAttrs: [NSAttributedString.Key: Any] = [
    .font: footFont,
    .foregroundColor: inkSecondary.withAlphaComponent(0.85),
]
let footSize = foot.size(withAttributes: footAttrs)
foot.draw(
    at: NSPoint(x: (CGFloat(width) - footSize.width) / 2, y: 14),
    withAttributes: footAttrs
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Packaging/dmg-background.png"
try data.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
