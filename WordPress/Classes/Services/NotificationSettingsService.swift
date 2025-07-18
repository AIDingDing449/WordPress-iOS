import Foundation
import BuildSettingsKit
import WordPressData
import WordPressKit
import WordPressShared

/// This service encapsulates the Restful API related to WordPress Notifications.
///
class NotificationSettingsService {
    // MARK: - Aliases
    public typealias Channel = NotificationSettings.Channel
    public typealias Stream = NotificationSettings.Stream

    /// Designated Initializer
    ///
    /// - Parameter managedObjectContext: A Reference to the MOC that should be used to interact with the Core Data Stack.
    ///
    public convenience init(coreDataStack: CoreDataStack) {
        let remoteApi = coreDataStack.performQuery { context -> WordPressComRestApi? in
            guard let defaultAccount = try? WPAccount.lookupDefaultWordPressComAccount(in: context),
                  defaultAccount.authToken != nil,
                  let restApi = defaultAccount.wordPressComRestApi,
                  restApi.hasCredentials() else {
                return nil
            }
            return restApi
        }
        self.init(coreDataStack: coreDataStack, wordPressComRestApi: remoteApi)
    }

    /// Convenience Initializer. Useful for Unit Testing
    ///
    /// - Parameters:
    ///     - managedObjectContext: A Reference to the MOC that should be used to interact with the Core Data Stack.
    ///     - wordPressComRestApi: The WordPressComRestApi that should be used.
    ///
    public init(coreDataStack: CoreDataStack, wordPressComRestApi: WordPressComRestApi?) {
        self.coreDataStack = coreDataStack
        self.remoteApi = wordPressComRestApi
    }

    /// This method will retrieve all of the Notification Settings for the default WordPress.com account
    ///
    /// - Parameters:
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    open func getAllSettings(_ success: (([NotificationSettings]) -> Void)?, failure: ((NSError?) -> Void)?) {
        notificationsServiceRemote?.getAllSettings(deviceId,
            success: { remote in
                let parsed = self.settingsFromRemote(remote)

                for settings in parsed {
                    guard let blog = settings.blog,
                          let pushNotificationStream = settings.streams.first(where: { $0.kind == .device }),
                          let preferences = pushNotificationStream.preferences else {

                        continue
                    }

                    let localSettings = self.loadLocalSettings(for: blog)

                    let updatedPreferences = preferences.merging(localSettings) { first, second in
                        second
                    }

                    pushNotificationStream.preferences = updatedPreferences
                }

                success?(parsed)
            },
            failure: failure)
    }

    private func userDefaultsKey(withNotificationSettingKey key: String, for blog: Blog) -> String {
        "\(key)-\(blog.objectID.uriRepresentation().absoluteString)"
    }

    private func loadLocalSettings(for blog: Blog) -> [String: Bool] {
        var localSettings = [String: Bool]()

        for key in NotificationSettings.locallyStoredKeys {
            let userDefaultsKey = userDefaultsKey(withNotificationSettingKey: key, for: blog)
            let value = (UserPersistentStoreFactory.instance().object(forKey: userDefaultsKey) as? Bool) ?? true

            localSettings[key] = value
        }

        return localSettings
    }

    private func saveLocalSettings(_ settings: [String: Bool], blog: Blog) {
        for (key, value) in settings {
            if NotificationSettings.isLocallyStored(key) {
                UserPersistentStoreFactory.instance().set(value, forKey: userDefaultsKey(withNotificationSettingKey: key, for: blog))
            }
        }
    }

    /// Updates the specified NotificationSettings's Stream, with a collection of new values.
    ///
    /// - Parameters:
    ///     - settings: The NotificationSettings to be updated.
    ///     - stream: Reference to the specific Settings Stream to update.
    ///     - newValues: The collection of new values to be submited.
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    open func updateSettings(_ settings: NotificationSettings, stream: Stream, newValues: [String: Bool], success: (() -> ())?, failure: ((NSError?) -> Void)?) {

        let remote = remoteFromSettings(newValues, channel: settings.channel, stream: stream)
        let pristine = stream.preferences

        // Preemptively Update the new settings
        for (key, value) in newValues {
            stream.preferences?[key] = value
        }

        if let preferences = stream.preferences,
           let blog = settings.blog {
            saveLocalSettings(preferences, blog: blog)
        }

        notificationsServiceRemote?.updateSettings(remote as [String: AnyObject],
            success: {
                success?()
            },
            failure: { (error: NSError?) in
                // Fall back to Pristine Settings
                stream.preferences = pristine
                failure?(error)
            })
    }

    /// Registers a given Push Notifications Token against the WordPress.com backend.
    ///
    /// - Parameters:
    ///     - token: Apple's Push Notifications Device Token
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    @objc open func registerDeviceForPushNotifications(_ token: String, success: ((_ deviceId: String) -> ())?, failure: ((NSError) -> Void)?) {
        if token.isEmpty {
            DDLogWarn("Error: registerDeviceForPushNotifications called with an empty token!")
            return
        }

        notificationsServiceRemote?.registerDeviceForPushNotifications(
            token,
            pushNotificationAppId: BuildSettings.current.pushNotificationAppID,
            success: success,
            failure: failure
        )
    }

    /// Unregisters the given deviceID for Push Notification Events.
    ///
    /// - Parameters:
    ///     - deviceId: Identifier of the device to be unregistered
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    @objc open func unregisterDeviceForPushNotifications(_ deviceId: String, success: (() -> ())?, failure: ((NSError) -> Void)?) {
        if deviceId.isEmpty {
            DDLogWarn("Error: unregisterDeviceForPushNotifications called with an empty deviceId!")
            return
        }

        notificationsServiceRemote?.unregisterDeviceForPushNotifications(deviceId, success: success, failure: failure)
    }

    /// Static Helper that will parse RemoteNotificationSettings instances into a collection of
    /// NotificationSettings instances.
    ///
    /// - Parameters:
    ///     - remoteSettings: Array of RemoteNotificationSettings
    ///
    /// - Returns: An array of NotificationSettings objects
    ///
    fileprivate func settingsFromRemote(_ remoteSettings: [RemoteNotificationSettings]) -> [NotificationSettings] {
        var parsed = [NotificationSettings]()
        let blogs = ((try? BlogQuery().blogs(in: coreDataStack.mainContext)) ?? []).filter { $0.dotComID != nil }
        let blogMap = Dictionary(blogs.map { ($0.dotComID!.intValue, $0) }, uniquingKeysWith: { _, new in new })

        for remoteSetting in remoteSettings {
            let channel = channelFromRemote(remoteSetting.channel)
            let streams = streamsFromRemote(remoteSetting.streams)
            let blog = blogForChannel(channel, blogMap: blogMap)
            let settings = NotificationSettings(channel: channel, streams: streams, blog: blog)

            parsed.append(settings)
        }

        return parsed
    }

    /// Helper method to convert RemoteNotificationSettings.Channel into a NotificationSettings.Channel enum.
    ///
    /// - Parameter remote: An instance of the RemoteNotificationSettings.Channel enum
    ///
    /// - Returns: Instance of NotificationSettings.Channel Enum
    ///
    fileprivate func channelFromRemote(_ remote: RemoteNotificationSettings.Channel) -> NotificationSettings.Channel {
        switch remote {
        case let .blog(blogId):
            return .blog(blogId: blogId)
        case .other:
            return .other
        case .wordPressCom:
            return .wordPressCom
        }
    }

    /// Helper method that will parse RemoteNotificationSettings.Stream instances into a collection of
    /// NotificationSettings.Stream instances.
    ///
    /// - Parameter remote: Array of RemoteNotificationSettings.Stream
    ///
    /// - Returns: An array of NotificationSettings.Stream
    ///
    fileprivate func streamsFromRemote(_ remote: [RemoteNotificationSettings.Stream]) -> [NotificationSettings.Stream] {
        var parsed = Array<NotificationSettings.Stream>()

        for remoteStream in remote {
            let kind = remoteStream.kind.rawValue
            let stream = NotificationSettings.Stream(kind: kind, preferences: remoteStream.preferences)
            parsed.append(stream)
        }

        return parsed
    }

    /// Helper method that filters the Blog associated with a specific Channel, if any.
    ///
    /// - Parameters:
    ///     - channel: An instance of the RemoteNotificationSettings.Channel enum
    ///     - blogMap: A Map of Blog entities, with their BlogID's as keys
    ///
    /// - Returns: Instance of the associated Blog, if any
    ///
    fileprivate func blogForChannel(_ channel: NotificationSettings.Channel, blogMap: [Int: Blog]?) -> Blog? {
        // We reuse a Blog Map by ID, since it's actually one order of magnitude faster than fetching
        // each time.
        switch channel {
        case let .blog(blogId):
            return blogMap?[blogId]
        default:
            return nil
        }
    }

    /// Transforms a collection of Settings into a format that's the one expected by the backend,
    /// depending on whether the channel is a Site (will post the Site ID), Other or WordPress.com
    ///
    /// - Parameters:
    ///     - settings: A collection of the settings that need to be updated
    ///     - channel: A reference to the Chanel that must be updated
    ///     - stream: A reference to the Stream that must be updated
    ///
    /// - Returns: Dictionary of values, as expected by the Backend, for the specified Channel and Stream.
    ///
    fileprivate func remoteFromSettings(_ settings: [String: Bool], channel: Channel, stream: Stream) -> [String: Any] {
        var wrappedSettings: Any = settings as Any
        var streamKey = stream.kind.rawValue

        switch stream.kind {
        case .device:
            // Devices require a special structure:
            // The backend actually expects an array of dictionaries of devices, each one with its own
            // device_id set.
            //
            var updatedSettings = settings as [String: AnyObject]
            updatedSettings["device_id"] = deviceId as AnyObject?

            // Done!
            streamKey = "devices"
            wrappedSettings = [updatedSettings]
        default:
            break
        }

        // Prepare the Remote Settings Dictionary
        switch channel {
        case let .blog(blogId):
            return [
                "blogs": [
                    [   "blog_id": blogId,
                        streamKey: wrappedSettings
                    ]
                ]
            ]
        case .other:
            return [
                "other": [
                    streamKey: wrappedSettings
                ]
            ]
        case .wordPressCom:
            return [ "wpcom": wrappedSettings ]
        }
    }

    // MARK: - Private Properties
    fileprivate var remoteApi: WordPressComRestApi?
    private let coreDataStack: CoreDataStack

    // MARK: - Private Computed Properties
    fileprivate var notificationsServiceRemote: NotificationSettingsServiceRemote? {
        guard let remoteApi else {
            return nil
        }

        return NotificationSettingsServiceRemote(wordPressComRestApi: remoteApi)
    }

    fileprivate var deviceId: String {
        return PushNotificationsManager.shared.deviceId ?? String()
    }
}
