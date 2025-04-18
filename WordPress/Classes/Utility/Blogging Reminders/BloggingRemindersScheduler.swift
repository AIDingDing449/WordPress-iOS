import Foundation
import BuildSettingsKit
import WordPressData

protocol NotificationScheduler {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationScheduler {
}

protocol PushNotificationAuthorizer {
    func requestAuthorization(completion: @escaping (_ allowed: Bool) -> Void)
}

extension InteractiveNotificationsManager: PushNotificationAuthorizer {
}

/// Main interface for scheduling blogging reminders
///
class BloggingRemindersScheduler {

    // MARK: - Convenience Typealiases

    typealias ScheduledReminders = BloggingRemindersStore.ScheduledReminders
    typealias ScheduledWeekday = BloggingRemindersStore.ScheduledWeekday
    typealias ScheduledWeekdaysWithTime = BloggingRemindersStore.ScheduledWeekdaysWithTime

    // MARK: - Error Handling

    enum Error: Swift.Error {
        case needsPermissionForPushNotifications
    }

    // MARK: - Schedule Data Containers

    enum Schedule: Equatable {
        /// No reminder schedule.
        ///
        case none

        /// Weekdays reminders
        ///
        case weekdays(_ days: [Weekday])

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.weekdays(let leftArray), .weekdays(let rightArray)):
                return leftArray.count == rightArray.count && leftArray.sorted() == rightArray.sorted()
            default:
                return false
            }
        }
    }

    /// The raw values have been selected for convenience, so that they perfectly match Apple's
    /// index for weekday symbol methods, such as `Calendar.weekdaySymbols`.
    ///
    enum Weekday: Int, Codable, Comparable, CaseIterable {
        case sunday = 0
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday

        /// The default reminder hour.  In the future we may want to replace this constant with a more customizable approach.
        ///
        static let defaultHour = 10

        static func < (lhs: BloggingRemindersScheduler.Weekday, rhs: BloggingRemindersScheduler.Weekday) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Scheduler State

    /// The store for persisting our schedule.
    ///
    private let store: BloggingRemindersStore

    /// The notification scheduler
    ///
    private let notificationScheduler: NotificationScheduler

    /// Push notifications authorizer
    ///
    private let pushNotificationAuthorizer: PushNotificationAuthorizer

    private let coreDataStack: CoreDataStackSwift

    /// The time of the day when blogging reminders will be received for the given blog
    /// - Parameter blog: the given blog
    /// - Returns: the time of the day
    func scheduledTime(for blog: Blog) -> Date {
        switch scheduledReminders(for: blog) {
        case .weekDaysWithTime(let daysWithTime):
            return daysWithTime.time
        default:
            let defaultTime = Calendar.current.date(from: DateComponents(calendar: Calendar.current, hour: Weekday.defaultHour, minute: 0)) ?? Date()
            guard FeatureFlag.bloggingPrompts.enabled else {
                return defaultTime
            }

            return coreDataStack.performQuery { [blogID = blog.objectID] context in
                if let blogInContext = try? context.existingObject(with: blogID) as? Blog,
                   let settings = try? BloggingPromptSettings.of(blogInContext),
                   settings.promptRemindersEnabled,
                   let reminderTimeDate = settings.reminderTimeDate() {
                    return reminderTimeDate
                }
                return defaultTime
            }
        }
    }

    /// Active schedule.
    ///
    func schedule(for blog: Blog) -> Schedule {
        switch scheduledReminders(for: blog) {
        case .none:
            return .none
        case .weekdays(let days):
            return .weekdays(days.map({ $0.weekday }))
        case .weekDaysWithTime(let daysWithTime):
            return .weekdays(daysWithTime.days.map({ $0.weekday }))
        }
    }

    // MARK: - Default Store

    private static func defaultStore() throws -> BloggingRemindersStore {
        let url = try defaultDataFileURL()
        return try BloggingRemindersStore(dataFileURL: url)
    }

    private static var defaultDataFileName = "BloggingReminders.plist"

    private static func defaultDataFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
            .appendingPathComponent(defaultDataFileName)
    }

    private static func sharedDataFileURL(appGroupName: String) -> URL? {
        let sharedDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        return sharedDirectory?.appendingPathComponent(defaultDataFileName)
    }

    static func handleRemindersMigration(appGroupName: String = BuildSettings.current.appGroupName) {
        if AppConfiguration.isWordPress {
            copyStoreToSharedFile(appGroupName: appGroupName)
        } else if AppConfiguration.isJetpack {
            copyStoreToLocalFile(appGroupName: appGroupName)
        }
    }

    /// Deletes backup reminders if it exists.
    ///
    static func deleteBackupReminders(appGroupName: String) {
        guard let sharedFileURL = sharedDataFileURL(appGroupName: appGroupName) else {
            return
        }

        try? FileManager.default.removeItem(at: sharedFileURL)
    }

    private static func copyStoreToSharedFile(appGroupName: String) {
        guard let store = try? defaultStore(),
              let sharedFileUrl = sharedDataFileURL(appGroupName: appGroupName) else {
            return
        }

        ContextManager.shared.performAndSave { context in
            var configuration = [String: ScheduledReminders]()
            for (blogIdentifier, schedule) in store.configuration {
                guard let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: blogIdentifier),
                      let blog = context.object(with: objectID) as? Blog,
                      let url = blog.url else {
                    continue
                }
                configuration[url] = schedule
            }

            if configuration.count > 0 {
                try? PropertyListEncoder().encode(configuration).write(to: sharedFileUrl)
            }
        }
    }

    private static func copyStoreToLocalFile(appGroupName: String) {
        guard let localStore = try? defaultStore(),
              let sharedFileUrl = sharedDataFileURL(appGroupName: appGroupName),
              FileManager.default.fileExists(at: sharedFileUrl),
              let data = try? Data(contentsOf: sharedFileUrl),
              let sharedConfig = try? PropertyListDecoder().decode([String: ScheduledReminders].self, from: data) else {
            return
        }

        // Only copy if the existing local store contains no schedules
        if localStore.configuration.count == 0 {
            ContextManager.shared.performAndSave { context in
                for (blogUrl, schedule) in sharedConfig {
                    guard let blog = try? BlogQuery().hostname(matching: blogUrl).blog(in: context) else {
                        continue
                    }
                    let blogIdentifier = blog.objectID.uriRepresentation()
                    try? localStore.save(scheduledReminders: schedule, for: blogIdentifier)
                }
                try? FileManager.default.removeItem(at: sharedFileUrl)
            }
        }
    }

    // MARK: - Initializers

    /// Default initializer.  Allows overriding the blogging reminders store and the notification center for testing purposes.
    ///
    ///  - Parameters:
    ///     - store: The `BloggingRemindersStore` to use for persisting the reminders schedule.
    ///     - notificationCenter: The `NotificationScheduler` to use for the notification requests.
    ///     - pushNotificationAuthorizer: The `PushNotificationAuthorizer` to use for push notification authorization.
    ///
    init(
        store: BloggingRemindersStore,
        notificationCenter: NotificationScheduler = UNUserNotificationCenter.current(),
        pushNotificationAuthorizer: PushNotificationAuthorizer = InteractiveNotificationsManager.shared,
        coreDataStack: CoreDataStackSwift = ContextManager.shared
    ) {
            self.store = store
            self.notificationScheduler = notificationCenter
            self.pushNotificationAuthorizer = pushNotificationAuthorizer
            self.coreDataStack = coreDataStack
    }

    /// Default initializer.  Allows overriding the blogging reminders store and the notification center for testing purposes.
    ///
    ///  - Parameters:
    ///     - blogIdentifier, the blog identifier.  This is necessary since we support blogging reminders for multiple blogs.
    ///     - notificationCenter: The `NotificationScheduler` to use for the notification requests.
    ///     - pushNotificationAuthorizer: The `PushNotificationAuthorizer` to use for push notification authorization.
    ///
    init(
        notificationCenter: NotificationScheduler = UNUserNotificationCenter.current(),
        pushNotificationAuthorizer: PushNotificationAuthorizer = InteractiveNotificationsManager.shared,
        coreDataStack: CoreDataStackSwift = ContextManager.shared
    ) throws {
        self.store = try Self.defaultStore()
        self.notificationScheduler = notificationCenter
        self.pushNotificationAuthorizer = pushNotificationAuthorizer
        self.coreDataStack = coreDataStack
    }

    // MARK: - Scheduling

    /// Main method for scheduling blogging reminder notifications.  This method will take care of scheduling the local notifications and
    /// persisting the user-defined reminder schedule.
    ///
    /// - Parameters:
    ///     - schedule: the blogging reminders schedule.
    ///
    func schedule(_ schedule: Schedule, for blog: Blog, time: Date? = nil, completion: @escaping (Result<Void, Swift.Error>) -> ()) {
        guard schedule != .none else {
            // If there's no schedule, then we don't need to request authorization
            pushAuthorizationReceived(blog: blog, schedule: schedule, time: time, completion: completion)
            return
        }

        let blogObjectID = blog.objectID
        pushNotificationAuthorizer.requestAuthorization { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self else { return }
                guard allowed else {
                    completion(.failure(Error.needsPermissionForPushNotifications))
                    return
                }
                do {
                    let blog = try self.coreDataStack.mainContext.existingObject(with: blogObjectID) as! Blog
                    self.pushAuthorizationReceived(blog: blog, schedule: schedule, time: time, completion: completion)
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    /// You should not be calling this method directly.  Instead, make sure to use `schedule(_:completion:)`.
    ///
    private func pushAuthorizationReceived(blog: Blog, schedule: Schedule, time: Date?, completion: (Result<Void, Swift.Error>) -> ()) {
        unschedule(scheduledReminders(for: blog))

        let scheduledReminders: BloggingRemindersStore.ScheduledReminders

        switch schedule {
        case .none:
            scheduledReminders = .none
        case .weekdays(let days):
            guard let time else {
                scheduledReminders = .weekdays(scheduled(days, for: blog))
                break
            }
            scheduledReminders = .weekDaysWithTime(scheduledWithTime(days, time: time, for: blog))
        }

        do {
            try store.save(scheduledReminders: scheduledReminders, for: blog.objectID.uriRepresentation())
        } catch {
            completion(.failure(error))
            return
        }

        completion(.success(()))
    }

    /// Schedules a notifications for the passed days, and returns another array with the days and their
    /// associated notification IDs.
    ///
    /// - Parameters:
    ///     - weekdays: the weekdays to schedule notifications for.
    ///
    /// - Returns: the weekdays with the associated notification IDs.
    ///
    private func scheduled(_ weekdays: [Weekday], for blog: Blog) -> [ScheduledWeekday] {
        weekdays.map { scheduled($0, for: blog) }
    }

    /// Schedules a notifications for the passed days, and returns a `ScheduledWeekdaysWithTime` instance
    ///  containing the scheduling time and an array of `ScheduledWeekday`
    /// - Parameters:
    ///   - weekdays: the weekdays to schedule notifications for.
    ///   - time: the time of the day when the notification will be received
    private func scheduledWithTime(_ weekdays: [Weekday], time: Date, for blog: Blog) -> ScheduledWeekdaysWithTime {
        ScheduledWeekdaysWithTime(time: time, days: weekdays.map { scheduled($0, time: time, for: blog) })
    }

    /// Schedules a notification for the passed day, and returns the day with the associated notification ID.
    ///
    /// - Parameters:
    ///     - weekday: the weekday to schedule a notification for.
    ///
    /// - Returns: the weekday with the associated notification ID.
    ///
    private func scheduled(_ weekday: Weekday, time: Date? = nil, for blog: Blog) -> ScheduledWeekday {
        let notificationID = scheduleNotification(for: weekday, time: time, blog: blog)
        return ScheduledWeekday(weekday: weekday, notificationID: notificationID)
    }

    /// Schedules a notification for the specified weekday.
    ///
    private func scheduleNotification(for weekday: Weekday, time: Date?, blog: Blog) -> String {
        let content = UNMutableNotificationContent()
        if let title = blog.title {
            content.title = String(format: TextContent.notificationTitle, title)
        } else {
            content.title = TextContent.noTitleNotificationTitle
        }
        content.body = TextContent.notificationBody
        content.categoryIdentifier = InteractiveNotificationsManager.NoteCategoryDefinition.bloggingReminderWeekly.rawValue
        if let blogID = blog.dotComID?.stringValue {
            content.threadIdentifier = blogID
        }

        var dateComponents = DateComponents()
        let calendar = Calendar.current
        dateComponents.calendar = calendar

        // `DateComponent`'s weekday uses a 1-based index.
        dateComponents.weekday = weekday.rawValue + 1
        dateComponents.hour = time?.dateAndTimeComponents().hour ?? Weekday.defaultHour
        dateComponents.minute = time?.dateAndTimeComponents().minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)

        notificationScheduler.add(request) { (error) in
            if let error {
                DDLogError("\(error)")
            }
        }

        return uuidString
    }

    // MARK: - Unscheduling
    func unschedule(for blogs: [Blog]) {
        for blog in blogs {
            unschedule(for: blog)
        }
    }

    func unschedule(for blog: Blog) {
        schedule(.none, for: blog, completion: { _ in })
    }

    /// Unschedules all notifications for the passed schedule.
    ///
    private func unschedule(_ schedule: ScheduledReminders) {
        switch schedule {
        case .none:
            return
        case .weekdays(let days):
            unschedule(days)
        case .weekDaysWithTime(let daysWithTime):
            unschedule(daysWithTime.days)
        }
    }

    /// Unschedules all notiication for the specified days.
    ///
    private func unschedule(_ days: [ScheduledWeekday]) {
        let notificationIDs = days.map { $0.notificationID }

        notificationScheduler.removePendingNotificationRequests(withIdentifiers: notificationIDs)
    }

    // MARK: - Scheduled Reminders

    private func scheduledReminders(for blog: Blog) -> ScheduledReminders {
        store.scheduledReminders(for: blog.objectID.uriRepresentation())
    }

    private enum TextContent {
        static let noTitleNotificationTitle = NSLocalizedString("It's time to blog!", comment: "Title of a notification displayed prompting the user to create a new blog post")
        static let notificationTitle = NSLocalizedString("It's time to blog on %@!",
                                                         comment: "Title of a notification displayed prompting the user to create a new blog post. The %@ will be replaced with the blog's title.")
        static let notificationBody = NSLocalizedString("This is your reminder to blog today ✍️", comment: "The body of a notification displayed to the user prompting them to create a new blog post. The emoji should ideally remain, as part of the text.")
    }
}

extension BloggingPromptSettingsReminderDays {

    func getActiveWeekdays() -> [BloggingRemindersScheduler.Weekday] {
        return [
            sunday,
            monday,
            tuesday,
            wednesday,
            thursday,
            friday,
            saturday
        ].enumerated().compactMap { (index: Int, isReminderActive: Bool) in
            guard isReminderActive else {
                return nil
            }
            return BloggingRemindersScheduler.Weekday(rawValue: index)
        }
    }
}
