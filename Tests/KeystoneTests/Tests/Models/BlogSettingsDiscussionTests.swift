import Foundation
import XCTest

@testable import WordPress
@testable import WordPressData

class BlogSettingsDiscussionTests: CoreDataTestCase {
    func testCommentsAutoapprovalDisabledEnablesManualModerationFlag() {
        let settings = newSettings()
        settings.commentsAutoapproval = .disabled
        XCTAssertTrue(settings.commentsRequireManualModeration)
        XCTAssertFalse(settings.commentsFromKnownUsersAllowlisted)
    }

    func testCommentsAutoapprovalFromKnownUsersEnablesAllowlistedFlag() {
        let settings = newSettings()
        settings.commentsAutoapproval = .fromKnownUsers
        XCTAssertFalse(settings.commentsRequireManualModeration)
        XCTAssertTrue(settings.commentsFromKnownUsersAllowlisted)
    }

    func testCommentsAutoapprovalEverythingDisablesManualModerationAndAllowlistedFlags() {
        let settings = newSettings()
        settings.commentsAutoapproval = .everything
        XCTAssertFalse(settings.commentsRequireManualModeration)
        XCTAssertFalse(settings.commentsFromKnownUsersAllowlisted)
    }

    func testCommentsSortingSetsTheCorrectCommentSortOrderIntegerValue() {
        let settings = newSettings()

        settings.commentsSorting = .ascending
        XCTAssertTrue(settings.commentsSortOrder?.intValue == Sorting.ascending.rawValue)

        settings.commentsSorting = .descending
        XCTAssertTrue(settings.commentsSortOrder?.intValue == Sorting.descending.rawValue)
    }

    func testCommentsSortOrderAscendingSetsTheCorrectCommentSortOrderIntegerValue() {
        let settings = newSettings()

        settings.commentsSortOrderAscending = true
        XCTAssertTrue(settings.commentsSortOrder?.intValue == Sorting.ascending.rawValue)

        settings.commentsSortOrderAscending = false
        XCTAssertTrue(settings.commentsSortOrder?.intValue == Sorting.descending.rawValue)
    }

    func testCommentsThreadingDisablesSetsThreadingEnabledFalse() {
        let settings = newSettings()

        settings.commentsThreading = .disabled
        XCTAssertFalse(settings.commentsThreadingEnabled)
    }

    func testCommentsThreadingEnabledSetsThreadingEnabledTrueAndTheRightDepthValue() {
        let settings = newSettings()

        settings.commentsThreading = .enabled(depth: 10)
        XCTAssertTrue(settings.commentsThreadingEnabled)
        XCTAssert(settings.commentsThreadingDepth == 10)

        settings.commentsThreading = .enabled(depth: 2)
        XCTAssertTrue(settings.commentsThreadingEnabled)
        XCTAssert(settings.commentsThreadingDepth == 2)
    }

    // MARK: - Typealiases
    typealias Sorting = BlogSettings.CommentsSorting

    // MARK: - Private Helpers
    fileprivate func newSettings() -> BlogSettings {
        let name = BlogSettings.classNameWithoutNamespaces()
        let entity = NSEntityDescription.insertNewObject(forEntityName: name, into: mainContext)

        return entity as! BlogSettings
    }
}
