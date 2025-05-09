import UIKit
import WordPressShared

@IBDesignable
class RoundedButton: UIButton {

    @IBInspectable var isCircular: Bool = false

    @IBInspectable var cornerRadius: CGFloat = 4.0 {
        didSet {
            updateAppearance()
        }
    }

    @IBInspectable var borderWidth: CGFloat = 0.0 {
        didSet {
            updateAppearance()
        }
    }

    @IBInspectable var borderColor: UIColor? = nil {
        didSet {
            updateAppearance()
        }
    }

    @IBInspectable var horizontalEdgeInset: CGFloat = 19.0 {
        didSet {
            updateAppearance()
        }
    }

    @IBInspectable var verticalEdgeInset: CGFloat = 5.0 {
        didSet {
            updateAppearance()
        }
    }

    @IBInspectable var selectedBackgroundColor: UIColor? {
        didSet {
            updateAppearance()
        }
    }

    override var reversesTitleShadowWhenHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        updateAppearance()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        updateAppearance()
    }

    fileprivate func updateAppearance() {
        contentEdgeInsets = UIEdgeInsets(top: verticalEdgeInset, left: horizontalEdgeInset, bottom: verticalEdgeInset, right: horizontalEdgeInset)

        layer.masksToBounds = true
        if !isCircular {
            layer.cornerRadius = cornerRadius
        }
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor?.cgColor ?? tintColor.cgColor

        setTitleColor(tintColor, for: UIControl.State())
        setBackgroundImage(UIImage(color: tintColor), for: .highlighted)

        if reversesTitleShadowWhenHighlighted {
            setTitleColor(backgroundColor, for: [.highlighted])
            setBackgroundImage(UIImage(color: tintColor), for: .highlighted)
        } else {
            setTitleColor(tintColor.withAlphaComponent(0.5), for: .highlighted)
            setBackgroundImage(UIImage(color: selectedBackgroundColor ?? backgroundColor ?? .clear), for: .highlighted)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isCircular {
            layer.cornerRadius = frame.size.width / 2
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateFontSizeToMatchSystem()
        }
    }

    public func updateFontSizeToMatchSystem() {
        titleLabel?.font = WPStyleGuide.fontForTextStyle(.subheadline)
    }
}
