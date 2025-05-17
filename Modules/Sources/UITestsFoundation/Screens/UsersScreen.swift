import ScreenObject
import XCTest

public class UsersScreen: ScreenObject {

    private let usersTableGetter: (XCUIApplication) -> XCUIElement = {
        $0.tables["users_table_view"].firstMatch
    }

    init(app: XCUIApplication = XCUIApplication()) throws {
        try super.init(
            expectedElementGetters: [usersTableGetter],
            app: app
        )
    }

    public static func isLoaded() -> Bool {
        (try? UsersScreen().isLoaded) ?? false
    }
}
