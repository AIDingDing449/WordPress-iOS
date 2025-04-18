extension UIColor {
    /// Get a UIColor from the Muriel color palette
    ///
    /// - Parameters:
    ///   - color: an instance of a MurielColor
    /// - Returns: UIColor. Red in cases of error
    class func muriel(color murielColor: MurielColor) -> UIColor {
        let assetName = murielColor.assetName()
        let color = UIColor(named: assetName)

        guard let unwrappedColor = color else {
            return .red
        }

        return unwrappedColor
    }
    /// Get a UIColor from the Muriel color palette, adjusted to a given shade
    /// - Parameter color: an instance of a MurielColor
    /// - Parameter shade: a MurielColorShade
    class func muriel(color: MurielColor, _ shade: MurielColorShade) -> UIColor {
        let newColor = MurielColor(from: color, shade: shade)
        return muriel(color: newColor)
    }

    /// Get a UIColor from the Muriel color palette by name, adjusted to a given shade
    /// - Parameters:
    ///   - name: a MurielColorName
    ///   - shade: a MurielColorShade
    /// - Returns: the desired color/shade
    class func muriel(name: MurielColorName, _ shade: MurielColorShade) -> UIColor {
        let newColor = MurielColor(name: name, shade: shade)
        return muriel(color: newColor)
    }
}
// MARK: - Basic Colors
extension UIColor {
    /// Muriel accent color
    static var accent = muriel(color: .accent)
    static var accentDark = muriel(color: .accent, .shade70)
    class func accent(_ shade: MurielColorShade) -> UIColor {
        return muriel(color: .accent, shade)
    }

    /// Muriel brand color
    static var brand = muriel(color: .brand)

    /// Muriel error color
    static var error = muriel(color: .error)
    class func error(_ shade: MurielColorShade) -> UIColor {
        return muriel(color: .error, shade)
    }

    /// Muriel primary color
    static var primary = muriel(color: .primary)
    static var primaryLight = muriel(color: .primary, .shade30)
    static var primaryDark = muriel(color: .primary, .shade70)
    class func primary(_ shade: MurielColorShade) -> UIColor {
        return muriel(color: .primary, shade)
    }

    /// Muriel editor primary color
    static var editorPrimary = muriel(color: .editorPrimary)

    /// Muriel success color
    static var success = muriel(color: .success)

    /// Muriel warning color
    static var warning = muriel(color: .warning)
    class func warning(_ shade: MurielColorShade) -> UIColor {
        return muriel(color: .warning, shade)
    }

    /// Muriel jetpack green color
    static var jetpackGreen = muriel(color: .jetpackGreen)
}

// MARK: - Grays
extension UIColor {
    /// Muriel gray palette
    /// - Parameter shade: a MurielColorShade of the desired shade of gray
    class func gray(_ shade: MurielColorShade) -> UIColor {
        return muriel(color: .gray, shade)
    }

    /// Muriel neutral colors, which invert in dark mode
    /// - Parameter shade: a MurielColorShade of the desired neutral shade
    static var neutral: UIColor {
        return neutral(.shade50)
    }
    class func neutral(_ shade: MurielColorShade) -> UIColor {
        switch shade {
        case .shade0:
            return UIColor(light: muriel(color: .gray, .shade0), dark: muriel(color: .gray, .shade100))
            case .shade5:
            return UIColor(light: muriel(color: .gray, .shade5), dark: muriel(color: .gray, .shade90))
            case .shade10:
            return UIColor(light: muriel(color: .gray, .shade10), dark: muriel(color: .gray, .shade80))
            case .shade20:
            return UIColor(light: muriel(color: .gray, .shade20), dark: muriel(color: .gray, .shade70))
            case .shade30:
            return UIColor(light: muriel(color: .gray, .shade30), dark: muriel(color: .gray, .shade60))
            case .shade40:
            return UIColor(light: muriel(color: .gray, .shade40), dark: muriel(color: .gray, .shade50))
            case .shade50:
            return UIColor(light: muriel(color: .gray, .shade50), dark: muriel(color: .gray, .shade40))
            case .shade60:
            return UIColor(light: muriel(color: .gray, .shade60), dark: muriel(color: .gray, .shade30))
            case .shade70:
            return UIColor(light: muriel(color: .gray, .shade70), dark: muriel(color: .gray, .shade20))
            case .shade80:
            return UIColor(light: muriel(color: .gray, .shade80), dark: muriel(color: .gray, .shade10))
            case .shade90:
            return UIColor(light: muriel(color: .gray, .shade90), dark: muriel(color: .gray, .shade5))
            case .shade100:
            return UIColor(light: muriel(color: .gray, .shade100), dark: muriel(color: .gray, .shade0))
        }
    }
}

// MARK: - UI elements
extension UIColor {
    /// The most basic background: white in light mode, black in dark mode
    static var basicBackground: UIColor {
        return .systemBackground
    }

    /// Default text color: high contrast
    static var text: UIColor {
        return .label
    }

    /// Secondary text color: less contrast
    static var textSubtle: UIColor {
        return .secondaryLabel
    }

    /// Very low contrast text
    static var textTertiary: UIColor {
        return .tertiaryLabel
    }

    /// Very, very low contrast text
    static var textQuaternary: UIColor {
        return .quaternaryLabel
    }

    static var textInverted = UIColor(light: .white, dark: .gray(.shade100))
    static var textPlaceholder: UIColor {
        return .tertiaryLabel
    }
    static var placeholderElement: UIColor {
        return UIColor(light: .systemGray5, dark: .systemGray4)
    }

    static var placeholderElementFaded: UIColor {
        return UIColor(light: .systemGray6, dark: .systemGray5)
    }

    // MARK: - Table Views

    static var divider: UIColor {
        return .separator
    }

    /// WP color for table foregrounds (cells, etc)
    static var listForeground: UIColor {
        return .secondarySystemGroupedBackground
    }

    static var listBackground: UIColor {
        return .systemGroupedBackground
    }

    /// For icons that are present in a table view, or similar list
    static var listIcon: UIColor {
        return .secondaryLabel
    }

    /// For small icons, such as the badges on notification gravatars
    static var listSmallIcon: UIColor {
        return .systemGray
    }

    // MARK: - Others

    static var prologueBackground: UIColor {
        return UIColor(light: muriel(color: MurielColor(name: .blue, shade: .shade0)), dark: .systemBackground)
    }
}

@objc
extension UIColor {
    // A way to create dynamic colors that's compatible with iOS 11 & 12
    @objc
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return dark
            } else {
                return light
            }
        }
    }

    convenience init(color: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIColor {
    func color(for trait: UITraitCollection?) -> UIColor {
        if let trait = trait {
            return resolvedColor(with: trait)
        }
        return self
    }

    func lightVariant() -> UIColor {
        return color(for: UITraitCollection(userInterfaceStyle: .light))
    }

    func darkVariant() -> UIColor {
        return color(for: UITraitCollection(userInterfaceStyle: .dark))
    }
}
