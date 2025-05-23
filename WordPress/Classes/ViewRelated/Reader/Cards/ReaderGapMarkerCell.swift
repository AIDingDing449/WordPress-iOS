import UIKit
import WordPressShared
import WordPressUI

open class ReaderGapMarkerCell: UITableViewCell, NibLoadable {
    @IBOutlet fileprivate weak var tearBackgroundView: UIView!
    @IBOutlet fileprivate weak var tearMaskView: UIView!
    @IBOutlet fileprivate weak var activityViewBackgroundView: UIView!
    @IBOutlet fileprivate weak var activityView: UIActivityIndicatorView!
    @IBOutlet fileprivate weak var button: UIButton!

    open override func awakeFromNib() {
        super.awakeFromNib()
        applyStyles()
    }

    fileprivate func applyStyles() {
        // Background styles
        contentView.backgroundColor = .systemGroupedBackground
        selectedBackgroundView = UIView(frame: contentView.frame)
        selectedBackgroundView?.backgroundColor = .systemGroupedBackground
        contentView.backgroundColor = .systemGroupedBackground
        tearMaskView.backgroundColor = .systemGroupedBackground

        // Draw the tear
        drawTearBackground()

        activityViewBackgroundView.backgroundColor = UIAppColor.neutral(.shade40)
        activityViewBackgroundView.layer.cornerRadius = 4.0
        activityViewBackgroundView.layer.masksToBounds = true

        // Button style
        WPStyleGuide.applyGapMarkerButtonStyle(button)
        let text = NSLocalizedString("Load more posts", comment: "A short label.  A call to action to load more posts.")
        button.setTitle(text, for: UIControl.State())
        button.layer.cornerRadius = 4.0
        button.layer.masksToBounds = true

        // Disable button interactions so the full cell handles the tap.
        button.isUserInteractionEnabled = false
    }

    @objc open func animateActivityView(_ animate: Bool) {
        button.alpha = animate ? 0 : 1
        if animate {
            activityView.startAnimating()
        } else {
            activityView.stopAnimating()
        }
    }

    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        button.isHighlighted = highlighted
        button.backgroundColor = highlighted ? WPStyleGuide.gapMarkerButtonBackgroundColorHighlighted() : WPStyleGuide.gapMarkerButtonBackgroundColor()
        if highlighted {
            // Redraw the backgrounds when highlighted
            drawTearBackground()
            tearMaskView.backgroundColor = .systemGroupedBackground
        }
    }

    @objc func drawTearBackground() {
        let tearImage = UIImage(named: "background-reader-tear")
        tearBackgroundView.backgroundColor = UIColor(patternImage: tearImage!)
    }
}
