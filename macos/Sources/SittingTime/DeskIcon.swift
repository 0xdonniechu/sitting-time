import AppKit
import SwiftUI
import SittingCore

/// Desk-work glyph: the solid-silhouette pictogram (person + desk + monitor
/// arm), seated on an office chair at a low desk or standing at a raised one.
/// Both states share one fixed frame, so switching posture can never shift
/// surrounding layout.
struct DeskIcon: View {
    var deskRaised: Bool
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: deskPictogramImage(sitting: !deskRaised))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * deskPictogramAspect, height: size)
    }
}

/// Menu bar twin of `DeskIcon`: the same pictogram sized to the status
/// button's font. The canvas is identical in both states, so the menu bar
/// clock never jitters on posture switches.
func deskCompositeImage(pointSize: CGFloat, deskRaised: Bool) -> NSImage {
    let image = deskPictogramImage(sitting: !deskRaised)
    image.size = NSSize(width: pointSize * deskPictogramAspect, height: pointSize)
    return image
}

/// Fixed menu bar canvas: every status image is centered aspect-fit in the
/// pictogram-wide box. Without this, pausing or skipping swaps a wide
/// pictogram for a narrower SF Symbol, the status item shrinks, and the
/// open popover visibly jumps to its new anchor.
func statusItemImage(_ image: NSImage?, pointSize: CGFloat) -> NSImage? {
    guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
    let box = NSSize(width: pointSize * deskPictogramAspect, height: pointSize)
    let scale = min(box.width / image.size.width, box.height / image.size.height)
    let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let canvas = NSImage(size: box, flipped: false) { _ in
        image.draw(in: NSRect(
            x: (box.width - drawSize.width) / 2,
            y: (box.height - drawSize.height) / 2,
            width: drawSize.width, height: drawSize.height
        ))
        return true
    }
    canvas.isTemplate = image.isTemplate
    canvas.accessibilityDescription = image.accessibilityDescription
    return canvas
}
