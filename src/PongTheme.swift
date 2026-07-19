import AppKit

/// SuperGrok-inspired design tokens: deep black, soft elevation, crisp type, restrained accent.
enum PongTheme {
    // Backgrounds
    static let bg = NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.045, alpha: 1)       // #0A0A0B
    static let bgElevated = NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1) // cards
    static let bgHover = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    static let bgInput = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    static let bgFooter = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)

    // Text
    static let textPrimary = NSColor(calibratedWhite: 0.96, alpha: 1)
    static let textSecondary = NSColor(calibratedWhite: 0.55, alpha: 1)
    static let textTertiary = NSColor(calibratedWhite: 0.38, alpha: 1)

    // Borders / hairlines
    static let border = NSColor(calibratedWhite: 1, alpha: 0.08)
    static let borderStrong = NSColor(calibratedWhite: 1, alpha: 0.14)

    // Accents (restrained — SuperGrok-like monochrome + one signal color)
    static let accent = NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.95, alpha: 1) // near-white CTA
    static let accentInk = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)
    static let live = NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.55, alpha: 1)   // soft green
    static let warn = NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.28, alpha: 1)
    static let idle = NSColor(calibratedWhite: 0.35, alpha: 1)
    static let tabSelected = NSColor(calibratedWhite: 1, alpha: 0.12)
    static let tabIdle = NSColor.clear

    static let radiusCard: CGFloat = 14
    static let radiusPill: CGFloat = 10
    static let radiusBtn: CGFloat = 10

    static func applyCard(_ v: NSView, elevated: Bool = true) {
        v.wantsLayer = true
        v.layer?.backgroundColor = (elevated ? bgElevated : bgInput).cgColor
        v.layer?.cornerRadius = radiusCard
        v.layer?.borderWidth = 1
        v.layer?.borderColor = border.cgColor
    }

    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        .systemFont(ofSize: size, weight: weight)
    }
}
