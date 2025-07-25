import UIKit
import WordPressData
import WordPressShared
import WordPressUI

@objc public protocol ReaderCardDiscoverAttributionViewDelegate: NSObjectProtocol {
    func attributionActionSelectedForVisitingSite(_ view: ReaderCardDiscoverAttributionView)
}

private enum ReaderCardDiscoverAttribution: Int {

    case none // Default, no action
    case visitSite // Action for verbose attribution to visit a site
}

@objc open class ReaderCardDiscoverAttributionView: UIView, NibLoadable {
    fileprivate let gravatarImageName = "gravatar"
    fileprivate let blavatarImageName = "post-blavatar-placeholder"

    @IBOutlet fileprivate weak var imageView: CircularImageView!
    @IBOutlet fileprivate weak var textLabel: UILabel!

    fileprivate lazy var originalAttributionParagraphAttributes: [NSAttributedString.Key: Any] = {
        return WPStyleGuide.originalAttributionParagraphAttributes()
    }()

    fileprivate var attributionAction: ReaderCardDiscoverAttribution = .none {
        didSet {
            // Enable/disable userInteraction on self if we allow an action.
            self.isUserInteractionEnabled = attributionAction != .none
        }
    }

    @objc weak var delegate: ReaderCardDiscoverAttributionViewDelegate?

    override open var backgroundColor: UIColor? {
        didSet {
            applyOpaqueBackgroundColors()
        }
    }

    var displayAsLink = false

    // MARK: - Lifecycle Methods

    open override func awakeFromNib() {
        super.awakeFromNib()

        // Add a tap gesture for detecting a tap on the label and acting on the current attributionAction.
        //// Ideally this would have independent tappable links but this adds a bit of overrhead for text/link detection
        //// on a UILabel. We might consider migrating to somethnig lik TTTAttributedLabel for more discrete link
        //// detection via UILabel.
        //// Also, rather than detecting a tap on the whole view, we add it to the label and imageView specifically,
        //// to avoid accepting taps outside of the label's text content, on display.
        //// Brent C. Aug/23/2016
        let selector = #selector(ReaderCardDiscoverAttributionView.textLabelTapGesture(_:))
        let labelTap = UITapGestureRecognizer(target: self, action: selector)
        textLabel.addGestureRecognizer(labelTap)

        // Also add a tap recognizer on the imageView.
        let imageTap = UITapGestureRecognizer(target: self, action: selector)
        imageView.addGestureRecognizer(imageTap)

        // Enable userInteraction on the label/imageView by default while userInteraction
        // is toggled on self in attributionAction: didSet for valid actions.
        textLabel.isUserInteractionEnabled = true
        imageView.isUserInteractionEnabled = true

        backgroundColor = .secondarySystemGroupedBackground
        applyOpaqueBackgroundColors()
    }

    // MARK: - Configuration

    /**
     Applies opaque backgroundColors to all subViews to avoid blending, for optimized drawing.
     */
    fileprivate func applyOpaqueBackgroundColors() {
        imageView?.backgroundColor = backgroundColor
        textLabel?.backgroundColor = backgroundColor
    }

    @objc open func configureView(_ post: ReaderPost?) {
        if post?.sourceAttributionStyle() == SourceAttributionStyle.post {
            configurePostAttribution(post!)
        } else if post?.sourceAttributionStyle() == SourceAttributionStyle.site {
            configureSiteAttribution(post!, verboseAttribution: false)
        } else {
            reset()
        }
    }

    @objc open func configureViewWithVerboseSiteAttribution(_ post: ReaderPost?) {
        if let post {
            configureSiteAttribution(post, verboseAttribution: true)
        } else {
            reset()
        }
    }

    fileprivate func reset() {
        imageView.image = nil
        textLabel.attributedText = nil
        attributionAction = .none
    }

    fileprivate func configurePostAttribution(_ post: ReaderPost) {
        let url = post.sourceAvatarURLForDisplay()
        let placeholder = UIImage(named: gravatarImageName)
        imageView.downloadImage(from: url, placeholderImage: placeholder)
        imageView.shouldRoundCorners = true

        let str = stringForPostAttribution(post.sourceAuthorNameForDisplay(),
                                            blogName: post.sourceBlogNameForDisplay())
        let attributes = originalAttributionParagraphAttributes
        textLabel.attributedText = NSAttributedString(string: str, attributes: attributes)
        attributionAction = .none
    }

    fileprivate func configureSiteAttribution(_ post: ReaderPost, verboseAttribution verbose: Bool) {
        let url = post.sourceAvatarURLForDisplay()
        let placeholder = UIImage(named: blavatarImageName)
        imageView.downloadImage(from: url, placeholderImage: placeholder)
        imageView.shouldRoundCorners = false

        let blogName = post.sourceBlogNameForDisplay()
        let pattern = patternForSiteAttribution(verbose)
        let str = String(format: pattern, blogName!)

        let range = (str as NSString).range(of: blogName!)
        let font = WPStyleGuide.fontForTextStyle(WPStyleGuide.originalAttributionTextStyle(), symbolicTraits: .traitItalic)
        let attributes = originalAttributionParagraphAttributes
        let attributedString = NSMutableAttributedString(string: str, attributes: attributes)
        attributedString.addAttribute(.font, value: font, range: range)
        if !displayAsLink {
            WPStyleGuide.applyReaderCardAttributionLabelStyle(textLabel)
        } else {
            textLabel.textColor = UIAppColor.primary
//            textLabel.highlightedtextColor = UIAppColor.primary
        }
        textLabel.attributedText = attributedString
        attributionAction = .visitSite
    }

    fileprivate func stringForPostAttribution(_ authorName: String?, blogName: String?) -> String {
        var str = ""
        if (authorName != nil) && (blogName != nil) {
            let pattern = NSLocalizedString("Originally posted by %@ on %@",
                comment: "Used to attribute a post back to its original author and blog.  The '%@' characters are placholders for the author's name, and the author's blog repsectively.")
            str = String(format: pattern, authorName!, blogName!)

        } else if authorName != nil {
            let pattern = NSLocalizedString("Originally posted by %@",
                comment: "Used to attribute a post back to its original author.  The '%@' characters are a placholder for the author's name.")
            str = String(format: pattern, authorName!)

        } else if blogName != nil {
            let pattern = NSLocalizedString("Originally posted on %@",
                comment: "Used to attribute a post back to its original blog.  The '%@' characters are a placholder for the blog name.")
            str = String(format: pattern, blogName!)
        }
        return str
    }

    fileprivate func patternForSiteAttribution(_ verbose: Bool) -> String {
        var pattern: String
        if verbose {
            pattern = NSLocalizedString("Visit %@ for more", comment: "A call to action to visit the specified blog.  The '%@' characters are a placholder for the blog name.")
        } else {
            pattern = NSLocalizedString("Visit %@", comment: "A call to action to visit the specified blog.  The '%@' characters are a placholder for the blog name.")
        }
        return pattern
    }

    // MARK: - Touches

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Add highlight if the touch begins inside of the textLabel's frame
        guard let touch: UITouch = event?.allTouches?.first else {
            return
        }
        if textLabel.bounds.contains(touch.location(in: textLabel)) {
            textLabel.isHighlighted = true
        }
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        // Remove highlight if the touch moves outside of the textLabel's frame
        guard textLabel.isHighlighted else {
            return
        }
        guard let touch: UITouch = event?.allTouches?.first else {
            return
        }
        if !textLabel.bounds.contains(touch.location(in: textLabel)) {
            textLabel.isHighlighted = false
        }
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard textLabel.isHighlighted else {
            return
        }
        textLabel.isHighlighted = false
    }

    open override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches!, with: event)
        guard textLabel.isHighlighted else {
            return
        }
        textLabel.isHighlighted = false
    }

    // MARK: - Actions

    @objc open func textLabelTapGesture(_ gesture: UITapGestureRecognizer) {
        switch attributionAction {
        case .visitSite:
            delegate?.attributionActionSelectedForVisitingSite(self)
        default: break
        }
    }
}
