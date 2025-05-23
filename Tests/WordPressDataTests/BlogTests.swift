import XCTest
@testable import WordPressData

final class BlogTests: CoreDataTestCase {

    // MARK: - Atomic Tests
    func testIsAtomic() {
        let blog = BlogBuilder(mainContext)
            .with(atomic: true)
            .build()

        XCTAssertTrue(blog.isAtomic())
    }

    func testIsNotAtomic() {
        let blog = BlogBuilder(mainContext)
            .with(atomic: false)
            .build()

        XCTAssertFalse(blog.isAtomic())
    }

    // MARK: - Blog Lookup
    func testThatLookupByBlogIDWorks() throws {
        let blog = BlogBuilder(mainContext).build()
        XCTAssertNotNil(blog.dotComID)
        XCTAssertNotNil(Blog.lookup(withID: blog.dotComID!, in: mainContext))
    }

    func testThatLookupByBlogIDFailsForInvalidBlogID() throws {
        XCTAssertNil(Blog.lookup(withID: NSNumber(integerLiteral: 1), in: mainContext))
    }

    func testThatLookupByBlogIDWorksForIntegerBlogID() throws {
        let blog = BlogBuilder(mainContext).build()
        XCTAssertNotNil(blog.dotComID)
        XCTAssertNotNil(try Blog.lookup(withID: blog.dotComID!.intValue, in: mainContext))
    }

    func testThatLookupByBlogIDFailsForInvalidIntegerBlogID() throws {
        XCTAssertNil(try Blog.lookup(withID: 1, in: mainContext))
    }

    func testThatLookupBlogIDWorksForInt64BlogID() throws {
        let blog = BlogBuilder(mainContext).build()
        XCTAssertNotNil(blog.dotComID)
        XCTAssertNotNil(try Blog.lookup(withID: blog.dotComID!.int64Value, in: mainContext))
    }

    func testThatLookupByBlogIDFailsForInvalidInt64BlogID() throws {
        XCTAssertNil(try Blog.lookup(withID: Int64(1), in: mainContext))
    }

    // MARK: - Post lookup
    func testThatLookupPostWorks() {
        let context = contextManager.newDerivedContext()
        let blog = BlogBuilder(context)
            .set(blogOption: "foo", value: "bar")
            .build()
        let post = PostBuilder(context, blog: blog).build()
        post.postID = NSNumber(value: Int64.max)
        contextManager.saveContextAndWait(context)

        XCTAssertIdentical(blog.lookupPost(withID: post.postID!, in: mainContext)?.managedObjectContext, mainContext)
        XCTAssertIdentical(blog.lookupPost(withID: post.postID!, in: context)?.managedObjectContext, context)
    }

    // MARK: - Plugin Management
    func testThatPluginManagementIsDisabledForSimpleSites() {
        let blog = BlogBuilder(mainContext)
            .with(atomic: true)
            .build()

        XCTAssertFalse(blog.supports(.pluginManagement))
    }

    func testThatPluginManagementIsEnabledForBusinessPlans() {
        let blog = BlogBuilder(mainContext)
            .with(isHostedAtWPCom: true)
            .with(planID: 1008) // Business plan
            .with(isAdmin: true)
            .build()

        XCTAssertTrue(blog.supports(.pluginManagement))
    }

    func testThatPluginManagementIsDisabledForPrivateSites() {
        let blog = BlogBuilder(mainContext)
            .with(isHostedAtWPCom: true)
            .with(planID: 1008) // Business plan
            .with(isAdmin: true)
            .with(siteVisibility: .private)
            .build()

        XCTAssertTrue(blog.supports(.pluginManagement))
    }

    // FIXME: Crashes because WPAccount fixture sets username and triggers BuildSettings access
//    func testThatPluginManagementIsEnabledForJetpack() {
//        let blog = BlogBuilder(mainContext)
//            .withAnAccount()
//            .withJetpack(version: "5.6", username: "test_user", email: "user@example.com")
//            .with(isHostedAtWPCom: false)
//            .with(isAdmin: true)
//            .build()
//
//        XCTAssertTrue(blog.supports(.pluginManagement))
//    }

    func testThatPluginManagementIsDisabledForWordPress54AndBelow() {
        let blog = BlogBuilder(mainContext)
            .with(wordPressVersion: "5.4")
            .with(username: "test_username")
            .with(password: "test_password")
            .with(isAdmin: true)
            .build()

        XCTAssertFalse(blog.supports(.pluginManagement))
    }

    func testThatPluginManagementIsEnabledForWordPress55AndAbove() {
        let blog = BlogBuilder(mainContext)
            .with(wordPressVersion: "5.5")
            .with(username: "test_username")
            .with(password: "test_password")
            .with(isAdmin: true)
            .build()

        XCTExpectFailure("Fails because it gets a nil WordPressOrgRestApi instance", strict: true)
        XCTAssertTrue(blog.supports(.pluginManagement))
    }

    func testThatPluginManagementIsDisabledForNonAdmins() {
        let blog = BlogBuilder(mainContext)
            .with(wordPressVersion: "5.5")
            .with(username: "test_username")
            .with(password: "test_password")
            .with(isAdmin: false)
            .build()

        XCTAssertFalse(blog.supports(.pluginManagement))
    }

    func testStatsActiveForSitesHostedAtWPCom() {
        let blog = BlogBuilder(mainContext)
            .isHostedAtWPcom()
            .with(modules: [""])
            .build()

        XCTAssertTrue(blog.isStatsActive())
    }

    func testStatsActiveForSitesNotHotedAtWPCom() {
        let blog = BlogBuilder(mainContext)
            .isNotHostedAtWPcom()
            .with(modules: ["stats"])
            .build()

        XCTAssertTrue(blog.isStatsActive())
    }

    func testStatsNotActiveForSitesNotHotedAtWPCom() {
        let blog = BlogBuilder(mainContext)
            .isNotHostedAtWPcom()
            .with(modules: [""])
            .build()

        XCTAssertFalse(blog.isStatsActive())
    }

    // MARK: - Blog.version string conversion testing
    func testTheVersionIsAStringWhenGivenANumber() {
        let blog = BlogBuilder(mainContext)
            .set(blogOption: "software_version", value: 13.37)
            .build()

        XCTAssertTrue((blog.version as Any) is String)
        XCTAssertEqual(blog.version, "13.37")
    }

    func testTheVersionIsAStringWhenGivenAString() {
        let blog = BlogBuilder(mainContext)
            .set(blogOption: "software_version", value: "5.5")
            .build()

        XCTAssertTrue((blog.version as Any) is String)
        XCTAssertEqual(blog.version, "5.5")
    }

    func testTheVersionDefaultsToAnEmptyStringWhenTheValueIsNotConvertible() {
        let blog = BlogBuilder(mainContext)
            .set(blogOption: "software_version", value: NSObject())
            .build()

        XCTAssertTrue((blog.version as Any) is String)
        XCTAssertEqual(blog.version, "")
    }

    // FIXME: Crashes because WPAccount fixture sets username and triggers BuildSettings access
//    func testRemoveDuplicates() async throws {
//        // Create an account with duplicated blogs
//        let xmlrpc = "https://xmlrpc.test.wordpress.com"
//        let account = try await contextManager.performAndSave { context in
//            let account = WPAccount.fixture(context: context)
//            account.blogs = Set(
//                (1...10).map { _ in
//                    let blog = BlogBuilder(context).build()
//                    blog.xmlrpc = xmlrpc
//                    return blog
//                }
//            )
//            return account
//        }
//        try XCTAssertEqual(mainContext.count(for: Blog.fetchRequest()), 10)
//
//        try await contextManager.performAndSave { context in
//            let accountInContext = try XCTUnwrap(context.existingObject(with: account.objectID) as? WPAccount)
//            let blog = Blog.lookup(xmlrpc: xmlrpc, andRemoveDuplicateBlogsOf: accountInContext, in: context)
//            XCTAssertNotNil(blog)
//        }
//
//        try XCTAssertEqual(mainContext.count(for: Blog.fetchRequest()), 1)
//    }

    // MARK: - Blog Feature Domains

    func testBlogSupportsDomainsHostedAtWPcom() {
        let blog = BlogBuilder(mainContext)
            .isHostedAtWPcom()
            .with(atomic: false)
            .with(isAdmin: true)
            .build()

        let result = blog.supports(.domains)

        XCTAssertTrue(result, "Domains should be supported for WPcom hosted blogs")
    }

    func testBlogSupportsDomainsAtomic() {
        let blog = BlogBuilder(mainContext)
            .isNotHostedAtWPcom()
            .with(atomic: true)
            .with(isAdmin: true)
            .build()

        let result = blog.supports(.domains)

        XCTAssertTrue(result, "Domains should be supported for Atomic blogs")
    }

    func testShouldNotSupportDomainsNotAdmin() {
        let blog = BlogBuilder(mainContext)
            .isHostedAtWPcom()
            .with(atomic: false)
            .with(isAdmin: false)
            .build()

        let result = blog.supports(.domains)

        XCTAssertFalse(result, "Domains should not be supported for non-admin users")
    }

    func testShouldNotSupportDomainsForP2s() {
        let blog = BlogBuilder(mainContext)
            .isHostedAtWPcom()
            .with(atomic: false)
            .with(isAdmin: true)
            .with(isWPForTeamsSite: true)
            .build()

        let result = blog.supports(.domains)

        XCTAssertFalse(result, "Domains should not be supported when the site is P2 site")
    }

    // Blog URL Parsing Tests
    func testBlogUrlShouldBeParseableForBlogWithSimpleUrl() throws {
        let blog = BlogBuilder(mainContext)
            .isHostedAtWPcom()
            .with(url: "http://example.com")
            .build()

        XCTAssertEqual(try blog.wordPressClientParsedUrl().url(), "http://example.com/")
    }

    func testBlogUrlShouldBeParseableForBlogWithMappedDomain() throws {
        let blog = BlogBuilder(mainContext)
            .with(url: "http://example.com")
            .withMappedDomain(mappedDomainUrl: "http://example2.com")
            .build()

        XCTAssertEqual(try blog.wordPressClientParsedUrl().url(), "http://example.com/")
    }

    func testDotComIdShouldBeJetpackSiteID() throws {
        let blog = BlogBuilder(mainContext, dotComID: nil)
            .set(blogOption: "jetpack_client_id", value: "123")
            .build()
        XCTAssertEqual(blog.jetpack?.siteID?.int64Value, 123)

        try XCTAssertNil(Blog.lookup(withID: 123, in: mainContext))
        try mainContext.save()

        try XCTAssertNotNil(Blog.lookup(withID: 123, in: mainContext))

        contextManager.performAndSave { context in
            try? XCTAssertNotNil(Blog.lookup(withID: 123, in: context))
        }
    }
}
