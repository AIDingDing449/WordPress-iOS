import SwiftUI

@MainActor
class UserDetailViewModel: ObservableObject {
    private let userProvider: UserDataProvider

    @Published
    var currentUserCanModifyUsers: Bool = false

    @Published
    var isLoadingCurrentUser: Bool = false

    @Published
    var error: Error? = nil

    init(userProvider: UserDataProvider) {
        self.userProvider = userProvider
    }

    func loadCurrentUserRole() async {
        withAnimation {
            isLoadingCurrentUser = true
        }

        do {
            let hasPermissions = try await userProvider.fetchCurrentUserCan("edit_users")
            error = nil

            withAnimation {
                currentUserCanModifyUsers = hasPermissions
            }
        } catch {
            withAnimation {
                self.error = error
            }
        }

        withAnimation {
            isLoadingCurrentUser = false
        }
    }
}