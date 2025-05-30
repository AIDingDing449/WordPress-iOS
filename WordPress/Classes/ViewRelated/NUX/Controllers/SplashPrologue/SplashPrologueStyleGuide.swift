import UIKit
import SwiftUI
import WordPressAuthenticator
import WordPressUI

struct SplashPrologueStyleGuide {
    static let backgroundColor = UIColor(light: .colorFromHex("F6F7F7"), dark: .colorFromHex("2C3338"))

    struct Title {
        static let font = Font.system(size: 25, weight: .regular, design: .serif)
        static let textColor = UIColor(light: .colorFromHex("101517"), dark: .white)
    }

    struct BrushStroke {
        static let color = UIColor(light: .colorFromHex("BBE0FA"), dark: .colorFromHex("101517")).withAlphaComponent(0.3)
    }

    /// Use the same shade for light and dark modes
    private static let primaryButtonColor: UIColor = UIAppColor.primary
        .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    private static let primaryButtonHighlightedColor: UIColor = UIAppColor.primary(.shade60)
        .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))

    private static let secondaryButtonColor: UIColor = .white
    private static let secondaryButtonHighlightedColor: UIColor = UIAppColor.gray(.shade5)

    static let primaryButtonStyle = NUXButtonStyle(
        normal: .init(backgroundColor: Self.primaryButtonColor,
                      borderColor: Self.primaryButtonColor,
                      titleColor: .white),

        highlighted: .init(backgroundColor: Self.primaryButtonHighlightedColor,
                           borderColor: Self.primaryButtonHighlightedColor,
                           titleColor: .white),

        disabled: .init(backgroundColor: .white,
                       borderColor: .white,
                       titleColor: Self.backgroundColor))

    static let secondaryButtonStyle = NUXButtonStyle(
        normal: .init(backgroundColor: Self.secondaryButtonColor,
                      borderColor: Self.secondaryButtonHighlightedColor,
                      titleColor: .black),

        highlighted: .init(backgroundColor: Self.secondaryButtonHighlightedColor,
                           borderColor: Self.secondaryButtonHighlightedColor,
                           titleColor: .black),

        disabled: .init(backgroundColor: .white,
                        borderColor: .white,
                        titleColor: Self.backgroundColor))
}
