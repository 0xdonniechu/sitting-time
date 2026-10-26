import AppKit

/// Vector pictograms for desk work, drawn as solid silhouettes: a person at a
/// desk with a monitor arm, seated on an office chair at a low desk or
/// standing at a raised desk. One fixed canvas for both states, sharing the
/// ground line and the desk's horizontal slot, so switching posture never
/// moves surrounding UI. Drawn black as a template image; callers tint
/// through `isTemplate`.
public let deskPictogramSize = NSSize(width: 100, height: 78)

/// Width over height; shared by the SwiftUI view and the menu bar image so
/// every host frames the pictogram identically.
public var deskPictogramAspect: CGFloat {
    deskPictogramSize.width / deskPictogramSize.height
}

public func deskPictogramImage(sitting: Bool) -> NSImage {
    let image = NSImage(size: deskPictogramSize, flipped: false) { _ in
        drawDeskPictogram(sitting: sitting)
        return true
    }
    image.isTemplate = true
    return image
}

private func capsule(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x1, y: y1))
    path.line(to: NSPoint(x: x2, y: y2))
    path.lineCapStyle = .round
    path.lineWidth = width
    NSColor.black.setStroke()
    path.stroke()
}

private func disc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
}

private func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) {
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: radius, yRadius: radius).fill()
}

private func drawDeskPictogram(sitting: Bool) {
    if sitting {
        // Head, torso leaning to the desk, arm reaching the low top.
        disc(23, 61, 8.5)
        capsule(24, 52, 30, 34, 13)
        capsule(28, 48, 53, 38.5, 7.5)
        // Thigh, calf, foot.
        capsule(30, 32, 48, 32, 10)
        capsule(48, 32, 48, 11, 9)
        capsule(44, 7, 54, 7, 5)
        // Office chair: reclined backrest, seat, post, base, casters.
        capsule(9, 27, 12, 46, 7)
        block(8, 26, 26, 5, 2)
        capsule(21, 26, 21, 14, 4)
        capsule(21, 14, 9, 6, 3)
        capsule(21, 14, 21, 5, 3)
        capsule(21, 14, 33, 6, 3)
        disc(9, 5, 2.5)
        disc(21, 4, 2.5)
        disc(33, 5, 2.5)
        drawDesk(topY: 34)
    } else {
        // Head, upright torso, arm reaching the high top.
        disc(24, 64, 8.5)
        capsule(25, 51, 27, 33, 13)
        capsule(28, 47, 53, 44.5, 8)
        // Spread legs, feet.
        capsule(25, 33, 20, 9, 9)
        capsule(29, 33, 34, 9, 9)
        capsule(14, 6, 26, 6, 5)
        capsule(28, 6, 40, 6, 5)
        drawDesk(topY: 44)
    }
}

/// Desk slab + pedestal leg + foot, with a monitor on an articulated arm.
/// `topY` is the top surface; the horizontal slot is shared by both states.
private func drawDesk(topY: CGFloat) {
    block(53, topY - 4, 36, 4, 1.5)
    block(67, 6, 5, topY - 10, 1)
    block(55, 3, 32, 3.5, 1.5)
    // Monitor arm clamped near the back edge: post, elbow, screen.
    capsule(84, topY, 84, topY + 12, 3)
    disc(84, topY + 12, 2.6)
    capsule(84, topY + 12, 74, topY + 20, 3)
    disc(74, topY + 20, 2.4)
    block(68, topY + 16, 6, 14, 1.5)
}
