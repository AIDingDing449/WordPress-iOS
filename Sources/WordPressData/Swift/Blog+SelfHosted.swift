import Foundation
import CryptoKit
import WordPressAPI
import WordPressShared

public extension Blog {

    enum BlogCredentialsError: Error {
        case blogUrlMissing
        case blogUrlInvalid
        case blogUsernameMissing
        case blogPasswordMissing
        case blogIdentifierMissing
        case invalidCredentialsUrl
        case invalidXmlRpcEndpoint
        case incorrectCredentials
    }

    static func createRestApiBlog(
        with details: WpApiApplicationPasswordDetails,
        restApiRootURL: URL,
        xmlrpcEndpointURL: URL,
        in contextManager: ContextManager,
        using keychainImplementation: KeychainAccessible = KeychainUtils()
    ) async throws -> TaggedManagedObjectID<Blog> {
        try await contextManager.performAndSave { context in
            let blog = Blog.lookup(username: details.userLogin, xmlrpc: xmlrpcEndpointURL.absoluteString, in: context)
                ?? Blog.createBlankBlog(in: context)
            blog.url = details.siteUrl
            blog.username = details.userLogin
            blog.restApiRootURL = restApiRootURL.absoluteString
            blog.setXMLRPCEndpoint(to: xmlrpcEndpointURL)
            blog.setSiteIdentifier(details.derivedSiteId)

            // `url` and `xmlrpc` need to be set before setting the application password.
            try blog.setApplicationToken(details.password, using: keychainImplementation)
            // We don't overwrite the `Blog.password` with the application password (`details.password`), because we want
            // the application continues to function when the application password is revoked.

            return TaggedManagedObjectID(blog)
        }
    }

    static func lookupRestApiBlog(with id: SiteIdentifier, in context: NSManagedObjectContext) throws -> Blog? {
        try BlogQuery().apiKey(is: id).blog(in: context)
    }

    static func hasRestApiBlog(with id: SiteIdentifier, in context: NSManagedObjectContext) throws -> Bool {
        BlogQuery().apiKey(is: id).count(in: context) != 0
    }

    // MARK: Type-safe wrappers
    // The underlying `Blog` object has lots of field nullability that doesn't provide guarantees about
    // which fields are present. These wrappers will `throw` if the `Blog` is invalid, allowing any dependent
    // code can be much simpler.

    /// Retrieve Application Tokens
    ///
    func getApplicationToken(using keychainImplementation: KeychainAccessible = KeychainUtils()) throws -> String {
        try keychainImplementation.getPassword(for: self.getUsername(), serviceName: self.getUrlString())
    }

    /// Delete Application Token
    ///
    func deleteApplicationToken(using keychainImplementation: KeychainAccessible = KeychainUtils()) throws {
        try? keychainImplementation.setPassword(for: self.getUsername(), to: nil, serviceName: self.getUrlString())
    }

    @available(swift, obsoleted: 1.0)
    @objc(deleteApplicationToken)
    func objc_deleteApplicationToken() {
        _ = try? deleteApplicationToken()
    }

    /// Store Application Tokens
    ///
    func setApplicationToken(
        _ newValue: String,
        using keychainImplementation: KeychainAccessible = KeychainUtils()
    ) throws {
        try keychainImplementation.setPassword(for: self.getUsername(), to: newValue, serviceName: self.getUrlString())
    }

    /// A null-safe wrapper for `Blog.username`
    func getUsername() throws -> String {
        guard let username = self.username else {
            throw BlogCredentialsError.blogUsernameMissing
        }

        return username
    }

    /// A null-safe replacement for `Blog.password(get)`
    func getPassword(using keychainImplementation: KeychainAccessible = KeychainUtils()) throws -> String {
        try keychainImplementation.getPassword(for: self.getUsername(), serviceName: self.getXMLRPCEndpoint().absoluteString)
    }

    /// A null-safe replacement for `Blog.password(set)`
    func setPassword(to newValue: String, using keychainImplementation: KeychainAccessible = KeychainUtils()) throws {
        try keychainImplementation.setPassword(for: self.getUsername(), to: newValue, serviceName: self.getXMLRPCEndpoint().absoluteString)
    }

    func wordPressClientParsedUrl() throws -> ParsedUrl {
        try ParsedUrl.parse(input: self.getUrl().absoluteString)
    }

    /// A null-and-type-safe replacement for `Blog.url(get)`
    func getUrl() throws -> URL {
        guard let stringUrl = self.url else {
            throw BlogCredentialsError.blogUrlMissing
        }

        guard let url = URL(string: stringUrl) else {
            throw BlogCredentialsError.blogUrlInvalid
        }

        return url
    }

    /// A null-safe helper for `Blog.url(get)`, when what you really want is a String
    func getUrlString() throws -> String {
        try getUrl().absoluteString
    }

    /// A type-safe helper for `Blog.url(set)` that takes a URL directly (instead of a string)
    func setUrl(_ newValue: URL) {
        self.url = newValue.absoluteString
    }

    /// A null-and-type-safe replacement for `Blog.xmlrpc(get)`
    func getXMLRPCEndpoint() throws -> URL {
        guard let urlString = self.xmlrpc, let url = URL(string: urlString) else {
            throw BlogCredentialsError.invalidXmlRpcEndpoint
        }

        return url
    }

    /// A type-safe helper for `Blog.xmlrpc(set)` that takes a URL directly (instead of a string)
    func setXMLRPCEndpoint(to newValue: URL) {
        self.xmlrpc = newValue.absoluteString
    }

    /// There's `dotComId` for WordPress.com blogs, but we don't have a good way to lookup REST API sites with a scalar value.
    ///
    /// This hack fixes that – we should never store API Keys in Core Data anyway, so we can (mis)use that field to add a unique identifier
    typealias SiteIdentifier = String

    func getSiteIdentifier() throws -> SiteIdentifier {
        guard let identifier = self.apiKey else {
            throw BlogCredentialsError.blogIdentifierMissing
        }

        return identifier
    }

    func setSiteIdentifier(_ newValue: SiteIdentifier) {
        self.apiKey = newValue
    }

    @objc var isSelfHosted: Bool {
        self.account == nil
    }

    @objc var supportsCoreRestApi: Bool {
        if case .selfHosted = try? WordPressSite(blog: self) {
            return true
        }
        return false
    }
}

public extension WpApiApplicationPasswordDetails {
    var derivedSiteId: String {
        SHA256.hash(data: Data(siteUrl.localizedLowercase.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

public enum WordPressSite {
    case dotCom(siteId: Int, authToken: String)
    case selfHosted(blogId: TaggedManagedObjectID<Blog>, apiRootURL: ParsedUrl, username: String, authToken: String)

    public init(blog: Blog) throws {
        if let account = blog.account {
            let authToken = try account.authToken ?? WPAccount.token(forUsername: account.username)
            self = .dotCom(siteId: blog.dotComID?.intValue ?? 0, authToken: authToken)
        } else {
            let url = try blog.restApiRootURL ?? blog.getUrl().appending(path: "wp-json").absoluteString
            let apiRootURL = try ParsedUrl.parse(input: url)
            self = .selfHosted(blogId: TaggedManagedObjectID(blog), apiRootURL: apiRootURL, username: try blog.getUsername(), authToken: try blog.getApplicationToken())
        }
    }
}
