import AppKit
import CoreText
import SwiftUI

/// Every colour, font size and radius the app uses, from Design/tokens.json and Design/BRAND.md.
/// Views never use hex values or raw sizes: they use these.
enum Theme {
    // MARK: Colour tokens (tokens.json "color"; dark is the default, light swaps)

    static let bg = Color(dark: 0x000000, light: 0xEEE5E9)
    static let surface = Color(dark: 0x0E0E10, light: 0xFFFFFF)
    static let surface2 = Color(dark: 0x18181B, light: 0xF6F1F3)
    static let text = Color(dark: 0xEEE5E9, light: 0x000000)
    static let textMuted = Color(dark: 0x7C7C7C, light: 0x565456)
    static let primary = Color(dark: 0x92DCE5, light: 0x000000)
    /// Burnt Tangerine: alert UI only (BRAND.md).
    static let warning = Color(dark: 0xD64933, light: 0xB83A26)

    // Brand colours that don't swap.
    static let frostedBlue = Color(dark: 0x92DCE5, light: 0x92DCE5)
    static let grey = Color(dark: 0x7C7C7C, light: 0x7C7C7C)
    static let lavenderBlush = Color(dark: 0xEEE5E9, light: 0xEEE5E9)
    static let black = Color(dark: 0x000000, light: 0x000000)
    static let warningText = Color(dark: 0xEF7A63, light: 0xB83A26)
    /// Document glyphs: Lavender Blush sheet on dark, white with a hairline on light (screens 04 and 24).
    static let docFill = Color(dark: 0xEEE5E9, light: 0xFFFFFF)
    static let docBadge = Color(dark: 0x4A4A4E, light: 0x5A5A5E)

    /// Hairlines: Lavender Blush at 8% (line) and 13% (line2) on dark.
    static let line = Color(dark: 0xEEE5E9, light: 0x000000, opacity: 0.08)
    static let line2 = Color(dark: 0xEEE5E9, light: 0x000000, opacity: 0.13)

    /// Popover background rgba(30,30,34,.92) over vibrancy, with a Lavender Blush 8.5% inner border.
    static let popoverBackground = Color(dark: 0x1E1E22, light: 0xFFFFFF, opacity: 0.92)
    static let popoverBorder = Color(dark: 0xEEE5E9, light: 0x000000, opacity: 0.085)

    /// Selected row: Frosted Blue 14% fill + 1 pt Frosted Blue 22% inner border.
    static let selectedFill = Color(dark: 0x92DCE5, light: 0x000000, opacity: 0.14)
    static let selectedBorder = Color(dark: 0x92DCE5, light: 0x000000, opacity: 0.22)
    /// Focus ring: 3.5 pt Frosted Blue 32% plus a 1 pt inner border at 70%.
    static let focusGlow = Color(dark: 0x92DCE5, light: 0x000000, opacity: 0.32)
    static let focusBorder = Color(dark: 0x92DCE5, light: 0x000000, opacity: 0.70)
    /// Hover and raised rows.
    static let hoverFill = Color(dark: 0xEEE5E9, light: 0x000000, opacity: 0.06)
    /// Severity tiles: warning Tangerine 15%, info Frosted Blue 13%.
    static let warningTint = Color(dark: 0xD64933, light: 0xB83A26, opacity: 0.15)
    static let infoTint = Color(dark: 0x92DCE5, light: 0x000000, opacity: 0.13)

    // MARK: Type (BRAND.md "Type": SF Pro for UI, Sora for brand, SF Mono for ledger details)

    static let windowTitle = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let rowTitle = Font.system(size: 12.5, weight: .medium)
    static let caption = Font.system(size: 11.5)
    static let captionSmall = Font.system(size: 11)
    static let sectionLabel = Font.system(size: 10.5, weight: .semibold)
    static let sectionTracking: CGFloat = 10.5 * 0.12
    static let mono = Font.system(size: 11.5, design: .monospaced)
    static let statNumber = Font.system(size: 28, weight: .regular)
    static let detailTitle = Font.system(size: 24, weight: .medium)
    static let avatarLetter = Font.system(size: 11, weight: .semibold)

    /// Sora Medium, only for the wordmark, onboarding headlines and empty-state titles.
    static func brand(_ size: CGFloat) -> Font { .custom("Sora", size: size).weight(.medium) }

    // MARK: Sizes and radii (BRAND.md "Components")

    static let popoverWidth: CGFloat = 368
    static let popoverRadius: CGFloat = 14
    static let searchHeight: CGFloat = 32
    static let searchRadius: CGFloat = 9
    static let popoverRowHeight: CGFloat = 48
    static let popoverRowRadius: CGFloat = 9
    static let sidebarWidth: CGFloat = 236
    static let toolbarHeight: CGFloat = 54
    static let inspectorWidth: CGFloat = 328
    static let tableRowHeight: CGFloat = 44
    static let tableRowRadius: CGFloat = 8   // radius-sm
    static let cardRadius: CGFloat = 14      // radius-md
    static let buttonHeight: CGFloat = 28
    static let buttonRadius: CGFloat = 7
    static let chipHeight: CGFloat = 20
    static let chipRadius: CGFloat = 6
    static let confidenceDot: CGFloat = 8
    static let space2: CGFloat = 8
    static let space4: CGFloat = 16
    static let space6: CGFloat = 24

    /// Registers the bundled Sora font. Called once at launch.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "Sora-Variable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Color {
    /// A colour that follows the system appearance: dark value in Dark Mode, light value otherwise.
    init(dark: UInt32, light: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: opacity)
        })
    }
}
