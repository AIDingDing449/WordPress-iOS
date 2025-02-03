import Foundation
import WordPressAPI

public struct InstalledPlugin: Equatable, Hashable, Identifiable, Sendable {
    public var slug: PluginSlug
    public var iconURL: URL?
    public var name: String
    public var version: String
    public var author: String
    public var shortDescription: String

    public init(slug: PluginSlug, iconURL: URL?, name: String, version: String, author: String, shortDescription: String) {
        self.slug = slug
        self.iconURL = iconURL
        self.name = name
        self.version = version
        self.author = author
        self.shortDescription = shortDescription
    }

    public init(plugin: PluginWithViewContext) {
        self.slug = plugin.plugin
        iconURL = nil
        name = plugin.name
        version = plugin.version
        author = plugin.author
        shortDescription = plugin.description.raw
    }

    public var id: String {
        slug.slug
    }

    public var possibleWpOrgDirectorySlug: PluginWpOrgDirectorySlug? {
        guard let maybeWpOrgSlug = slug.slug.split(separator: "/").first else { return nil }
        return .init(slug: String(maybeWpOrgSlug))
    }
}
