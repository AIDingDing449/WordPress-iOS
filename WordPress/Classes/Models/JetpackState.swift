import Foundation

@objcMembers public class JetpackState: NSObject {
    public static let minimumVersionRequired = "3.4.3"

    public var siteID: NSNumber?
    public var version: String?
    public internal(set) var connectedUsername: String?
    public internal(set) var connectedEmail: String?
    var automatedTransfer: Bool = false

    /// Returns true if Jetpack is installed and activated on the site.
    public var isInstalled: Bool {
        return version != nil
    }

    /// Returns true if Jetpack is connected to WordPress.com.
    ///
    /// - Warning: Before Jetpack 3.6, a site might appear connected if it was connected and then disconnected. See https://github.com/Automattic/jetpack/issues/2137
    ///
    public var isConnected: Bool {
        guard isInstalled,
            let siteID,
            siteID.intValue > 0 else {
                return false
        }
        return true
    }

    /// Return true is Jetpack has site-connection (Jetpack plugin connected to the site but not connected to WP.com account)
    public var isSiteConnection: Bool {
        let isUserConnected = connectedUsername != nil || connectedEmail != nil

        return isConnected && !isUserConnected
    }

    /// Returns YES if the detected version meets the app requirements.

    /// - SeeAlso: JetpackVersionMinimumRequired
    ///
    public var isUpdatedToRequiredVersion: Bool {
        guard let version else {
            return false
        }
        return version.compare(JetpackState.minimumVersionRequired, options: .numeric) != .orderedAscending
    }

    public override var description: String {
        if isConnected {
            let connectedAs = connectedUsername?.nonEmptyString()
                ?? connectedEmail?.nonEmptyString()
                ?? "UNKNOWN"
            return "🚀✅ Jetpack \(version ?? "unknown") connected as \(connectedAs) with site ID \(siteID?.description ?? "unknown")"
        } else if isInstalled {
            return "🚀❌ Jetpack \(version ?? "unknown") not connected"
        } else {
            return "🚀❔Jetpack not installed"
        }
    }
}
