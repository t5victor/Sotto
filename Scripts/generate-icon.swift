#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(
    "Sources/Sotto/Resources/AppIcon.iconset",
    isDirectory: true
)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let assetCatalogIcon = root.appendingPathComponent(
    "Sources/Sotto/Resources/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)
try FileManager.default.createDirectory(at: assetCatalogIcon, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1_024),
]

for (name, size) in outputs {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Unable to create icon context") }

    context.interpolationQuality = .high
    let side = CGFloat(size)
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    let inset = side * 0.045
    let plate = bounds.insetBy(dx: inset, dy: inset)
    let corner = side * 0.225

    context.saveGState()
    context.addPath(CGPath(roundedRect: plate, cornerWidth: corner, cornerHeight: corner, transform: nil))
    context.clip()

    let colors = [
        CGColor(red: 0.19, green: 0.12, blue: 0.48, alpha: 1),
        CGColor(red: 0.48, green: 0.30, blue: 0.96, alpha: 1),
        CGColor(red: 0.67, green: 0.39, blue: 0.98, alpha: 1),
    ] as CFArray
    let locations: [CGFloat] = [0, 0.55, 1]
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: locations
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: side * 0.12, y: side * 0.95),
        end: CGPoint(x: side * 0.88, y: side * 0.05),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.24),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: side * 0.32, y: side * 0.76),
        startRadius: 0,
        endCenter: CGPoint(x: side * 0.32, y: side * 0.76),
        endRadius: side * 0.58,
        options: []
    )
    context.restoreGState()

    context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
    context.setLineCap(.round)
    context.setLineWidth(side * 0.067)
    let heights: [CGFloat] = [0.22, 0.40, 0.61, 0.80, 0.58, 0.74, 0.43, 0.26]
    let spacing = side * 0.082
    let startX = side * 0.213
    for (index, height) in heights.enumerated() {
        let x = startX + CGFloat(index) * spacing
        let half = side * height * 0.255
        context.move(to: CGPoint(x: x, y: side * 0.5 - half))
        context.addLine(to: CGPoint(x: x, y: side * 0.5 + half))
        context.strokePath()
    }

    guard let image = context.makeImage() else { fatalError("Unable to render icon") }
    for directory in [iconset, assetCatalogIcon] {
        let destinationURL = directory.appendingPathComponent(name) as CFURL
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { fatalError("Unable to create PNG destination") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write \(name)") }
    }
}

print(iconset.path)
