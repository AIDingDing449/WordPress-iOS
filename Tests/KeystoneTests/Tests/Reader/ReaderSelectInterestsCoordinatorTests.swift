import WordPressShared
import XCTest
@testable import WordPress
@testable import WordPressData

class ReaderSelectInterestsCoordinatorTests: CoreDataTestCase {
    func testisFollowingInterestsReturnsFalse() {
        let store = EphemeralKeyValueDatabase()
        let service = MockFollowedInterestsService(populateItems: false, coreDataStack: contextManager)
        let coordinator = ReaderSelectInterestsCoordinator(service: service, store: store, userId: 1)

        service.success = true
        service.fetchSuccessExpectation = expectation(description: "Fetching of interests succeeds")

        let displayExpectation = expectation(description: "Should display returns true")
        coordinator.isFollowingInterests { (result) in
            displayExpectation.fulfill()

            XCTAssertFalse(result)
        }

        waitForExpectations(timeout: 4, handler: nil)
    }

    func testisFollowingInterestsReturnsTrue() {
        let store = EphemeralKeyValueDatabase()
        let service = MockFollowedInterestsService(populateItems: true, coreDataStack: contextManager)
        let coordinator = ReaderSelectInterestsCoordinator(service: service, store: store, userId: 1)

        let successExpectation = expectation(description: "Fetching of interests succeeds")

        service.success = true
        service.fetchSuccessExpectation = successExpectation

        let displayExpectation = expectation(description: "Should display returns true")
        coordinator.isFollowingInterests { (result) in
            displayExpectation.fulfill()

            XCTAssertTrue(result)
        }

        waitForExpectations(timeout: 4, handler: nil)
    }

    func testSaveInterestsTriggersSuccess() {
        let store = EphemeralKeyValueDatabase()
        let service = MockFollowedInterestsService(populateItems: false, coreDataStack: contextManager)
        let coordinator = ReaderSelectInterestsCoordinator(service: service, store: store, userId: nil)

        let successExpectation = expectation(description: "Saving of interests callback returns true")

        let interest = MockInterestsService.mock(title: "title", slug: "slug")
        coordinator.saveInterests(interests: [interest]) { success in
            successExpectation.fulfill()
            XCTAssertTrue(success)
        }

        waitForExpectations(timeout: 4, handler: nil)
    }

    func testSaveInterestsTriggersFailure() {
        let store = EphemeralKeyValueDatabase()
        let service = MockFollowedInterestsService(populateItems: false, coreDataStack: contextManager)
        let coordinator = ReaderSelectInterestsCoordinator(service: service, store: store, userId: nil)

        service.success = false

        let failureExpectation = expectation(description: "Saving of interests callback returns false")

        let interest = MockInterestsService.mock(title: "title", slug: "slug")
        coordinator.saveInterests(interests: [interest]) { success in
            failureExpectation.fulfill()
            XCTAssertFalse(success)
        }

        waitForExpectations(timeout: 4, handler: nil)
    }
}

// MARK: - MockFollowedInterestsService
class MockFollowedInterestsService: ReaderFollowedInterestsService {

    var success = true
    var populateItems = false
    var fetchSuccessExpectation: XCTestExpectation?
    var fetchFailureExpectation: XCTestExpectation?

    private let failureError = NSError(domain: "org.wordpress.reader-tests", code: 1, userInfo: nil)

    private var coreDataStack: CoreDataStack
    private var context: NSManagedObjectContext {
        coreDataStack.mainContext
    }

    init(populateItems: Bool, coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
        self.populateItems = populateItems
    }

    // MARK: - Fetch Methods
    func fetchFollowedInterestsLocally(completion: @escaping ([ReaderTagTopic]?) -> Void) {
        guard self.success else {
            fetchFailureExpectation?.fulfill()

            completion(nil)
            return
        }

        self.populateItems ? completion([createInterest()]) : completion([])
        fetchSuccessExpectation?.fulfill()
    }

    func fetchFollowedInterestsRemotely(completion: @escaping ([ReaderTagTopic]?) -> Void) {
        self.fetchFollowedInterestsLocally(completion: completion)
    }

    func followInterests(_ interests: [RemoteReaderInterest],
                         success: @escaping ([ReaderTagTopic]?) -> Void,
                         failure: @escaping (Error) -> Void,
                         isLoggedIn: Bool) {
        guard self.success else {
            fetchFailureExpectation?.fulfill()

            failure(failureError)
            return
        }

        var topics: [ReaderTagTopic] = []

        interests.forEach { remoteInterest in
            let topic = NSEntityDescription.insertNewObject(forEntityName: ReaderTagTopic.entityName(), into: context) as! ReaderTagTopic
            topic.tagID = isLoggedIn ? 1 : ReaderTagTopic.loggedOutTagID
            topic.type = ReaderTagTopic.TopicType
            topic.path = "/tag/interest"
            topic.following = true
            topic.showInMenu = true
            topic.title = remoteInterest.title
            topic.slug = remoteInterest.slug

            topics.append(topic)
        }

        success(topics)
        fetchSuccessExpectation?.fulfill()
    }

    func path(slug: String) -> String {
        return "/path/to/slug"
    }

    // MARK: - Private: Helpers
    private func createInterest() -> ReaderTagTopic {
        let interest = NSEntityDescription.insertNewObject(forEntityName: ReaderTagTopic.entityName(), into: context) as! ReaderTagTopic
        interest.path = "/tags/interest"
        interest.title = "interest"
        interest.type = ReaderTagTopic.TopicType
        interest.following = true
        interest.showInMenu = true

        return interest
    }
}
