// Code-native AppSwitcher keyboard mark. No remote artwork or third-party icon assets.
import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
func round(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
round(NSRect(x: 48, y: 48, width: 928, height: 928), radius: 204,
      color: NSColor(srgbRed: 0.11, green: 0.13, blue: 0.17, alpha: 1))
round(NSRect(x: 127, y: 239, width: 770, height: 523), radius: 92,
      color: NSColor(srgbRed: 0.07, green: 0.085, blue: 0.11, alpha: 1))
let gray = NSColor(srgbRed: 0.27, green: 0.30, blue: 0.35, alpha: 1)
let blue = NSColor(srgbRed: 0.16, green: 0.45, blue: 0.90, alpha: 1)
for (y, widths) in [(CGFloat(572), [CGFloat(177), 177, 177]),
                    (CGFloat(371), [CGFloat(177), 380])] {
    var x: CGFloat = 201
    for (i, width) in widths.enumerated() {
        let highlighted = y == 572 && i == 1
        let rect = NSRect(x: x, y: y, width: width, height: 148)
        round(rect.offsetBy(dx: 0, dy: -12), radius: 30,
              color: NSColor(srgbRed: 0.025, green: 0.03, blue: 0.045, alpha: 1))
        round(rect, radius: 30, color: highlighted ? blue : gray)
        if highlighted {
            let text = "A" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 84, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let measured = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: rect.midX - measured.width / 2,
                                  y: rect.midY - measured.height / 2), withAttributes: attributes)
        }
        x += width + 26
    }
}
NSGraphicsContext.restoreGraphicsState()
let source = NSImage(size: NSSize(width: size, height: size))
source.addRepresentation(bitmap)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
        try output.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
