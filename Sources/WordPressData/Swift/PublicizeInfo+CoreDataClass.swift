import Foundation
import CoreData
import WordPressKit

/// `PublicizeInfo` encapsulates the information related to Jetpack Social auto-sharing.
///
/// WP.com sites will not have a `PublicizeInfo`, and currently doesn't have auto-sharing limitations.
/// Furthermore, sites eligible for unlimited sharing will still return a `PublicizeInfo` along with its sharing
/// limitations, but the numbers should be ignored (at least for now).
///
@objc(PublicizeInfo)
public class PublicizeInfo: NSManagedObject {

    public var sharingLimit: SharingLimit {
        SharingLimit(remaining: Int(sharesRemaining), limit: Int(shareLimit))
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PublicizeInfo> {
        return NSFetchRequest<PublicizeInfo>(entityName: "PublicizeInfo")
    }

    @nonobjc public class func newObject(in context: NSManagedObjectContext) -> PublicizeInfo? {
        return NSEntityDescription.insertNewObject(forEntityName: Self.entityName(), into: context) as? PublicizeInfo
    }

    public func configure(with remote: RemotePublicizeInfo) {
        self.shareLimit = Int64(remote.shareLimit)
        self.toBePublicizedCount = Int64(remote.toBePublicizedCount)
        self.sharedPostsCount = Int64(remote.sharedPostsCount)
        self.sharesRemaining = Int64(remote.sharesRemaining)
    }

    /// A value-type representation for Publicize auto-sharing usage.
    public struct SharingLimit {
        /// The remaining shares available for use.
        public let remaining: Int

        /// Maximum number of shares allowed for the site.
        public let limit: Int
    }
}
