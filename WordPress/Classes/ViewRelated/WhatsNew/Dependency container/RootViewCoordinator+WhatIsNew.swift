import WordPressData
import WordPressShared

/// dependency container for the What's New / Feature Announcements scene
extension RootViewCoordinator {

    @objc func presentWhatIsNew(on viewController: UIViewController) {

        DispatchQueue.main.async { [weak viewController] in
            guard let viewController else {
                return
            }
            self.whatIsNewScenePresenter.present(on: viewController, animated: true, completion: nil)
        }
    }

    @objc func makeWhatIsNewPresenter() -> ScenePresenter {
        return WhatIsNewScenePresenter(store: makeAnnouncementStore())
    }

    private func makeAnnouncementStore() -> AnnouncementsStore {
        return CachedAnnouncementsStore(cache: makeCache(), service: makeAnnouncementsService())
    }

    private func makeAnnouncementsService() -> AnnouncementServiceRemote {
        return AnnouncementServiceRemote(wordPressComRestApi: makeApi())
    }

    private func makeCache() -> AnnouncementsCache {
        return UserDefaultsAnnouncementsCache()
    }

    private func makeApi() -> WordPressComRestApi {
        let defaultAccount = try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext)
        let token: String? = defaultAccount?.authToken

        return WordPressComRestApi.defaultApi(oAuthToken: token,
                                              userAgent: WPUserAgent.wordPress(),
                                              localeKey: WordPressComRestApi.LocaleKeyV2)
    }
}
