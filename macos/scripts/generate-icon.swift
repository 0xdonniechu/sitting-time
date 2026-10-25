import AppKit
import Foundation

// Generates SittingTime.icns: dark teal rounded square, white minimal chair,
// orange "tracking" dot. Verifies its own rendering by sampling pixels, so a
// broken draw fails the build instead of shipping a blank icon.
//
// Usage: generate-icon.swift <output.icns>

let outPath = CommandLine.arguments.dropFirst().first ?? "SittingTime.icns"
let masterSize: CGFloat = 1024

func drawMaster() -> NSImage {
    let image = NSImage(size: NSSize(width: masterSize, height: masterSize))
    image.lockFocus()
    defer { image.unlockFocus() }
    let s = masterSize
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Background: rounded rect, slate -> teal gradient (origin is bottom-left).
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                           xRadius: s * 0.225, yRadius: s * 0.225)
    let bottom = NSColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1)
    let top = NSColor(red: 0.06, green: 0.45, blue: 0.42, alpha: 1)
    NSGradient(starting: bottom, ending: top)?.draw(in: bg, angle: 90)

    // Chair: backrest, seat, two legs.
    NSColor.white.setFill()
    NSBezierPath(roundedRect: r(0.36, 0.30, 0.08, 0.40), xRadius: s * 0.04, yRadius: s * 0.04).fill()
    NSBezierPath(roundedRect: r(0.36, 0.30, 0.30, 0.08), xRadius: s * 0.04, yRadius: s * 0.04).fill()
    NSBezierPath(roundedRect: r(0.375, 0.12, 0.045, 0.19), xRadius: s * 0.022, yRadius: s * 0.022).fill()
    NSBezierPath(roundedRect: r(0.60, 0.12, 0.045, 0.19), xRadius: s * 0.022, yRadius: s * 0.022).fill()

    // Tracking dot.
    NSColor(red: 0.97, green: 0.45, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(ovalIn: r(0.685, 0.665, 0.11, 0.11)).fill()

    return image
}

// Coordinates are bottom-left (drawing space); the flattened bytes below
// are top-left, hence the row flip.
func pixel(_ bytes: Data, _ w: Int, _ h: Int, _ x: Int, _ y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    let o = ((h - 1 - y) * w + x) * 4
    return (CGFloat(bytes[o]) / 255, CGFloat(bytes[o + 1]) / 255, CGFloat(bytes[o + 2]) / 255, CGFloat(bytes[o + 3]) / 255)
}

func check(_ name: String, _ ok: Bool) {
    if !ok {
        fputs("generate-icon: pixel check failed: \(name)\n", stderr)
        exit(1)
    }
}

let master = drawMaster()
// Flatten to explicit 8-bit sRGB bytes: lockFocus/tiffRepresentation bit depth
// follows the environment (16-bit with display access, 8-bit without), and
// getPixel on a 16-bit rep returns garbage, so never sample it directly.
guard let tiff = master.tiffRepresentation,
      let src = CGImageSourceCreateWithData(tiff as CFData, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let cs = CGColorSpace(name: CGColorSpace.sRGB) else {
    fputs("generate-icon: cannot rasterize master image\n", stderr)
    exit(1)
}
let w = cg.width, h = cg.height
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fputs("generate-icon: cannot create 8-bit context\n", stderr)
    exit(1)
}
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
guard let flat = ctx.makeImage(),
      let cfData = flat.dataProvider?.data else {
    fputs("generate-icon: cannot read back pixels\n", stderr)
    exit(1)
}
let bytes = cfData as Data
let n = w
// Chair backrest centre must be near-white.
let chair = pixel(bytes, w, h, Int(0.40 * CGFloat(n)), Int(0.50 * CGFloat(n)))
check("chair", chair.r > 0.9 && chair.g > 0.9 && chair.b > 0.9 && chair.a > 0.9)
// Sky area must be dark teal, opaque.
let sky = pixel(bytes, w, h, Int(0.50 * CGFloat(n)), Int(0.88 * CGFloat(n)))
check("sky", sky.r < 0.25 && sky.g > 0.3 && sky.b > 0.3 && sky.a > 0.9)
// Dot centre must be orange.
let dot = pixel(bytes, w, h, Int(0.74 * CGFloat(n)), Int(0.72 * CGFloat(n)))
check("dot", dot.r > 0.85 && dot.g > 0.3 && dot.g < 0.6 && dot.b < 0.25)
// Extreme corner must be transparent (rounded rect).
let corner = pixel(bytes, w, h, 4, 4)
check("corner", corner.a < 0.1)

// Render PNGs at every pixel size a modern .icns carries.
func renderPNG(pixels: Int) -> Data? {
    let px = CGFloat(pixels)
    let scaled = NSImage(size: NSSize(width: px, height: px))
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
                from: NSRect(x: 0, y: 0, width: masterSize, height: masterSize),
                operation: .copy, fraction: 1)
    scaled.unlockFocus()
    guard let data = scaled.tiffRepresentation,
          let rep = NSBitmapImageRep(data: data) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

// Assemble the .icns by hand: 'icns' + total length, then per element
// OSType + length + PNG payload. Same bytes iconutil would emit, no subprocess.
let elements: [(type: String, pixels: Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
    ("ic08", 256), ("ic09", 512), ("ic10", 1024),
]
func u32be(_ v: UInt32) -> Data {
    Data([UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
}
var body = Data()
for (type, pixels) in elements {
    guard let png = renderPNG(pixels: pixels) else {
        fputs("generate-icon: cannot render \(pixels)px\n", stderr)
        exit(1)
    }
    body.append(contentsOf: type.utf8)
    body.append(u32be(UInt32(8 + png.count)))
    body.append(png)
}
var icns = Data("icns".utf8)
icns.append(u32be(UInt32(8 + body.count)))
icns.append(body)
try icns.write(to: URL(fileURLWithPath: outPath))

// Validate: the file must parse as an image container with 7 entries.
guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, nil) else {
    fputs("generate-icon: output does not parse as an image\n", stderr)
    exit(1)
}
let count = CGImageSourceGetCount(src)
if count != elements.count {
    fputs("generate-icon: expected \(elements.count) images, got \(count)\n", stderr)
    exit(1)
}
print("Wrote \(outPath) (\(count) images)")
