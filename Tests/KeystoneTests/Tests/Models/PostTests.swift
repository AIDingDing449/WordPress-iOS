import Foundation
import XCTest

@testable import WordPress
@testable import WordPressData

class PostTests: CoreDataTestCase {

    fileprivate func newTestBlog() -> Blog {
        return NSEntityDescription.insertNewObject(forEntityName: Blog.entityName(), into: mainContext) as! Blog
    }

    fileprivate func newTestPost() -> Post {
        return NSEntityDescription.insertNewObject(forEntityName: Post.entityName(), into: mainContext) as! Post
    }

    fileprivate func newTestPostCategory() -> PostCategory {
        return NSEntityDescription.insertNewObject(forEntityName: PostCategory.entityName(), into: mainContext) as! PostCategory
    }

    fileprivate func newTestPostCategory(_ name: String) -> PostCategory {
        let category = newTestPostCategory()
        category.categoryName = name

        return category
    }

    func testSetCategoriesFromNamesWithTwoCategories() {
        let blog = newTestBlog()
        let post = newTestPost()

        let category1 = newTestPostCategory("One")
        let category2 = newTestPostCategory("Two")
        let category3 = newTestPostCategory("Three")

        blog.categories = [category1, category2, category3]

        post.blog = blog
        post.setCategoriesFromNames(["One", "Three"])

        let postCategories = post.categories!
        XCTAssertEqual(postCategories.count, 2)
        XCTAssertTrue(postCategories.contains(category1))
        XCTAssertFalse(postCategories.contains(category2))
        XCTAssertTrue(postCategories.contains(category3))
    }

    func testThatSettingNilLikeCountReturnsZeroNumberOfLikes() {
        let post = newTestPost()

        post.likeCount = nil

        XCTAssertEqual(post.numberOfLikes(), 0)
    }

    func testThatSettingLikeCountAffectsNumberOfLikes() {
        let post = newTestPost()

        post.likeCount = 2

        XCTAssertEqual(post.numberOfLikes(), 2)
    }

    func testThatSettingNilCommentCountReturnsZeroNumberOfComments() {
        let post = newTestPost()

        post.commentCount = nil

        XCTAssertEqual(post.numberOfComments(), 0)
    }

    func testThatSettingCommentCountAffectsNumberOfComments() {
        let post = newTestPost()

        post.commentCount = 2

        XCTAssertEqual(post.numberOfComments(), 2)
    }

    func testThatAddCategoriesWorks() {
        let post = newTestPost()
        let testCategories = Set([newTestPostCategory("1"), newTestPostCategory("2"), newTestPostCategory("3")])

        post.addCategories(testCategories)

        guard let postCategories = post.categories else {
            XCTFail("post.categories should not be nil here.")
            return
        }

        XCTAssert(postCategories.count == testCategories.count)

        for testCategory in testCategories {
            XCTAssertTrue(postCategories.contains(testCategory))
        }
    }

    func testThatAddCategoriesObjectWorks() {
        let post = newTestPost()
        let testCategory = newTestPostCategory("1")

        post.addCategoriesObject(testCategory)

        guard let postCategories = post.categories else {
            XCTFail("post.categories should not be nil here.")
            return
        }

        XCTAssertEqual(postCategories.count, 1)
        XCTAssertTrue(postCategories.contains(testCategory))
    }

    func testThatRemoveCategoriesWorks() {
        let post = newTestPost()
        let testCategories = Set<PostCategory>(arrayLiteral: newTestPostCategory("1"), newTestPostCategory("2"), newTestPostCategory("3"))

        post.categories = testCategories
        XCTAssertNotEqual(post.categories?.count, 0)
        XCTAssertEqual(post.categories?.count, testCategories.count)

        post.removeCategories(testCategories)
        XCTAssertEqual(post.categories?.count, 0)
    }

    func testThatRemoveCategoriesObjectWorks() {
        let post = newTestPost()
        let testCategory = newTestPostCategory("1")

        post.categories = Set<PostCategory>(arrayLiteral: testCategory)
        XCTAssertEqual(post.categories?.count, 1)

        post.removeCategoriesObject(testCategory)
        XCTAssertEqual(post.categories?.count, 0)
    }

    func testThatPostFormatTextReturnsDefault() {
        let defaultPostFormat = (key: "standard", value: "Default")

        let post = newTestPost()
        let blog = newTestBlog()

        blog.postFormats = [defaultPostFormat.key: defaultPostFormat.value]
        post.blog = blog

        let postFormatText = post.postFormatText()!
        XCTAssertEqual(postFormatText, defaultPostFormat.value)
    }

    func testThatPostFormatTextReturnsSelected() {
        let defaultPostFormat = (key: "standard", value: "Default")
        let secondaryPostFormat = (key: "secondary", value: "Secondary")

        let post = newTestPost()
        let blog = newTestBlog()

        blog.postFormats = [defaultPostFormat.key: defaultPostFormat.value,
                            secondaryPostFormat.key: secondaryPostFormat.value]
        post.blog = blog
        post.postFormat = secondaryPostFormat.key

        let postFormatText = post.postFormatText()!
        XCTAssertEqual(postFormatText, secondaryPostFormat.value)
    }

    func testThatSetPostFormatTextWorks() {
        let defaultPostFormat = (key: "standard", value: "Default")
        let secondaryPostFormat = (key: "secondary", value: "Secondary")

        let post = newTestPost()
        let blog = newTestBlog()

        blog.postFormats = [defaultPostFormat.key: defaultPostFormat.value,
                            secondaryPostFormat.key: secondaryPostFormat.value]
        post.blog = blog
        post.setPostFormatText(secondaryPostFormat.value)

        XCTAssertEqual(post.postFormat, secondaryPostFormat.key)
    }

    func testPostFormatSorting() throws {
        let postFormats = [
            "b": "B",
            "c": "C",
            "q": "Q",
            "z": "Z",
            "standard": "Standard",
            "a": "A",
            "d": "D",
        ]

        let expectedPostFormats = [
            ("standard", "Standard"),
            ("a", "A"),
            ("b", "B"),
            ("c", "C"),
            ("d", "D"),
            ("q", "Q"),
            ("z", "Z")
        ]

        let blog = BlogBuilder(mainContext)
            .with(postFormats: postFormats)
            .build()

        let sortedPostFormats = try XCTUnwrap(blog.sortedPostFormats as? [String])
        let sortedPostFormatNames = try XCTUnwrap(blog.sortedPostFormatNames as? [String])

        XCTAssertEqual(expectedPostFormats.map { $0.0 }, sortedPostFormats)
        XCTAssertEqual(expectedPostFormats.map { $0.1 }, sortedPostFormatNames)
    }

    func testThatHasCategoriesWorks() {
        let post = newTestPost()

        XCTAssertFalse(post.hasCategories())
        post.categories = [newTestPostCategory("1"), newTestPostCategory("2"), newTestPostCategory("3")]
        XCTAssertTrue(post.hasCategories())
        post.categories = nil
        XCTAssertFalse(post.hasCategories())
    }

    func testThatHasTagsWorks() {
        let post = newTestPost()

        XCTAssertFalse(post.hasTags())
        post.tags = "a b c"
        XCTAssertTrue(post.hasTags())
        post.tags = nil
        XCTAssertFalse(post.hasTags())
    }

    func testThatTitleForDisplayWorks() {
        let post = newTestPost()

        XCTAssertEqual(post.titleForDisplay(), NSLocalizedString("(no title)", comment: "(no title)"))

        post.postTitle = "hello world"
        XCTAssertEqual(post.titleForDisplay(), "hello world")

        post.postTitle = "hello <i>world</i>"
        XCTAssertEqual(post.titleForDisplay(), "hello world")

        post.postTitle = "    "
        XCTAssertEqual(post.titleForDisplay(), NSLocalizedString("(no title)", comment: "(no title)"))
    }

    func testThatContentPreviewForDisplayWorks() {
        let post = newTestPost()

        post.content = "<HTML>some contents&nbsp;go here</HTML>"
        XCTAssertEqual(post.contentPreviewForDisplay(), "some contents\u{A0}go here")
    }

    func testThatContentPreviewForDisplayWorksWithExcerpt() {
        let post = newTestPost()

        post.mt_excerpt = "<HTML>some contents&nbsp;go here</HTML>"
        post.content = "blah blah"
        XCTAssertEqual(post.contentPreviewForDisplay(), "some contents\u{A0}go here")
    }

    func testThatEnablingDisablingPublicizeConnectionsWorks() {
        let post = newTestPost()

        post.disablePublicizeConnectionWithKeyringID(1234)
        XCTAssertTrue(post.publicizeConnectionDisabledForKeyringID(1234))

        post.enablePublicizeConnectionWithKeyringID(1234)
        XCTAssertFalse(post.publicizeConnectionDisabledForKeyringID(1234))
    }

    func testThatCanEditPublicizeSettingsWorks() {
        let post = newTestPost()

        post.status = .publish
        XCTAssertTrue(post.canEditPublicizeSettings())

        post.postID = 2905
        XCTAssertFalse(post.canEditPublicizeSettings())

        post.status = .scheduled
        XCTAssertTrue(post.canEditPublicizeSettings())

        post.status = .draft
        XCTAssertTrue(post.canEditPublicizeSettings())
    }

    func testCountLocalDrafts() {
        let blog = BlogBuilder(mainContext).build()
        let _ = blog.createDraftPost()

        XCTAssertEqual(AbstractPost.countLocalPosts(in: mainContext), 1)
    }
}
