import Foundation

@objc(ReaderSearchTopic)
open class ReaderSearchTopic: ReaderAbstractTopic {
    override open class var TopicType: String {
        return "search"
    }
}
