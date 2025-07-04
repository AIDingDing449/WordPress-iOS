import UIKit
import WordPressData
import WordPressShared

class StatsBaseCell: UITableViewCell {

    let headingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.adjustsFontForContentSizeCategory = true
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        return label
    }()

    private lazy var showDetailsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.forward")
        configuration.buttonSize = .small
        configuration.imagePadding = 4
        configuration.baseForegroundColor = .secondaryLabel
        configuration.imagePlacement = .trailing
        configuration.titleLineBreakMode = .byTruncatingTail

        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = true
        button.addTarget(self, action: #selector(detailsButtonTapped), for: .touchUpInside)
        button.accessibilityHint = LocalizedText.buttonAccessibilityHint
        return button
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 8
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        return stackView
    }()

    @IBOutlet var topConstraint: NSLayoutConstraint?

    private var headingBottomConstraint: NSLayoutConstraint?
    private var headingWidthConstraint: NSLayoutConstraint?

    /// Finds the item from the top constraint that's not the content view itself.
    /// - Returns: `topConstraint`'s `firstItem` or `secondItem`, whichever is not this cell's content view.
    private var topConstraintTargetView: UIView? {
        if let firstItem = topConstraint?.firstItem as? UIView,
           firstItem != contentView {
            return firstItem
        }

        return topConstraint?.secondItem as? UIView
    }

    var statSection: StatSection? {
        didSet {
            updateHeader()
        }
    }

    weak var siteStatsInsightDetailsDelegate: SiteStatsInsightsDelegate? {
        didSet {
            updateHeader()
        }
    }

    private func configureHeading(with topConstraint: NSLayoutConstraint) {
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.padding),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Metrics.padding)
        ])

        stackView.addArrangedSubviews([headingLabel, showDetailsButton])

        headingWidthConstraint = headingLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.55)
        headingWidthConstraint?.isActive = true
        showDetailsButton.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.35).isActive = true

        if let anchor = topConstraintTargetView?.topAnchor {
            // Deactivate the existing top constraint of the cell
            let constant = topConstraint.constant
            topConstraint.isActive = false

            // Create a new constraint between the stackView containing the heading label and the first item of the existing top constraint
            headingBottomConstraint = stackView.bottomAnchor.constraint(equalTo: anchor, constant: -(Metrics.bottomSpacing + constant))
            headingBottomConstraint?.isActive = true
        }
    }

    private func updateHeader() {
        if let topConstraint, headingBottomConstraint == nil && headingLabel.superview == nil {
            configureHeading(with: topConstraint)
        }

        let title = statSection?.title ?? ""
        headingLabel.text = title

        if shouldShowDetailsButton() {
            showDetailsButton.isHidden = false

            switch statSection {
            case .insightsViewsVisitors:
                showDetailsButton.configuration?.title = LocalizedText.buttonTitleThisWeek
            case .insightsFollowerTotals, .insightsCommentsTotals, .insightsLikesTotals:
                showDetailsButton.configuration?.title = LocalizedText.buttonTitleViewMore
            default:
                showDetailsButton.configuration?.title = nil
            }

            headingWidthConstraint?.isActive = true
        } else {
            showDetailsButton.isHidden = true
            headingWidthConstraint?.isActive = false
        }

        let hasTitleOrButton = !title.isEmpty || !showDetailsButton.isHidden

        headingBottomConstraint?.isActive = hasTitleOrButton
        topConstraint?.isActive = !hasTitleOrButton
    }

    func shouldShowDetailsButton () -> Bool {
        return siteStatsInsightDetailsDelegate != nil
    }

    @objc private func detailsButtonTapped() {
        guard let statSection else {
            return
        }

        captureAnalyticsEventsFor(statSection)
        siteStatsInsightDetailsDelegate?.viewMoreSelectedForStatSection?(statSection)
    }

    private func captureAnalyticsEventsFor(_ statSection: StatSection) {
        let legacyEvent: WPAnalyticsStat = .statsViewAllAccessed
        captureAnalyticsEvent(legacyEvent)

        switch statSection {
        case .insightsViewsVisitors, .insightsFollowerTotals, .insightsLikesTotals, .insightsCommentsTotals:
            captureAnalyticsEvent(.statsInsightsViewMore, statSection: statSection)
        default:
            if let modernEvent = statSection.analyticsViewMoreEvent {
                captureAnalyticsEvent(modernEvent)
            }
        }
    }

    private func captureAnalyticsEvent(_ event: WPAnalyticsStat) {
        if let blogIdentifier = SiteStatsInformation.sharedInstance.siteID {
            WPAppAnalytics.track(event, blogID: blogIdentifier)
        } else {
            WPAppAnalytics.track(event)
        }
    }

    private func captureAnalyticsEvent(_ event: WPAnalyticsEvent, statSection: StatSection) {
        let properties: [String: String] = ["type": statSection.analyticsProperty]

        if let blogId = SiteStatsInformation.sharedInstance.siteID,
           let blog = Blog.lookup(withID: blogId, in: ContextManager.shared.mainContext) {
            WPAnalytics.track(event, properties: properties, blog: blog)
        } else {
            WPAnalytics.track(event, properties: properties)
        }
    }

    enum Metrics {
        static let padding: CGFloat = 16
        static let bottomSpacing: CGFloat = 12
    }

    private enum LocalizedText {
        static let buttonTitleThisWeek = NSLocalizedString("Week", comment: "Title of a button. A call to action to view more stats for this week")
        static let buttonTitleViewMore = NSLocalizedString("View more", comment: "Label for viewing more stats.")
        static let buttonAccessibilityHint = NSLocalizedString("Tap to view more stats for this week", comment: "VoiceOver accessibility hint, informing the user the button can be used to access more stats about this week")
    }
}
