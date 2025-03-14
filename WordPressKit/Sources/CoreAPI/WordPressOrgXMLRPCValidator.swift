import Foundation

@objc public enum WordPressOrgXMLRPCValidatorError: Int, Error {
    case emptyURL // The URL provided was nil, empty or just whitespaces
    case invalidURL // The URL provided was an invalid URL
    case invalidScheme // The URL provided was an invalid scheme, only HTTP and HTTPS supported
    case notWordPressError // That's a XML-RPC endpoint but doesn't look like WordPress
    case mobilePluginRedirectedError // There's some "mobile" plugin redirecting everything to their site
    case forbidden = 403 // Server returned a 403 error while reading xmlrpc file
    case blocked = 405 // Server returned a 405 error while reading xmlrpc file
    case invalid // Doesn't look to be valid XMLRPC Endpoint.
    case xmlrpc_missing // site contains RSD link but XML-RPC information is missing

    public var localizedDescription: String {
        switch self {
        case .emptyURL:
            return NSLocalizedString("Empty URL", comment: "Message to show to user when he tries to add a self-hosted site that is an empty URL.")
        case .invalidURL:
            return NSLocalizedString("Invalid URL, please check if you wrote a valid site address.", comment: "Message to show to user when he tries to add a self-hosted site that isn't a valid URL.")
        case .invalidScheme:
            return NSLocalizedString("Invalid URL scheme inserted, only HTTP and HTTPS are supported.", comment: "Message to show to user when he tries to add a self-hosted site that isn't HTTP or HTTPS.")
        case .notWordPressError:
            return NSLocalizedString("That doesn't look like a WordPress site.", comment: "Message to show to user when he tries to add a self-hosted site that isn't a WordPress site.")
        case .mobilePluginRedirectedError:
            return NSLocalizedString(
                "You seem to have installed a mobile plugin from DudaMobile which is preventing the app to connect to your blog",
                comment: "Error messaged show when a mobile plugin is redirecting traffict to their site, DudaMobile in particular"
            )
        case .invalid:
            return NSLocalizedString("Couldn't connect to the WordPress site. There is no valid WordPress site at this address. Check the site address (URL) you entered.", comment: "Error message shown a URL points to a valid site but not a WordPress site.")
        case .blocked:
            return NSLocalizedString("Couldn't connect. Your host is blocking POST requests, and the app needs that in order to communicate with your site. Please contact your hosting provider to solve this problem.", comment: "Message to show to user when he tries to add a self-hosted site but the host returned a 405 error, meaning that the host is blocking POST requests on /xmlrpc.php file.")
        case .forbidden:
            return NSLocalizedString("Couldn't connect. We received a 403 error when trying to access your site's XMLRPC endpoint. The app needs that in order to communicate with your site. Please contact your hosting provider to solve this problem.", comment: "Message to show to user when he tries to add a self-hosted site but the host returned a 403 error, meaning that the access to the /xmlrpc.php file is forbidden.")
        case .xmlrpc_missing:
            return NSLocalizedString("Couldn't connect. Required XML-RPC methods are missing on the server. Please contact your hosting provider to solve this problem.", comment: "Message to show to user when he tries to add a self-hosted site with RSD link present, but xmlrpc is missing.")
        }
    }
}

extension WordPressOrgXMLRPCValidatorError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription
    }
}

/// An WordPressOrgXMLRPCValidator is able to validate and check if user provided site urls are
/// WordPress XMLRPC sites.
open class WordPressOrgXMLRPCValidator: NSObject {

    // The documentation for NSURLErrorHTTPTooManyRedirects says that 16
    // is the default threshold for allowable redirects.
    private let redirectLimit = 16

    private let appTransportSecuritySettings: AppTransportSecuritySettings

    override public init() {
        appTransportSecuritySettings = AppTransportSecuritySettings()
        super.init()
    }

    init(_ appTransportSecuritySettings: AppTransportSecuritySettings) {
        self.appTransportSecuritySettings = appTransportSecuritySettings
        super.init()
    }

    /**
     Validates and check if user provided site urls are WordPress XMLRPC sites and returns the API endpoint.

     - parameter site:      the user provided site URL
     - parameter userAgent: user agent for anonymous .com API to check if a site is a Jetpack site
     - parameter success:   completion handler that is invoked when the site is considered valid,
     the xmlrpcURL argument is the endpoint
     - parameter failure: completion handler that is invoked when the site is considered invalid,
     the error object provides details why the endpoint is invalid
     */
    @objc open func guessXMLRPCURLForSite(_ site: String,
                                    userAgent: String,
                                      success: @escaping (_ xmlrpcURL: URL) -> Void,
                                      failure: @escaping (_ error: NSError) -> Void) {

        var sitesToTry = [String]()

        let secureAccessOnly: Bool = {
            if let url = URL(string: site) {
                return appTransportSecuritySettings.secureAccessOnly(for: url)
            }
            return true
        }()

        if site.hasPrefix("http://") {
            if !secureAccessOnly {
                sitesToTry.append(site)
            }
            sitesToTry.append(site.replacingOccurrences(of: "http://", with: "https://"))
        } else if site.hasPrefix("https://") {
            sitesToTry.append(site)
            if !secureAccessOnly {
                sitesToTry.append(site.replacingOccurrences(of: "https://", with: "http://"))
            }
        } else {
            failure(WordPressOrgXMLRPCValidatorError.invalidScheme as NSError)
            return
        }

        tryGuessXMLRPCURLForSites(sitesToTry, userAgent: userAgent, success: success, failure: failure)
    }

    /// Helper for `guessXMLRPCURLForSite(_:userAgent:success:failure)`
    /// Tries to guess the XMLRPC url for all the sites string given in the sites array
    /// If all of them fail, it will call `failure` with the error in the last url string.
    ///
    private func tryGuessXMLRPCURLForSites(_ sites: [String],
                                          userAgent: String,
                                          success: @escaping (_ xmlrpcURL: URL) -> Void,
                                          failure: @escaping (_ error: NSError) -> Void) {

        guard sites.isEmpty == false else {
            failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
            return
        }

        var mutableSites = sites
        let nextSite = mutableSites.removeFirst()

        func errorHandler(_ error: NSError) {
            if mutableSites.isEmpty {
                failure(error)
            } else {
                tryGuessXMLRPCURLForSites(mutableSites, userAgent: userAgent, success: success, failure: failure)
            }
        }

        let originalXMLRPCURL: URL
        let xmlrpcURL: URL
        do {
            xmlrpcURL = try urlForXMLRPCFromURLString(nextSite, addXMLRPC: true)
            originalXMLRPCURL = try urlForXMLRPCFromURLString(nextSite, addXMLRPC: false)
        } catch let error as NSError {
            // WPKitLogError(error.localizedDescription)
            errorHandler(error)
            return
        }

        validateXMLRPCURL(xmlrpcURL, success: success, failure: { (error) in
            // WPKitLogError(error.localizedDescription)
            if (error.domain == NSURLErrorDomain && error.code == NSURLErrorUserCancelledAuthentication) ||
                (error.domain == NSURLErrorDomain && error.code == NSURLErrorCannotFindHost) ||
                (error.domain == NSURLErrorDomain && error.code == NSURLErrorNetworkConnectionLost) ||
                (error.domain == String(reflecting: WordPressOrgXMLRPCValidatorError.self) && error.code == WordPressOrgXMLRPCValidatorError.mobilePluginRedirectedError.rawValue) {
                errorHandler(error)
                return
            }
            // Try the original given url as an XML-RPC endpoint
            // WPKitLogError("Try the original given url as an XML-RPC endpoint: \(originalXMLRPCURL)")
            self.validateXMLRPCURL(originalXMLRPCURL, success: success, failure: { (error) in
                // WPKitLogError(error.localizedDescription)
                // Fetch the original url and look for the RSD link
                self.guessXMLRPCURLFromHTMLURL(originalXMLRPCURL, success: success, failure: { (error) in
                    // WPKitLogError(error.localizedDescription)

                    errorHandler(error)
                })
            })
        })
    }

    private func urlForXMLRPCFromURLString(_ urlString: String, addXMLRPC: Bool) throws -> URL {
        var resultURLString = urlString
        // Is an empty url? Sorry, no psychic powers yet
        resultURLString = urlString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if resultURLString.isEmpty {
            throw WordPressOrgXMLRPCValidatorError.emptyURL
        }

        // Check if it's a valid URL
        // Not a valid URL. Could be a bad protocol (htpp://), syntax error (http//), ...
        // See https://github.com/koke/NSURL-Guess for extra help cleaning user typed URLs
        guard let baseURL = URL(string: resultURLString) else {
            throw WordPressOrgXMLRPCValidatorError.invalidURL
        }

        // Let's see if a scheme is provided and it's HTTP or HTTPS
        var scheme = baseURL.scheme!.lowercased()
        if scheme.isEmpty {
            resultURLString = "http://\(resultURLString)"
            scheme = "http"
        }

        guard scheme == "http" || scheme == "https" else {
            throw WordPressOrgXMLRPCValidatorError.invalidScheme
        }

        if baseURL.lastPathComponent != "xmlrpc.php" && addXMLRPC {
            // Assume the given url is the home page and XML-RPC sits at /xmlrpc.php
            // WPKitLogInfo("Assume the given url is the home page and XML-RPC sits at /xmlrpc.php")
            resultURLString = "\(resultURLString)/xmlrpc.php"
        }

        guard let url = URL(string: resultURLString) else {
            throw WordPressOrgXMLRPCValidatorError.invalid
        }

        return url
    }

    private func validateXMLRPCURL(_ url: URL,
                                   redirectCount: Int = 0,
                                   success: @escaping (_ xmlrpcURL: URL) -> Void,
                                   failure: @escaping (_ error: NSError) -> Void) {

        guard redirectCount < redirectLimit else {
            let error = NSError(domain: URLError.errorDomain,
                                code: URLError.httpTooManyRedirects.rawValue,
                                userInfo: nil)
            failure(error)
            return
        }
        let api = WordPressOrgXMLRPCApi(endpoint: url)
        api.callMethod("system.listMethods", parameters: nil, success: { (responseObject, httpResponse) in
                guard let methods = responseObject as? [String], methods.contains("wp.getUsersBlogs") else {
                    failure(WordPressOrgXMLRPCValidatorError.notWordPressError as NSError)
                        return
                }
                if let finalURL = httpResponse?.url {
                    success(finalURL)
                } else {
                    failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
                }
            }, failure: { (error, httpResponse) in
                if httpResponse?.url != url {
                    // we where redirected, let's check the answer content
                    if let data = error.userInfo[WordPressOrgXMLRPCApi.WordPressOrgXMLRPCApiErrorKeyData as String] as? Data,
                        let responseString = String(data: data, encoding: String.Encoding.utf8), responseString.range(of: "<meta name=\"GENERATOR\" content=\"www.dudamobile.com\">") != nil
                            || responseString.range(of: "dm404Container") != nil {
                        failure(WordPressOrgXMLRPCValidatorError.mobilePluginRedirectedError as NSError)
                        return
                    }
                    // If it's a redirect to the same host
                    // and the response is a '405 Method Not Allowed'
                    if let responseUrl = httpResponse?.url,
                        responseUrl.host == url.host
                        && httpResponse?.statusCode == 405 {
                        // Then it's likely a good redirect, but the POST
                        // turned into a GET.
                        // Let's retry the request at the new URL.
                        self.validateXMLRPCURL(responseUrl, redirectCount: redirectCount + 1, success: success, failure: failure)
                        return
                    }
                }

                switch httpResponse?.statusCode {
                case .some(WordPressOrgXMLRPCValidatorError.forbidden.rawValue):
                    failure(WordPressOrgXMLRPCValidatorError.forbidden as NSError)
                case .some(WordPressOrgXMLRPCValidatorError.blocked.rawValue):
                    failure(WordPressOrgXMLRPCValidatorError.blocked as NSError)
                default:
                    failure(error)
                }
            })
    }

    private func guessXMLRPCURLFromHTMLURL(_ htmlURL: URL,
                                           success: @escaping (_ xmlrpcURL: URL) -> Void,
                                           failure: @escaping (_ error: NSError) -> Void) {
        // WPKitLogInfo("Fetch the original url and look for the RSD link by using RegExp")

        var isWpSite = false
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        let dataTask = session.dataTask(with: htmlURL, completionHandler: { (data, _, error) in
            if let error = error {
                failure(error as NSError)
                return
            }
            guard let data = data,
                  let responseString = String(data: data, encoding: String.Encoding.utf8),
                  let rsdURL = self.extractRSDURLFromHTML(responseString)
            else {
                    failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
                return
            }

            // If the site contains RSD link, it is WP.org site
            isWpSite = true

            // Try removing "?rsd" from the url, it should point to the XML-RPC endpoint
            let xmlrpc = rsdURL.replacingOccurrences(of: "?rsd", with: "")
            if xmlrpc != rsdURL {
                guard let newURL = URL(string: xmlrpc) else {
                    failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
                    return
                }
                self.validateXMLRPCURL(newURL, success: success, failure: { (error) in
                    // Try to validate by using the RSD file directly
                    if error.code == 403 || error.code == 405, let xmlrpcValidatorError = error as? WordPressOrgXMLRPCValidatorError {
                        failure(xmlrpcValidatorError as NSError)
                    } else {
                        let validatorError = isWpSite ? WordPressOrgXMLRPCValidatorError.xmlrpc_missing :
                                                        WordPressOrgXMLRPCValidatorError.invalid
                            failure(validatorError as NSError)
                    }
                })
            } else {
                // Try to validate by using the RSD file directly
                self.guessXMLRPCURLFromRSD(rsdURL, success: success, failure: failure)
            }
        })
        dataTask.resume()
    }

    private func extractRSDURLFromHTML(_ html: String) -> String? {
        guard let rsdURLRegExp = try? NSRegularExpression(pattern: "<link\\s+rel=\"EditURI\"\\s+type=\"application/rsd\\+xml\"\\s+title=\"RSD\"\\s+href=\"([^\"]*)\"[^/]*/>",
                                                          options: [.caseInsensitive])
            else {
                return nil
        }

        let matches = rsdURLRegExp.matches(in: html,
                                                   options: NSRegularExpression.MatchingOptions(),
                                                   range: NSRange(location: 0, length: html.count))
        if matches.count <= 0 {
            return nil
        }

#if swift(>=4.0)
        let rsdURLRange = matches[0].range(at: 1)
#else
        let rsdURLRange = matches[0].rangeAt(1)
#endif

        if rsdURLRange.location == NSNotFound {
            return nil
        }
        let rsdURL = (html as NSString).substring(with: rsdURLRange)
        return rsdURL
    }

    private func guessXMLRPCURLFromRSD(_ rsd: String,
                                       success: @escaping (_ xmlrpcURL: URL) -> Void,
                                       failure: @escaping (_ error: NSError) -> Void) {
        // WPKitLogInfo("Parse the RSD document at the following URL: \(rsd)")
        guard let rsdURL = URL(string: rsd) else {
            failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        let dataTask = session.dataTask(with: rsdURL, completionHandler: { (data, _, error) in
            if let error = error {
                failure(error as NSError)
                return
            }
            guard let data = data,
                let responseString = String(data: data, encoding: String.Encoding.utf8),
                let parser = WordPressRSDParser(xmlString: responseString),
                let xmlrpc = try? parser.parsedEndpoint(),
                let xmlrpcURL = URL(string: xmlrpc)
                else {
                    failure(WordPressOrgXMLRPCValidatorError.invalid as NSError)
                    return
            }
            // WPKitLogInfo("Bingo! We found the WordPress XML-RPC element: \(xmlrpcURL)")
            self.validateXMLRPCURL(xmlrpcURL, success: success, failure: failure)
        })
        dataTask.resume()
    }
}
