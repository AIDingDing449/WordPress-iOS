import XCTest
import Nimble
@testable import WordPress
@testable import WordPressData

class SiteAddressServiceTests: CoreDataTestCase {

    var remoteApi: MockWordPressComRestApi!
    var service: DomainsServiceAdapter!
    var mockedResponse: Any!

    override func setUpWithError() throws {
        remoteApi = MockWordPressComRestApi()
        service = DomainsServiceAdapter(coreDataStack: contextManager, api: remoteApi)

        let json = Bundle(for: SiteSegmentTests.self).url(forResource: "domain-suggestions", withExtension: "json")!
        let data = try Data(contentsOf: json)
        mockedResponse = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
    }

    func testSuggestionsWithMatchingTermSuccess() {
        let searchTerm = "domaintesting"

        let waitExpectation = expectation(description: "Domains should be successfully fetched")
        service.addresses(for: searchTerm, type: .wordPressDotComAndDotBlogSubdomains) { (results) in
            switch results {
            case .success(let fetchedResults):
                self.resultsAreSorted(fetchedResults, forQuery: searchTerm, expectMatch: true)
            case .failure:
                fail("This is using a mocked endpoint so there is a test error")
            }

            waitExpectation.fulfill()
        }

        expect(self.remoteApi.getMethodCalled).to(beTrue())

        // Respond with mobile editor not yet set on the server
        remoteApi.successBlockPassedIn!(mockedResponse as AnyObject, HTTPURLResponse())
        expect(self.remoteApi.URLStringPassedIn!).to(equal("rest/v1.1/domains/suggestions"))
        let parameters = remoteApi.parametersPassedIn as! [String: AnyObject]

        expect(parameters["query"] as? String).to(equal(searchTerm))
        expect(parameters["quantity"] as? Int).toNot(beNil())

        waitForExpectations(timeout: 0.1)
    }

    func testSuggestionsWithOutMatchingTermSuccess() {
        let searchTerm = "notIncludedResult"

        let waitExpectation = expectation(description: "Domains should be successfully fetched")
        service.addresses(for: searchTerm, type: .wordPressDotComAndDotBlogSubdomains) { (results) in
            switch results {
            case .success(let fetchedResults):
                self.resultsAreSorted(fetchedResults, forQuery: searchTerm, expectMatch: false)
            case .failure:
                fail("This is using a mocked endpoint so there is a test error")
            }

            waitExpectation.fulfill()
        }

        expect(self.remoteApi.getMethodCalled).to(beTrue())

        // Respond with mobile editor not yet set on the server
        remoteApi.successBlockPassedIn!(mockedResponse as AnyObject, HTTPURLResponse())
        expect(self.remoteApi.URLStringPassedIn!).to(equal("rest/v1.1/domains/suggestions"))
        let parameters = remoteApi.parametersPassedIn as! [String: AnyObject]

        expect(parameters["query"] as? String).to(equal(searchTerm))
        expect(parameters["quantity"] as? Int).to(equal(20))

        waitForExpectations(timeout: 0.1)
    }

    // Helpers
    func resultsAreSorted(_ results: SiteAddressServiceResult, forQuery query: String, expectMatch: Bool) {
        let suggestions = results.domainSuggestions

        let domainNames = suggestions.compactMap { (suggestion) -> String? in
            guard !suggestion.domainName.contains(query) else { return nil } //Filter out exact matches
            return suggestion.domainName
        }

        let sortedDomainNames = domainNames.sorted()
        expect(sortedDomainNames).to(equal(domainNames)) // Expect the results after sorting to be the same as the results before sorting
    }
}
