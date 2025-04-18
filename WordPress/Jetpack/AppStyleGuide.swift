import Foundation
import WordPressShared
import Gridicons

/// - Warning:
/// This configuration struct has a **WordPress** counterpart in the WordPress bundle.
/// Make sure to keep them in sync to avoid build errors when building the WordPress target.
struct AppStyleGuide {
    static let navigationBarStandardFont: UIFont = Feature.enabled(.serif) ? WPStyleGuide.fixedSerifFontForTextStyle(.headline, fontWeight: .semibold) : WPStyleGuide.fontForTextStyle(.headline, fontWeight: .semibold)
    static let navigationBarLargeFont: UIFont = Feature.enabled(.serif) ? WPStyleGuide.fixedSerifFontForTextStyle(.largeTitle, fontWeight: .semibold) : WPStyleGuide.fontForTextStyle(.largeTitle, fontWeight: .semibold)
    static let epilogueTitleFont: UIFont = Feature.enabled(.serif) ? WPStyleGuide.fixedSerifFontForTextStyle(.largeTitle, fontWeight: .semibold) : WPStyleGuide.fontForTextStyle(.largeTitle, fontWeight: .semibold)
}

// MARK: - Colors
extension AppStyleGuide {
    static let accent = MurielColor(name: .jetpackGreen)
    static let brand = MurielColor(name: .jetpackGreen)
    static let divider = MurielColor(name: .gray, shade: .shade10)
    static let error = MurielColor(name: .red)
    static let gray = MurielColor(name: .gray)
    static let primary = MurielColor(name: .jetpackGreen)
    static let success = MurielColor(name: .green)
    static let text = MurielColor(name: .gray, shade: .shade80)
    static let textSubtle = MurielColor(name: .gray, shade: .shade50)
    static let warning = MurielColor(name: .yellow)
    static let jetpackGreen = MurielColor(name: .jetpackGreen)
    static let editorPrimary = MurielColor(name: .blue)
}

// MARK: - Fonts
extension AppStyleGuide {
    static func prominentFont(textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        WPStyleGuide.fontForTextStyle(textStyle, fontWeight: weight)
    }
}
