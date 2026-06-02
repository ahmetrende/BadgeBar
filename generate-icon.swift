#!/usr/bin/env swift
import AppKit

// Generates AppIcon.iconset (PNGs at all required sizes) for BadgeBar.
// Design: a blue squircle with a white bell and a red unread badge — the app's
// whole point, in one glyph. Run: `swift generate-icon.swift`, then
// `iconutil -c icns AppIcon.iconset`.

func drawIcon(size: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Rounded squircle background with a vertical blue→indigo gradient.
    let inset = size * 0.055
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = rect.width * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.40, green: 0.56, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.22, green: 0.36, blue: 0.82, alpha: 1),
    ])!
    gradient.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // White bell, centered and fit by aspect ratio.
    if let bell = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
        let configured = bell.withSymbolConfiguration(config) ?? bell
        let white = tint(configured, with: .white)
        let box = size * 0.46
        let s = white.size
        let scale = min(box / s.width, box / s.height)
        let w = s.width * scale, h = s.height * scale
        let bx = (size - w) / 2
        let by = (size - h) / 2 - size * 0.02
        white.draw(in: NSRect(x: bx, y: by, width: w, height: h))
    }

    // Red unread badge (with a white ring) at the top-right, showing "3".
    let badgeD = size * 0.30
    let badgeRect = NSRect(x: size * 0.585, y: size * 0.585, width: badgeD, height: badgeD)

    NSColor.white.setFill()
    NSBezierPath(ovalIn: badgeRect.insetBy(dx: -size * 0.022, dy: -size * 0.022)).fill()

    NSColor(srgbRed: 0.96, green: 0.26, blue: 0.21, alpha: 1).setFill()
    NSBezierPath(ovalIn: badgeRect).fill()

    let number = "3"
    let font = NSFont.systemFont(ofSize: badgeD * 0.62, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let str = NSAttributedString(string: number, attributes: attrs)
    let ts = str.size()
    str.draw(in: NSRect(x: badgeRect.midX - ts.width / 2,
                        y: badgeRect.midY - ts.height / 2,
                        width: ts.width, height: ts.height))
}

func tint(_ image: NSImage, with color: NSColor) -> NSImage {
    let result = NSImage(size: image.size)
    result.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    color.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    result.unlockFocus()
    return result
}

func writePNG(pixels: Int, to path: String) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

let iconset = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// (filename, pixel size)
let variants: [(String, Int)] = [
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

for (name, px) in variants {
    writePNG(pixels: px, to: "\(iconset)/\(name)")
}
print("Wrote \(iconset) (\(variants.count) images)")
