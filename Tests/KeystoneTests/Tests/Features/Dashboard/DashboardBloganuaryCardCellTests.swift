import XCTest
@testable import WordPress
@testable import WordPressData

final class DashboardBloganuaryCardCellTests: CoreDataTestCase {

    private static var calendar = {
        Calendar(identifier: .gregorian)
    }()
    private let blogID = 100
    private let featureFlags = FeatureFlagOverrideStore()

    override func setUp() {
        super.setUp()
        featureFlags.override(RemoteFeatureFlag.bloganuaryDashboardNudge, withValue: true)
    }

    override func tearDown() {
        super.tearDown()
        featureFlags.override(RemoteFeatureFlag.bloganuaryDashboardNudge, withValue: RemoteFeatureFlag.bloganuaryDashboardNudge.defaultValue)
    }

    // MARK: - `shouldShowCard` tests

    func testCardIsNotShownWhenFlagIsDisabled() throws {
        // Given
        let blog = makeBlog()
        makeBloggingPromptSettings()
        try mainContext.save()
        featureFlags.override(RemoteFeatureFlag.bloganuaryDashboardNudge, withValue: false)

        // When
        let result = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInDecember)

        // Then
        XCTAssertFalse(result)
    }

    func testCardIsNotShownWhenSiteIsNotMarkedAsBloggingSite() throws {
        // Given
        let blog = makeBlog()
        makeBloggingPromptSettings(markAsBloggingSite: false)
        try mainContext.save()

        // When
        let result = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInDecember)

        // Then
        XCTAssertFalse(result)
    }

    func testCardIsNotShownForEligibleSitesOutsideEligibleMonths() throws {
        // Given
        let blog = makeBlog()
        makeBloggingPromptSettings()
        try mainContext.save()

        // When
        let result = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInFebruary)

        // Then
        XCTAssertFalse(result)
    }

    func testCardIsShownWhenSiteIsEligible() throws {
        // Given
        let blog = makeBlog()
        makeBloggingPromptSettings()
        try mainContext.save()

        // When
        let resultForDecember = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInDecember)
        let resultForJanuary = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInJanuary)

        // Then
        XCTAssertTrue(resultForDecember)
        XCTAssertTrue(resultForJanuary)
    }

    func testCardIsShownForEligibleSitesThatHavePromptsDisabled() throws {
        // Given
        let blog = makeBlog()
        makeBloggingPromptSettings(promptCardEnabled: false)
        try mainContext.save()

        // When
        let result = DashboardBloganuaryCardCell.shouldShowCard(for: blog, date: sometimeInDecember)

        // Then
        XCTAssertTrue(result)
    }
}

// MARK: - Helpers

private extension DashboardBloganuaryCardCellTests {

    var sometimeInDecember: Date {
        let date = Date()
        var components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        components.month = 12
        components.year = 2023
        components.day = 10

        return Self.calendar.date(from: components) ?? date
    }

    var sometimeInJanuary: Date {
        let date = Date()
        var components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        components.month = 1
        components.year = 2024
        components.day = 10

        return Self.calendar.date(from: components) ?? date
    }

    var sometimeInFebruary: Date {
        let date = Date()
        var components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        components.month = 2
        components.year = 2024
        components.day = 10

        return Self.calendar.date(from: components) ?? date
    }

    func prepareData() -> (Blog, BloggingPromptSettings) {
        return (makeBlog(), makeBloggingPromptSettings())
    }

    func makeBlog() -> Blog {
        let builder = BlogBuilder(mainContext)
            .withAnAccount()
            .with(dotComID: blogID)

        return builder.build()
    }

    @discardableResult
    func makeBloggingPromptSettings(markAsBloggingSite: Bool = true, promptCardEnabled: Bool = true) -> BloggingPromptSettings {
        let settings = NSEntityDescription.insertNewObject(forEntityName: BloggingPromptSettings.entityName(),
                                                           into: mainContext) as! WordPress.BloggingPromptSettings

        let reminderDays = NSEntityDescription.insertNewObject(forEntityName: BloggingPromptSettingsReminderDays.entityName(),
                                                               into: mainContext) as! WordPress.BloggingPromptSettingsReminderDays
        reminderDays.monday = false
        reminderDays.tuesday = false
        reminderDays.wednesday = false
        reminderDays.thursday = false
        reminderDays.friday = false
        reminderDays.saturday = false
        reminderDays.sunday = false

        settings.isPotentialBloggingSite = markAsBloggingSite
        settings.promptCardEnabled = promptCardEnabled
        settings.reminderDays = reminderDays
        settings.siteID = Int32(blogID)

        return settings
    }
}
