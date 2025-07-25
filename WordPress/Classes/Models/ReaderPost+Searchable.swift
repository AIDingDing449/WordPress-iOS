import Foundation
import WordPressData

extension ReaderPost: @retroactive SearchableItemConvertable {
    public var searchItemType: SearchItemType {
        return .readerPost
    }

    public var isSearchable: Bool {
        return true
    }

    public var searchIdentifier: String? {
        guard let postID, postID.intValue > 0 else {
            return nil
        }
        return postID.stringValue
    }

    public var searchDomain: String? {
        guard let siteID, siteID.intValue > 0 else {
            return nil
        }
        return siteID.stringValue
    }

    public var searchTitle: String? {
        var title = titleForDisplay() ?? ""
        if title.isEmpty {
            // If titleForDisplay() happens to be empty, try using the content preview instead...
            title = contentPreviewForDisplay()
        }
        return title
    }

    public var searchDescription: String? {
        guard let readerPostPreview = contentPreviewForDisplay(), !readerPostPreview.isEmpty else {
            return blogURL ?? contentForDisplay()
        }
        return readerPostPreview
    }

    public var searchKeywords: [String]? {
        return generateKeywordsFromContent()
    }

    public var searchExpirationDate: Date? {
        let oneWeekFromNow = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
        return oneWeekFromNow
    }
}

// MARK: - Private Helper Functions

fileprivate extension ReaderPost {
    func generateKeywordsFromContent() -> [String]? {
        var keywords: [String]? = nil
        if let postTitle {
            // Try to generate some keywords from the title...
            keywords = postTitle.components(separatedBy: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        } else if !contentPreviewForDisplay().isEmpty {
            // ...otherwise try to generate some keywords from the content preview
            keywords = contentPreviewForDisplay().components(separatedBy: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        }
        return keywords
    }
}
