import AppKit

/// Renders a monitored app's icon with a red unread badge overlaid, sized for
/// the menu bar. The canvas widens to fit the badge so multi-digit counts
/// (e.g. "128") are never clipped.
enum BadgeIcon {
    private static let iconSize: CGFloat = 18

    static func render(appIcon: NSImage, badge: String?, showsCount: Bool, dimWhenEmpty: Bool = false) -> NSImage {
        guard let badge, !badge.isEmpty else {
            return iconOnly(appIcon, dimmed: dimWhenEmpty)
        }
        guard showsCount else {
            return iconWithDot(appIcon)
        }

        let font = NSFont.systemFont(ofSize: 9, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: badge, attributes: attributes)
        let textSize = string.size()

        let badgeHeight = textSize.height + 2
        let badgeWidth = max(badgeHeight, textSize.width + 6)

        // Let the badge overflow the icon's right edge, and widen the canvas so
        // it isn't clipped by the status item.
        let overflow = max(0, badgeWidth - iconSize * 0.55)
        let canvas = NSSize(width: iconSize + overflow, height: iconSize)

        let image = NSImage(size: canvas)
        image.lockFocus()

        appIcon.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: 1.0)

        let badgeRect = NSRect(
            x: canvas.width - badgeWidth,
            y: canvas.height - badgeHeight,
            width: badgeWidth,
            height: badgeHeight
        )
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2)
            .fill(with: .systemRed)

        let textRect = NSRect(
            x: badgeRect.minX + (badgeWidth - textSize.width) / 2,
            y: badgeRect.minY + (badgeHeight - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        string.draw(in: textRect)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Icon with a small red dot in the corner — used when the count is hidden
    /// but a notification is present.
    private static func iconWithDot(_ appIcon: NSImage) -> NSImage {
        let size = NSSize(width: iconSize, height: iconSize)
        let image = NSImage(size: size)
        image.lockFocus()

        appIcon.draw(in: NSRect(origin: .zero, size: size),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: 1.0)

        let diameter = iconSize * 0.42
        let dotRect = NSRect(x: size.width - diameter,
                             y: size.height - diameter,
                             width: diameter,
                             height: diameter)

        NSColor.white.setFill()
        NSBezierPath(ovalIn: dotRect.insetBy(dx: -1.2, dy: -1.2)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func iconOnly(_ appIcon: NSImage, dimmed: Bool = false) -> NSImage {
        let size = NSSize(width: iconSize, height: iconSize)
        let image = NSImage(size: size)
        image.lockFocus()
        appIcon.draw(in: NSRect(origin: .zero, size: size),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: dimmed ? 0.35 : 1.0)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}
