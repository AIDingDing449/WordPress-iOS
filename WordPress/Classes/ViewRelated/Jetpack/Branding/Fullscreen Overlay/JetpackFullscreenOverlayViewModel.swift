import UIKit

typealias JetpackOverlayDismissCallback = () -> Void

/// Protocol used to configure `JetpackFullscreenOverlayViewController`
protocol JetpackFullscreenOverlayViewModel: AnyObject {
    var title: String { get }
    var subtitle: NSAttributedString { get }
    var animationLtr: String { get }
    var animationRtl: String { get }
    var footnote: String? { get }
    var learnMoreButtonURL: String? { get }
    var switchButtonText: String { get }
    var continueButtonText: String? { get }
    var shouldShowCloseButton: Bool { get }
    var shouldDismissOnSecondaryButtonTap: Bool { get }
    var analyticsSource: String { get }
    var actionInfoText: NSAttributedString? { get }
    var onWillDismiss: JetpackOverlayDismissCallback? { get }
    var onDidDismiss: JetpackOverlayDismissCallback? { get }

    /// An optional view.
    /// If provided, the view will be added to the overlay before the learn more button
    var secondaryView: UIView? { get }

    /// If `true`, the overlay uses tighter spacings between subviews.
    /// Useful for packed overlays.
    var isCompact: Bool { get }

    func didDisplayOverlay()
    func didTapLink()
    func didTapPrimary()
    func didTapClose()
    func didTapSecondary()
    func didTapActionInfo()
}

extension JetpackFullscreenOverlayViewModel {
    var learnMoreButtonIsHidden: Bool {
        learnMoreButtonURL == nil
    }

    var footnoteIsHidden: Bool {
        footnote == nil
    }

    var continueButtonIsHidden: Bool {
        continueButtonText == nil
    }
}
