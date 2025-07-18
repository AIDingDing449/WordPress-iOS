import FormattableContentKit
import WordPressData

extension SubjectContentGroup {

    class func createGroup(from subject: [[String: AnyObject]], parent: WordPressData.Notification) -> FormattableContentGroup {
        let blocks = NotificationContentFactory.content(from: subject, actionsParser: NotificationActionParser(), parent: parent)
        return FormattableContentGroup(blocks: blocks, kind: .subject)
    }
}
