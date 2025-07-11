import Foundation
import WordPressData

/// Encapsulates a command to toggle subscribing to notifications for a site
final class ReaderSubscribingNotificationAction {
    func execute(for siteID: NSNumber?, context: NSManagedObjectContext, subscribe: Bool, completion: (() -> Void)? = nil, failure: ((ReaderTopicServiceError?) -> Void)? = nil) {
        guard let siteID else {
            return
        }

        let service = ReaderTopicService(coreDataStack: ContextManager.shared)
        service.toggleSubscribingNotifications(for: siteID.intValue, subscribe: subscribe, completion, failure)
    }
}
