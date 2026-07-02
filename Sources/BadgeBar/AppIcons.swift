import AppKit

/// Single cached source of app icons keyed by bundle id. NSCache evicts under
/// memory pressure, so there's nothing to prune manually.
enum AppIcons {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleId bundleId: String) -> NSImage {
        if let hit = cache.object(forKey: bundleId as NSString) {
            return hit
        }
        let image: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        cache.setObject(image, forKey: bundleId as NSString)
        return image
    }
}
