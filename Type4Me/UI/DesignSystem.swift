import SwiftUI

// MARK: - Appearance Helper

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - Adaptive Color Helper

private func adaptiveColor(
    light: (r: CGFloat, g: CGFloat, b: CGFloat),
    dark: (r: CGFloat, g: CGFloat, b: CGFloat)
) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.isDark {
            return NSColor(srgbRed: dark.r, green: dark.g, blue: dark.b, alpha: 1.0)
        }
        return NSColor(srgbRed: light.r, green: light.g, blue: light.b, alpha: 1.0)
    }))
}

// MARK: - Design Tokens

enum TF {

    // MARK: Colors

    /// Warm amber accent: the signature "indicator light" color
    static let amber = adaptiveColor(
        light: (0.76, 0.49, 0.16),
        dark:  (0.83, 0.57, 0.24)
    )

    /// Recording active: warm red-orange, urgent but not alarming
    static let recording = adaptiveColor(
        light: (0.84, 0.34, 0.27),
        dark:  (0.87, 0.38, 0.30)
    )

    /// Success: muted warm green
    static let success = adaptiveColor(
        light: (0.35, 0.65, 0.35),
        dark:  (0.42, 0.70, 0.42)
    )

    // MARK: Settings Palette

    static let settingsBg = Color(nsColor: .controlBackgroundColor)
    static let settingsCard = Color(nsColor: .windowBackgroundColor)
    static let settingsCardAlt = Color(nsColor: .quaternaryLabelColor).opacity(0.16)
    static let settingsNavActive = Color.accentColor
    static let settingsText = Color.primary
    static let settingsTextSecondary = Color.secondary
    static let settingsTextTertiary = Color(nsColor: .tertiaryLabelColor)
    static let settingsAccentGreen = Color(nsColor: .systemGreen)
    static let settingsAccentAmber = amber
    static let settingsAccentRed = Color(nsColor: .systemRed)
    static let settingsAccentBlue = Color(nsColor: .systemBlue)

    // MARK: Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24

    // MARK: Corner Radius

    static let cornerSM: CGFloat = 6
    static let cornerMD: CGFloat = 10
    static let cornerLG: CGFloat = 16

    // MARK: Floating Bar

    static let barWidth: CGFloat = 400
    static let barWidthCompact: CGFloat = 200
    static let barHeight: CGFloat = 52
    static let barBottomOffset: CGFloat = 48

    // MARK: Transcript Popup (hover preview above bar)

    static let transcriptPopupMaxHeight: CGFloat = 400
    static let transcriptPopupCorner: CGFloat = 14
    static let transcriptPopupGap: CGFloat = 8

    // MARK: Animation

    static let springSnappy = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let springGentle = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.65)
    static let easeQuick = Animation.easeOut(duration: 0.2)
    static let glassTint = Animation.easeInOut(duration: 0.5)
}
