import SwiftUI
import UIKit
import WordPressData
import WordPressShared

/// Encapsulates logic related to Jetpack Social in the pre-publishing sheet.
///
extension PrepublishingViewController {

    /// Determines whether the account and the post's blog is eligible to see the Jetpack Social row.
    func canDisplaySocialRow(isJetpack: Bool = AppConfiguration.isJetpack,
                             isFeatureEnabled: Bool = RemoteFeatureFlag.jetpackSocialImprovements.enabled()) -> Bool {
        guard isJetpack &&
                isFeatureEnabled &&
                !isPostPrivate &&
                hasPublicizeServices &&
                post.blog.supportsPublicize()
        else {
            return false
        }

        guard hasExistingConnections else {
            // if the site has no connections, ensure that the No Connection view hasn't been dismissed before.
            return !isNoConnectionDismissed
        }

        return true
    }

    func configureSocialCell(_ cell: UITableViewCell) {
        if hasExistingConnections {
            configureAutoSharingView(for: cell)
        } else {
            configureNoConnectionView(for: cell)
        }
    }

    func didTapAutoSharingCell() {
        guard let postBlogID,
              hasExistingConnections else {
            return
        }

        let model = makeAutoSharingModel()
        let socialAccountsViewController = PrepublishingSocialAccountsViewController(blogID: postBlogID,
                                                                                     model: model,
                                                                                     delegate: self,
                                                                                     coreDataStack: coreDataStack)

        self.navigationController?.pushViewController(socialAccountsViewController, animated: true)
    }
}

// MARK: - Helper Methods

private extension PrepublishingViewController {

    /// Convenience variable representing whether the No Connection view has been dismissed.
    /// Note: the value is stored per site.
    var isNoConnectionDismissed: Bool {
        get {
            guard let postBlogID,
                  let dictionary = persistentStore.dictionary(forKey: Constants.noConnectionKey) as? [String: Bool],
                  let storedValue = dictionary["\(postBlogID)"] else {
                return false
            }
            return storedValue
        }

        set {
            guard let postBlogID else {
                return
            }
            var dictionary = (persistentStore.dictionary(forKey: Constants.noConnectionKey) as? [String: Bool]) ?? .init()
            dictionary["\(postBlogID)"] = newValue
            persistentStore.set(dictionary, forKey: Constants.noConnectionKey)
        }
    }

    var hasPublicizeServices: Bool {
        coreDataStack.performQuery { context in
            guard let services = (try? PublicizeService.allSupportedServices(in: context)) else {
                return false
            }
            return !services.isEmpty
        }
    }

    var hasExistingConnections: Bool {
        coreDataStack.performQuery { [postObjectID = post.objectID] context in
            guard let post = (try? context.existingObject(with: postObjectID)) as? Post,
                  let connections = post.blog.connections else {
                return false
            }
            return !connections.isEmpty
        }
    }

    var isPostPrivate: Bool {
        coreDataStack.performQuery { [postObjectID = post.objectID] context in
            guard let post = (try? context.existingObject(with: postObjectID)) as? Post else {
                return false
            }
            return post.status == .publishPrivate
        }
    }

    // MARK: Auto Sharing View

    func configureAutoSharingView(for cell: UITableViewCell) {
        let viewModel = makeAutoSharingModel()
        let viewToEmbed = UIView.embedSwiftUIView(PrepublishingAutoSharingView(model: viewModel))

        viewToEmbed.translatesAutoresizingMaskIntoConstraints = false
        cell.selectionStyle = .default
        cell.contentView.addSubview(viewToEmbed)
        cell.contentView.pinSubviewToAllEdgeMargins(viewToEmbed)

        cell.accessoryType = .disclosureIndicator

        if let _ = viewModel.sharingLimit {
            WPAnalytics.track(.jetpackSocialShareLimitDisplayed, properties: ["source": Constants.trackingSource])
        }
    }

    // MARK: - No Connection View

    func configureNoConnectionView(for cell: UITableViewCell) {
        let viewModel = makeNoConnectionViewModel()
        guard let viewToEmbed = JetpackSocialNoConnectionView.createHostController(with: viewModel).view else {
            return
        }

        viewToEmbed.translatesAutoresizingMaskIntoConstraints = false
        cell.selectionStyle = .none
        cell.contentView.addSubview(viewToEmbed)
        cell.contentView.pinSubviewToAllEdgeMargins(viewToEmbed)

        WPAnalytics.track(.jetpackSocialNoConnectionCardDisplayed, properties: ["source": Constants.trackingSource])
    }

    func makeNoConnectionViewModel() -> JetpackSocialNoConnectionViewModel {
        let context = post.managedObjectContext ?? coreDataStack.mainContext
        let insets = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        guard let services = try? PublicizeService.allSupportedServices(in: context) else {
            return .init(padding: insets)
        }

        return .init(services: services,
                     padding: insets,
                     preferredBackgroundColor: tableView.backgroundColor,
                     onConnectTap: noConnectionConnectTapped(),
                     onNotNowTap: noConnectionDismissTapped())
    }

    /// A closure to be executed when the Connect button is tapped in the No Connection view.
    func noConnectionConnectTapped() -> () -> Void {
        return { [weak self] in
            guard let self,
                  let controller = SharingViewController(blog: self.post.blog, delegate: self),
                  self.presentedViewController == nil else {
                return
            }

            WPAnalytics.track(.jetpackSocialNoConnectionCTATapped, properties: ["source": Constants.trackingSource])

            let navigationController = UINavigationController(rootViewController: controller)
            self.show(navigationController, sender: nil)
        }
    }

    /// A closure to be executed when the "Not now" button is tapped in the No Connection view.
    func noConnectionDismissTapped() -> () -> Void {
        return { [weak self] in
            guard let self,
                  let autoSharingRowIndex = options.firstIndex(where: { $0.id == .autoSharing }) else {
                return
            }

            WPAnalytics.track(.jetpackSocialNoConnectionCardDismissed, properties: ["source": Constants.trackingSource])

            self.isNoConnectionDismissed = true
            self.refreshOptions()

            // ensure that the `.autoSharing` identifier is truly removed to prevent table updates from crashing.
            guard options.firstIndex(where: { $0.id == .autoSharing }) == nil else {
                return
            }

            self.tableView.performBatchUpdates {
                self.tableView.deleteRows(at: [.init(row: autoSharingRowIndex, section: .zero)], with: .fade)
            } completion: { _ in }
        }
    }

    // MARK: - Model Creation

    func makeAutoSharingModel() -> PrepublishingAutoSharingModel {
        return coreDataStack.performQuery { [postObjectID = post.objectID] context in
            guard let post = (try? context.existingObject(with: postObjectID)) as? Post,
                  let supportedServices = try? PublicizeService.allSupportedServices(in: context) else {
                return .init(services: [], message: String(), sharingLimit: nil)
            }
            let connections = post.blog.sortedConnections

            // first, build a dictionary to categorize the connections.
            var connectionsMap = [PublicizeService.ServiceName: [PublicizeConnection]]()
            connections.filter { !$0.requiresUserAction() }.forEach { connection in
                let serviceName = PublicizeService.ServiceName(rawValue: connection.service) ?? .unknown
                var serviceConnections = connectionsMap[serviceName] ?? []
                serviceConnections.append(connection)
                connectionsMap[serviceName] = serviceConnections
            }

            // then, transform [PublicizeService] to [PrepublishingAutoSharingModel.Service].
            let modelServices = supportedServices.compactMap { service -> PrepublishingAutoSharingModel.Service? in
                // skip services without connections.
                guard let serviceConnections = connectionsMap[service.name],
                      !serviceConnections.isEmpty else {
                    return nil
                }

                return PrepublishingAutoSharingModel.Service(
                    name: service.name,
                    connections: serviceConnections.map {
                        .init(account: $0.externalDisplay,
                              keyringID: $0.keyringConnectionID.intValue,
                              enabled: !post.publicizeConnectionDisabledForKeyringID($0.keyringConnectionID))
                    }
                )
            }

            return .init(services: modelServices,
                         message: post.publicizeMessage ?? post.titleForDisplay(),
                         sharingLimit: post.blog.sharingLimit)
        }
    }

    // MARK: - Constants

    enum Constants {
        static let trackingSource = "pre_publishing"
        static let noConnectionKey = "prepublishing-social-no-connection-view-hidden"
    }
}

// MARK: - Auto Sharing Model

/// A value-type representation of `PublicizeService` for the current blog that's simplified for the auto-sharing flow.
struct PrepublishingAutoSharingModel {
    let services: [Service]
    let message: String
    let sharingLimit: PublicizeInfo.SharingLimit?

    struct Service: Hashable {
        let name: PublicizeService.ServiceName
        let connections: [Connection]
    }

    struct Connection: Hashable {
        let account: String
        let keyringID: Int
        var enabled: Bool
    }
}

// MARK: - Sharing View Controller Delegate

extension PrepublishingViewController: SharingViewControllerDelegate {

    func didChangePublicizeServices() {
        reloadData()
    }

}

// MARK: - Prepublishing Social Accounts Delegate

extension PrepublishingViewController: PrepublishingSocialAccountsDelegate {

    func didUpdateSharingLimit(with newValue: PublicizeInfo.SharingLimit?) {
        reloadData()
    }

    func didFinish(with connectionChanges: [Int: Bool], message: String?) {
        DispatchQueue.main.async {
            self._didFinish(with: connectionChanges, message: message)
        }
    }

    private func _didFinish(with connectionChanges: [Int: Bool], message: String?) {
        guard let post = post as? Post else {
            wpAssertionFailure("invalid post type")
            return
        }
        connectionChanges.forEach { (keyringID, enabled) in
            if enabled {
                post.enablePublicizeConnectionWithKeyringID(NSNumber(value: keyringID))
            } else {
                post.disablePublicizeConnectionWithKeyringID(NSNumber(value: keyringID))
            }
        }

        let isMessageEmpty = message?.isEmpty ?? true
        post.publicizeMessage = isMessageEmpty ? nil : message

        reloadData()
    }
}
