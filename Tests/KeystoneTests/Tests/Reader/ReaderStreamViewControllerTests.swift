import UIKit
import XCTest
@testable import WordPress
@testable import WordPressData

class ReaderStreamViewControllerTests: CoreDataTestCase {
    // Tests that a ReaderStreamViewController is returned
    func testControllerWithTopic() {
        let context = mainContext
        let topic = NSEntityDescription.insertNewObject(forEntityName: ReaderTagTopic.entityName(), into: context) as! ReaderTagTopic
        topic.path = "foo"

        let controller = ReaderStreamViewController.controllerWithTopic(topic)
        XCTAssertNotNil(controller, "Controller should not be nil")
    }

    func testControllerWithSiteID() {
        let controller = ReaderStreamViewController.controllerWithSiteID(NSNumber(value: 1), isFeed: false)
        XCTAssertNotNil(controller, "Controller should not be nil")
    }
}
