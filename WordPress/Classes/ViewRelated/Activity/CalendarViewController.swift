import UIKit
import WordPressUI

protocol CalendarViewControllerDelegate: AnyObject {
    func didCancel(calendar: CalendarViewController)
    func didSelect(calendar: CalendarViewController, startDate: Date?, endDate: Date?)
}

class CalendarViewController: UIViewController {

    private var calendarCollectionView: CalendarCollectionView!
    private var startDateLabel: UILabel!
    private var separatorDateLabel: UILabel!
    private var endDateLabel: UILabel!
    private var header: UIStackView!
    private let gradient = GradientView()

    private var startDate: Date?
    private var endDate: Date?

    weak var delegate: CalendarViewControllerDelegate?

    private lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter
    }()

    private enum Constants {
        static let headerPadding: CGFloat = 16
        static let endDateLabel = NSLocalizedString("End Date", comment: "Placeholder for the end date in calendar range selection")
        static let startDateLabel = NSLocalizedString("Start Date", comment: "Placeholder for the start date in calendar range selection")
        static let rangeSummaryAccessibilityLabel = NSLocalizedString(
            "Selected range: %1$@ to %2$@",
            comment: "Accessibility label for summary of currently selected range. %1$@ is the start date, %2$@ is " +
            "the end date.")
        static let singleDateRangeSummaryAccessibilityLabel = NSLocalizedString(
            "Selected range: %1$@ only",
            comment: "Accessibility label for summary of currently single date. %1$@ is the date")
        static let noRangeSelectedAccessibilityLabelPlaceholder = NSLocalizedString(
            "No date range selected",
            comment: "Accessibility label for no currently selected range.")
    }

    /// Creates a full screen year calendar controller
    ///
    /// - Parameters:
    ///   - startDate: An optional Date representing the first selected date
    ///   - endDate: An optional Date representing the end selected date
    init(startDate: Date? = nil, endDate: Date? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Choose date range", comment: "Title to choose date range in a calendar")

        // Configure Calendar
        let calendar = Calendar.current
        self.calendarCollectionView = CalendarCollectionView(
            calendar: calendar,
            style: .year,
            startDate: startDate,
            endDate: endDate
        )

        // Configure headers and add the calendar to the view
        configureHeader()
        let stackView = UIStackView(arrangedSubviews: [
                                            header,
                                            calendarCollectionView
        ])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.setCustomSpacing(Constants.headerPadding, after: header)
        view.addSubview(stackView)
        view.pinSubviewToAllEdges(stackView, insets: UIEdgeInsets(top: Constants.headerPadding, left: 0, bottom: 0, right: 0))
        view.backgroundColor = .systemBackground
        edgesForExtendedLayout = []

        setupNavButtons()

        setUpGradient()

        calendarCollectionView.calDataSource.didSelect = { [weak self] startDate, endDate in
            self?.updateDates(startDate: startDate, endDate: endDate)
        }

        calendarCollectionView.scrollsToTop = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        scrollToVisibleDate()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.calendarCollectionView.reloadData(withAnchor: self.startDate ?? Date(), completionHandler: nil)
        }, completion: nil)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        setUpGradientColors()
    }

    private func setupNavButtons() {
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Label for Done button"), style: .done, target: self, action: #selector(done))
        navigationItem.setRightBarButton(doneButton, animated: false)

        navigationItem.setLeftBarButton(UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)), animated: false)
    }

    private func updateDates(startDate: Date?, endDate: Date?) {
        self.startDate = startDate
        self.endDate = endDate

        updateLabels()
    }

    private func updateLabels() {
        guard let startDate else {
            resetLabels()
            return
        }

        startDateLabel.text = formatter.string(from: startDate)
        startDateLabel.textColor = .label
        startDateLabel.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)

        if let endDate {
            endDateLabel.text = formatter.string(from: endDate)
            endDateLabel.textColor = .label
            endDateLabel.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
            separatorDateLabel.textColor = .label
            separatorDateLabel.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
        } else {
            endDateLabel.text = Constants.endDateLabel
            endDateLabel.font = WPStyleGuide.fontForTextStyle(.title3)
            endDateLabel.textColor = .secondaryLabel
            separatorDateLabel.textColor = .secondaryLabel
        }

        header.accessibilityLabel = accessibilityLabelForRangeSummary(startDate: startDate, endDate: endDate)
    }

    private func configureHeader() {
        header = startEndDateHeader()
        resetLabels()
    }

    private func startEndDateHeader() -> UIStackView {
        let header = UIStackView(frame: .zero)
        header.distribution = .fill

        let startDate = UILabel()
        startDate.isAccessibilityElement = false
        startDateLabel = startDate
        startDate.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
        if view.effectiveUserInterfaceLayoutDirection == .leftToRight {
            // swiftlint:disable:next inverse_text_alignment
            startDate.textAlignment = .right
        } else {
            // swiftlint:disable:next natural_text_alignment
            startDate.textAlignment = .left
        }
        header.addArrangedSubview(startDate)
        startDate.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.47).isActive = true

        let separator = UILabel()
        separator.isAccessibilityElement = false
        separatorDateLabel = separator
        separator.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
        separator.textAlignment = .center
        header.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.06).isActive = true

        let endDate = UILabel()
        endDate.isAccessibilityElement = false
        endDateLabel = endDate
        endDate.font = WPStyleGuide.fontForTextStyle(.title3, fontWeight: .semibold)
        if view.effectiveUserInterfaceLayoutDirection == .leftToRight {
            // swiftlint:disable:next natural_text_alignment
            endDate.textAlignment = .left
        } else {
            // swiftlint:disable:next inverse_text_alignment
            endDate.textAlignment = .right
        }
        header.addArrangedSubview(endDate)
        endDate.widthAnchor.constraint(equalTo: header.widthAnchor, multiplier: 0.47).isActive = true

        header.isAccessibilityElement = true
        header.accessibilityTraits = [.header, .summaryElement]

        return header
    }

    private func scrollToVisibleDate() {
        if calendarCollectionView.frame.height == 0 {
            calendarCollectionView.superview?.layoutIfNeeded()
        }

        if let startDate {
            calendarCollectionView.scrollToDate(startDate,
                                                animateScroll: true,
                                                preferredScrollPosition: .centeredVertically,
                                                extraAddedOffset: -(self.calendarCollectionView.frame.height / 2))
        } else {
            calendarCollectionView.setContentOffset(CGPoint(
                                                        x: 0,
                                                        y: calendarCollectionView.contentSize.height - calendarCollectionView.frame.size.height
            ), animated: false)
        }

    }

    private func resetLabels() {
        startDateLabel.text = Constants.startDateLabel

        separatorDateLabel.text = "-"

        endDateLabel.text = Constants.endDateLabel

        [startDateLabel, separatorDateLabel, endDateLabel].forEach { label in
            label?.textColor = .secondaryLabel
            label?.font = WPStyleGuide.fontForTextStyle(.title3)
        }

        header.accessibilityLabel = accessibilityLabelForRangeSummary(startDate: nil, endDate: nil)
    }

    private func accessibilityLabelForRangeSummary(startDate: Date?, endDate: Date?) -> String {
        switch (startDate, endDate) {
        case (nil, _):
            return Constants.noRangeSelectedAccessibilityLabelPlaceholder
        case (.some(let startDate), nil):
            let startDateString = formatter.string(from: startDate)
            return String.localizedStringWithFormat(Constants.singleDateRangeSummaryAccessibilityLabel, startDateString)
        case (.some(let startDate), .some(let endDate)):
            let startDateString = formatter.string(from: startDate)
            let endDateString = formatter.string(from: endDate)
            return String.localizedStringWithFormat(Constants.rangeSummaryAccessibilityLabel, startDateString, endDateString)
        }
    }

    private func setUpGradient() {
        gradient.isUserInteractionEnabled = false
        gradient.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradient)

        NSLayoutConstraint.activate([
            gradient.heightAnchor.constraint(equalToConstant: 50),
            gradient.topAnchor.constraint(equalTo: calendarCollectionView.topAnchor),
            gradient.leadingAnchor.constraint(equalTo: calendarCollectionView.leadingAnchor),
            gradient.trailingAnchor.constraint(equalTo: calendarCollectionView.trailingAnchor)
        ])

        setUpGradientColors()
    }

    private func setUpGradientColors() {
        gradient.fromColor = .systemBackground
        gradient.toColor = UIColor.systemBackground.withAlphaComponent(0)
    }

    @objc private func done() {
        delegate?.didSelect(calendar: self, startDate: startDate, endDate: endDate)
    }

    @objc private func cancel() {
        delegate?.didCancel(calendar: self)
    }
}
