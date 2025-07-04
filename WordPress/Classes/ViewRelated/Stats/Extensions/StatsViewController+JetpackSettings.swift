import Foundation
import UIKit
import WordPressData

extension StatsViewController {

    @objc public func activateStatsModule(success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let blog else {
            return
        }

        let service = BlogJetpackSettingsService(coreDataStack: ContextManager.shared)

        service.updateJetpackModuleActiveSettingForBlog(blog,
                                                        module: Constants.statsModule,
                                                        active: true,
                                                        success: success,
                                                        failure: failure)

    }

    private enum Constants {
        static let statsModule = "stats"
    }

}
