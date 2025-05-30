import XCTest
import Nimble

@testable import WordPress
@testable import WordPressData

final class ReaderPostBackupTests: XCTestCase {
    private let storeURL = URL.Helpers.temporaryFile(named: "ReaderPostBackup.sqlite")
    private let backupURL = URL.Helpers.temporaryFile(named: "ReaderPostBackup-backup.sqlite")

    private var coreDataStack: CoreDataStack!

    override func setUpWithError() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(at: storeURL) {
            try fileManager.removeItem(at: storeURL)
        }
        if fileManager.fileExists(at: backupURL) {
            try fileManager.removeItem(at: backupURL)
        }

        coreDataStack = ContextManager(modelName: ContextManagerModelNameCurrent, store: storeURL)
    }

    func testBackupReaderPost() {
        coreDataStack.performAndSave { context in
            let post: ReaderPost = ReaderPostBuilder(context).build()
            let card = ReaderCard(context: context)
            card.post = post
            post.content = "test post"
            post.card = [card]
        }

        let migrator = DataMigrator(
            coreDataStack: coreDataStack,
            backupLocation: backupURL,
            localDefaults: InMemoryUserDefaults(),
            sharedDefaults: InMemoryUserDefaults(),
            appGroupName: "xctest_app_group_name"
        )
        waitUntil { done in
            migrator.exportData { result in
                XCTAssertNoThrow {
                    try result.get()
                }
                done()
            }
        }
    }

}
