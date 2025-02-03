import Foundation
@preconcurrency import Combine
import WordPressShared
import WordPressAPI

public protocol InstalledPluginDataStore: DataStore where T == InstalledPlugin, Query == PluginDataStoreQuery {
}

public enum PluginDataStoreQuery: Equatable, Sendable {
    case all
}

public actor InMemoryInstalledPluginDataStore: InstalledPluginDataStore, InMemoryDataStore {
    public typealias T = InstalledPlugin

    public var storage: [T.ID: T] = [:]
    public let updates: PassthroughSubject<Set<T.ID>, Never> = .init()

    deinit {
        updates.send(completion: .finished)
    }

    public init() {}

    public func list(query: Query) throws -> [T] {
        switch query {
        case .all:
            return storage.values.sorted(using: KeyPathComparator(\.slug.slug))
        }
    }
}
