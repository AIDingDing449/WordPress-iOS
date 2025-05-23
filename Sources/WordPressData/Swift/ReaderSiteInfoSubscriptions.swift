import Foundation
import CoreData

@objc(ReaderSiteInfoSubscriptionPost)
public class ReaderSiteInfoSubscriptionPost: NSManagedObject {
    @NSManaged open var siteTopic: ReaderSiteTopic
    @NSManaged open var sendPosts: Bool

    class func createOrUpdate(from remoteSiteInfo: RemoteReaderSiteInfo, topic: ReaderSiteTopic, context: NSManagedObjectContext) -> ReaderSiteInfoSubscriptionPost? {
        guard let postSubscription = remoteSiteInfo.postSubscription, postSubscription.wp_isValidObject() else {
            return nil
        }

        var subscription = topic.postSubscription
        if subscription?.wp_isValidObject() == false {
            subscription = ReaderSiteInfoSubscriptionPost(context: context)
        }

        subscription?.siteTopic = topic
        subscription?.sendPosts = postSubscription.sendPosts

        return subscription
    }
}

@objc(ReaderSiteInfoSubscriptionEmail)
public class ReaderSiteInfoSubscriptionEmail: NSManagedObject {
    @NSManaged open var siteTopic: ReaderSiteTopic
    @NSManaged open var sendPosts: Bool
    @NSManaged open var sendComments: Bool
    @NSManaged open var postDeliveryFrequency: String

    class func createOrUpdate(from remoteSiteInfo: RemoteReaderSiteInfo, topic: ReaderSiteTopic, context: NSManagedObjectContext) -> ReaderSiteInfoSubscriptionEmail? {
        guard let emailSubscription = remoteSiteInfo.emailSubscription, emailSubscription.wp_isValidObject() else {
            return nil
        }

        var subscription = topic.emailSubscription
        if subscription?.wp_isValidObject() == false {
            subscription = ReaderSiteInfoSubscriptionEmail(context: context)
        }

        subscription?.siteTopic = topic
        subscription?.sendPosts = emailSubscription.sendPosts
        subscription?.sendComments = emailSubscription.sendComments
        subscription?.postDeliveryFrequency = emailSubscription.postDeliveryFrequency

        return subscription
    }
}
