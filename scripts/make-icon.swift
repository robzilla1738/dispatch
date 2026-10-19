#!/usr/bin/env swift
import AppKit
import Foundation

// Generates Dispatch's app icon and menu-bar glyph from vector drawing code.
// Usage: swift scripts/make-icon.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Sources/DispatchApp/Resources")
let icons = resources.appendingPathComponent("Icons")
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("Dispatch.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)

func makeAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current else {
        image.unlockFocus()
        return image
    }
    context.imageInterpolation = .high
    let scale = size / 1024

    let outer = NSRect(x: 62 * scale, y: 62 * scale, width: 900 * scale, height: 900 * scale)
    let shape = NSBezierPath(roundedRect: outer, xRadius: 218 * scale, yRadius: 218 * scale)

    // Soft depth under the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 42 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -14 * scale)
    shadow.set()
    NSColor(calibratedRed: 0.20, green: 0.16, blue: 0.45, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Indigo-to-coral dusk gradient.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.66, alpha: 1),
        NSColor(calibratedRed: 0.47, green: 0.25, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.87, green: 0.28, blue: 0.45, alpha: 1),
    ])
    gradient?.draw(in: shape, angle: -55)

    // Soft light from the upper-left, with a transparent outer stop so the
    // tile has no hard gradient seam.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    if let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.20),
        NSColor.white.withAlphaComponent(0.0),
    ]) {
        let center = NSPoint(x: 345 * scale, y: 760 * scale)
        glow.draw(
            fromCenter: center,
            radius: 0,
            toCenter: center,
            radius: 560 * scale,
            options: []
        )
    }
    NSGraphicsContext.restoreGraphicsState()

    // Fine edge highlight.
    NSGraphicsContext.saveGraphicsState()
    NSColor.white.withAlphaComponent(0.20).setStroke()
    shape.lineWidth = 3 * scale
    shape.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // White dispatch glyph. SF Symbols supplies crisp, platform-native geometry.
    if let symbol = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "Dispatch") {
        let configuration = NSImage.SymbolConfiguration(pointSize: 500 * scale, weight: .regular)
        if let configured = symbol.withSymbolConfiguration(configuration) {
            let glyphSize = NSSize(width: 530 * scale, height: 530 * scale)
            let rect = NSRect(
                x: (size - glyphSize.width) / 2,
                y: (size - glyphSize.height) / 2 - 8 * scale,
                width: glyphSize.width,
                height: glyphSize.height
            )
            let tinted = NSImage(size: glyphSize)
            tinted.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: glyphSize).fill()
            configured.draw(
                in: NSRect(origin: .zero, size: glyphSize),
                from: .zero,
                operation: .destinationIn,
                fraction: 1
            )
            tinted.unlockFocus()

            NSGraphicsContext.saveGraphicsState()
            let glyphShadow = NSShadow()
            glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
            glyphShadow.shadowBlurRadius = 24 * scale
            glyphShadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
            glyphShadow.set()
            tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    image.unlockFocus()
    return image
}

func pngData(_ image: NSImage, pixelSize: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let master = makeAppIcon(size: 1024)
try pngData(master, pixelSize: 1024)?.write(to: iconset.appendingPathComponent("icon_512x512@2x.png"))
let docsScreenshots = root.appendingPathComponent("docs/screenshots")
try? FileManager.default.createDirectory(at: docsScreenshots, withIntermediateDirectories: true)
try? pngData(master, pixelSize: 256)?.write(to: docsScreenshots.appendingPathComponent("app-icon.png"))

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
]
for (size, name) in sizes {
    let image = makeAppIcon(size: CGFloat(size))
    if let data = pngData(image, pixelSize: size) {
        try data.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon-Release.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

func makeStatusGlyph(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="\(pixelSize)" height="\(pixelSize)">
    <path fill="#000000" d="M21.4 2.6a1.1 1.1 0 0 0-1.15-.24L2.9 9.2a1.1 1.1 0 0 0-.05 2.02l7.15 3.18 3.18 7.15a1.1 1.1 0 0 0 2.02-.05l6.84-17.35a1.1 1.1 0 0 0-.64-1.55zM10.8 13.2l6.4-6.4-4.95 9.65-1.45-3.25z"/>
    </svg>
    """
    guard let svgData = svg.data(using: .utf8),
          let svgImg = NSImage(data: svgData) else { return nil }
    return pngData(svgImg, pixelSize: Int(size))
}

for (size, suffix) in [(16, ""), (32, "@2x")] {
    if let data = makeStatusGlyph(pixelSize: size) {
        try data.write(to: icons.appendingPathComponent("dispatch-status-16\(suffix).png"))
    }
}
for (size, name) in [
    (128, "dispatch-mark-128.png"),
    (256, "dispatch-mark-128@2x.png"),
] {
    if let data = makeStatusGlyph(pixelSize: size) {
        try data.write(to: icons.appendingPathComponent(name))
    }
}

print("Wrote AppIcon-Release.icns and menu-bar glyphs")
