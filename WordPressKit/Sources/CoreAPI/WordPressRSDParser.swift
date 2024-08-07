import Foundation

/// An WordPressRSDParser is able to parse an RSD file and search for the XMLRPC WordPress url.
open class WordPressRSDParser: NSObject, XMLParserDelegate {

    private let parser: XMLParser
    private var endpoint: String?

    @objc init?(xmlString: String) {
        guard let data = xmlString.data(using: String.Encoding.utf8) else {
            return nil
        }
        parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
    }

    func parsedEndpoint() throws -> String? {
        if parser.parse() {
            return endpoint
        }
        // Return the 'WordPress' API link, if found.
        if let endpoint {
            return endpoint
        }
        guard let error = parser.parserError else {
            return nil
        }
        throw error
    }

    // MARK: - NSXMLParserDelegate
    open func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                                namespaceURI: String?,
                                qualifiedName qName: String?,
                                              attributes attributeDict: [String: String]) {
        if elementName == "api" {
            if let apiName = attributeDict["name"], apiName == "WordPress" {
                if let endpoint = attributeDict["apiLink"] {
                    self.endpoint = endpoint
                } else {
                    parser.abortParsing()
                }
            }
        }
    }

    open func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // WPKitLogInfo("Error parsing RSD: \(parseError)")
    }

}
