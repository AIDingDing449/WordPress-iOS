import Foundation
import WordPressData

@objc public protocol ReaderStreamHeaderDelegate {
    func handleFollowActionForHeader(_ header: ReaderStreamHeader, completion: @escaping () -> Void)
}

@objc public protocol ReaderStreamHeader {
    weak var delegate: ReaderStreamHeaderDelegate? {get set}
    func configureHeader(_ topic: ReaderAbstractTopic)
}
