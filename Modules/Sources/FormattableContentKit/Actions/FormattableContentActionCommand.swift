import UIKit

/// Abstracts the logic behind contextual actions that can be applied to FormattableContent.
///
public protocol FormattableContentActionCommand: CustomStringConvertible {
    var identifier: Identifier { get }
    var on: Bool { get set }

    var actionTitle: String? { get }
    var actionColor: UIColor? { get }

    func execute<ContentType: FormattableContent>(context: ActionContext<ContentType>)
}

extension FormattableContentActionCommand {
    public static func commandIdentifier() -> Identifier {
        return Identifier(value: String(describing: self))
    }
}

extension FormattableContentActionCommand {
    public var description: String {
        return identifier.description
    }
}
