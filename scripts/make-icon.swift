import AppKit

let destination = CommandLine.arguments[1] + "/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(calibratedRed: 0.25, green: 0.34, blue: 0.88, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 45, y: 45, width: 934, height: 934), xRadius: 210, yRadius: 210).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 213, y: 209, width: 598, height: 582), xRadius: 70, yRadius: 70).fill()
        NSColor(calibratedRed: 0.86, green: 0.89, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 213, y: 644, width: 598, height: 147), xRadius: 60, yRadius: 60).fill()
        for x in [350, 674] {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: x - 22, y: 725, width: 44, height: 127), xRadius: 22, yRadius: 22).fill()
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        ("28" as NSString).draw(in: NSRect(x: 215, y: 260, width: 594, height: 340), withAttributes: [
            .font: NSFont.systemFont(ofSize: 290, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.25, green: 0.34, blue: 0.88, alpha: 1),
            .paragraphStyle: paragraph
        ])
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination + "/icon_\(size)x\(size)\(suffix).png"))
    }
}
