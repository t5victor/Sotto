#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent(
    "Sotto-AppIcon-\(UUID().uuidString).iconset",
    isDirectory: true
)
defer { try? FileManager.default.removeItem(at: iconset) }
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let output = root.appendingPathComponent("Sources/Sotto/Resources/AppIcon.icns")
let artworkURL = root.appendingPathComponent("Assets/Sotto-icon-background.png")
guard let imageSource = CGImageSourceCreateWithURL(artworkURL as CFURL, nil),
      let artworkImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    fatalError("Unable to load icon artwork at \(artworkURL.path)")
}

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

    let imageWidth = CGFloat(artworkImage.width)
    let imageHeight = CGFloat(artworkImage.height)
    let scale = max(side / imageWidth, side / imageHeight)
    let scaledSize = CGSize(width: imageWidth * scale, height: imageHeight * scale)
    let imageRect = CGRect(
        x: (side - scaledSize.width) / 2,
        y: (side - scaledSize.height) / 2,
        width: scaledSize.width,
        height: scaledSize.height
    )
    context.interpolationQuality = .high
    context.draw(artworkImage, in: imageRect)
    context.restoreGState()

    guard let image = context.makeImage() else { fatalError("Unable to render icon") }
    let destinationURL = iconset.appendingPathComponent(name) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(
        destinationURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("Unable to create PNG destination") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write \(name)") }
}

func bigEndianData(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}

// Assemble the modern PNG-backed ICNS entries directly. This keeps the
// generator reproducible on macOS versions whose iconutil rejects iconsets.
let icnsEntries: [(String, String)] = [
    ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

var payload = Data()
for (type, name) in icnsEntries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(name))
    payload.append(Data(type.utf8))
    payload.append(bigEndianData(UInt32(png.count + 8)))
    payload.append(png)
}

var icns = Data("icns".utf8)
icns.append(bigEndianData(UInt32(payload.count + 8)))
icns.append(payload)
try icns.write(to: output, options: [.atomic])

print(output.path)
