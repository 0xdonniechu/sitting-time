import AppKit
import SittingCore

/// Tile zodiac icons: monochrome alpha masks from Resources/Zodiac, loaded
/// as template images so the tile tints them with the year element color.
/// Missing art (Vietnamese cat) resolves to nil and the eyebrow shows
/// text only. Main-actor isolated: every caller renders UI.
@MainActor
enum ZodiacArt {
    private static let cache = NSCache<NSString, NSImage>()

    /// Overrides the art directory (previews). Production reads the app bundle.
    static var directoryOverride: URL?

    static func image(for animal: ZodiacAnimal?) -> NSImage? {
        guard let animal else { return nil }
        let key = animal.assetName as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url: URL?
        if let dir = directoryOverride {
            url = dir.appendingPathComponent("\(animal.assetName).png")
        } else {
            url = Bundle.main.url(forResource: animal.assetName, withExtension: "png", subdirectory: "Zodiac")
        }
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        cache.setObject(image, forKey: key)
        return image
    }
}
