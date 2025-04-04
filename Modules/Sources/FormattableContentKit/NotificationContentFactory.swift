import Foundation

private enum Constants {
    static let Actions = "actions"
    static let RawType = "type"
    static let Ranges = "ranges"
}

enum ContentType: String {
    case comment
    case user
    case text
    case image
}

public class NotificationContentFactory: FormattableContentFactory {

    public static func content(from blocks: [[String: AnyObject]], actionsParser parser: FormattableContentActionParser, parent: Notifiable) -> [FormattableContent] {
        return blocks.compactMap { rawBlock in
            let actions = parser.parse(rawBlock[Constants.Actions] as? [String: AnyObject])
            let ranges = rangesFrom(rawBlock)

            guard let type = rawBlock[Constants.RawType] as? String else {
                return NotificationTextContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
            }
            return content(for: type, with: rawBlock, actions: actions, ranges: ranges, parent: parent)
        }
    }

    private static func rangesFrom(_ rawBlock: [String: AnyObject]) -> [FormattableContentRange] {
        let rawRanges = rawBlock[Constants.Ranges] as? [[String: AnyObject]]
        let parsed = rawRanges?.compactMap(NotificationContentRangeFactory.contentRange)
        return parsed ?? []
    }

    private static func content(for type: String, with rawBlock: [String: AnyObject], actions: [FormattableContentAction], ranges: [FormattableContentRange], parent: Notifiable) -> FormattableContent? {
        guard let type = ContentType(rawValue: type) else {
            return NotificationTextContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
        }

        switch type {
        case .comment:
            return FormattableCommentContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
        case .user:
            return FormattableUserContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
        case .text:
            return NotificationTextContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
        case .image:
            return NotificationTextContent(dictionary: rawBlock, actions: actions, ranges: ranges, parent: parent)
        }
    }
}
