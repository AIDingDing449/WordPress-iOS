import Foundation
import WordPressData

// MARK: - Factory

extension MediaService {
    class Factory {
        func create(_ context: NSManagedObjectContext) -> MediaService {
            return MediaService(managedObjectContext: context)
        }
    }
}
