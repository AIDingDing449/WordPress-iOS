import CoreData
import WordPressData
import WordPressKit

extension PublicizeService {
    /// Finds a cached `PublicizeService` matching the specified service name.
    ///
    /// - Parameter name: The name of the service. This is the `serviceID` attribute for a `PublicizeService` object.
    ///
    /// - Returns: The requested `PublicizeService` or nil.
    ///
    static func lookupPublicizeServiceNamed(_ name: String, in context: NSManagedObjectContext) throws -> PublicizeService? {
        let request = NSFetchRequest<PublicizeService>(entityName: PublicizeService.classNameWithoutNamespaces())
        request.predicate = NSPredicate(format: "serviceID = %@", name)
        return try context.fetch(request).first
    }

    @objc(lookupPublicizeServiceNamed:inContext:)
    public static func objc_lookupPublicizeServiceNamed(_ name: String, in context: NSManagedObjectContext) -> PublicizeService? {
        try? lookupPublicizeServiceNamed(name, in: context)
    }

    /// Returns an array of all cached `PublicizeService` objects.
    ///
    /// - Returns: An array of `PublicizeService`.  The array is empty if no objects are cached.
    ///
    @objc(allPublicizeServicesInContext:error:)
    public static func allPublicizeServices(in context: NSManagedObjectContext) throws -> [PublicizeService] {
        let request = NSFetchRequest<PublicizeService>(entityName: PublicizeService.classNameWithoutNamespaces())
        let sortDescriptor = NSSortDescriptor(key: "order", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        return try context.fetch(request)
    }

    /// Returns an array of all cached `PublicizeService` objects that are supported by Jetpack Social.
    ///
    /// Note that services without a `status` field from the remote will be marked as supported by default.
    ///
    /// - Parameter context: The managed object context.
    /// - Returns: An array of `PublicizeService`. The array is empty if no objects are cached.
    static func allSupportedServices(in context: NSManagedObjectContext) throws -> [PublicizeService] {
        let request = NSFetchRequest<PublicizeService>(entityName: PublicizeService.classNameWithoutNamespaces())
        let sortDescriptor = NSSortDescriptor(key: "order", ascending: true)
        request.predicate = NSPredicate(format: "status == %@", Self.defaultStatus)
        request.sortDescriptors = [sortDescriptor]
        return try context.fetch(request)
    }
}
