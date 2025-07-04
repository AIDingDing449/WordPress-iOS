import Foundation
import WordPressData
import WordPressShared

typealias ReaderSiteSearchSuccessBlock = (_ feeds: [ReaderFeed], _ hasMore: Bool, _ feedCount: Int) -> Void
typealias ReaderSiteSearchFailureBlock = (_ error: Error?) -> Void

/// Allows searching for sites / feeds in the Reader.
///
class ReaderSiteSearchService {

    let coreDataStack: CoreDataStackSwift

    init(coreDataStack: CoreDataStackSwift) {
        self.coreDataStack = coreDataStack
    }

    // The size of a single page of results when performing a search.
    static let pageSize = 20

    private func apiRequest() -> WordPressComRestApi {
        let api = coreDataStack.performQuery {
            try? WPAccount.defaultWordPressComAccountRestAPI(in: $0)
        }

        if let api, api.hasCredentials() {
            return api
        }

        return WordPressComRestApi.defaultApi(oAuthToken: nil, userAgent: WPUserAgent.wordPress())
    }

    /// Performs a search for sites / feeds matching the specified query.
    ///
    /// - Parameters:
    ///     - query: The phrase to search for
    ///     - page: Results are requested in pages. Use this to specify which
    ///             page of results to return. 0 indexed.
    ///     - success: Success block called on a successful search. Parameters
    ///                are a list of ReaderFeeds, a bool for `hasMore` (are there
    ///                more feeds to fetch), and a total feed count.
    ///     - failure: Failure block called on a failed search.
    ///
    func performSearch(with query: String,
                       page: Int,
                       success: @escaping ReaderSiteSearchSuccessBlock,
                       failure: @escaping ReaderSiteSearchFailureBlock) {
        let remote = ReaderSiteSearchServiceRemote(wordPressComRestApi: apiRequest())
        remote.performSearch(query,
                             offset: page * Constants.pageSize,
                             count: Constants.pageSize,
                             success: { (feeds, hasMore, feedCount) in
            success(feeds, hasMore, feedCount)
        }, failure: { error in
            DDLogError("Error while performing Reader site search: \(String(describing: error))")
            failure(error)
        })
    }

    private enum Constants {
        static let pageSize = 20
    }
}
