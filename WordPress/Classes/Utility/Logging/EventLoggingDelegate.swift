import Foundation
import AutomatticTracks
import AutomatticEncryptedLogs
import BuildSettingsKit
import WordPressData

struct EventLoggingDelegate: AutomatticEncryptedLogs.EventLoggingDelegate {

    var shouldUploadLogFiles: Bool {
        guard BuildSettingsEnvironment.current != .test else {
            return false
        }

        return
            !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !UserSettings.userHasOptedOutOfCrashLogging
    }

    func didQueueLogForUpload(_ log: LogFile) {
        NotificationCenter.default.post(name: WPLoggingStack.QueuedLogsDidChangeNotification, object: log)
        DDLogDebug("📜 Added log to queue: \(log.uuid)")

        DispatchQueue.main.async {
            guard let eventLogging = WordPressAppDelegate.eventLogging else {
                return
            }

            DDLogDebug("📜\t There are \(eventLogging.queuedLogFiles.count) logs in the queue.")
        }
    }

    func didStartUploadingLog(_ log: LogFile) {
        NotificationCenter.default.post(name: WPLoggingStack.QueuedLogsDidChangeNotification, object: log)
        DDLogDebug("📜 Started uploading encrypted log: \(log.uuid)")
    }

    func didFinishUploadingLog(_ log: LogFile) {
        NotificationCenter.default.post(name: WPLoggingStack.QueuedLogsDidChangeNotification, object: log)
        DDLogDebug("📜 Finished uploading encrypted log: \(log.uuid)")

        DispatchQueue.main.async {
            guard let eventLogging = WordPressAppDelegate.eventLogging else {
                return
            }

            DDLogDebug("📜\t There are \(eventLogging.queuedLogFiles.count) logs remaining in the queue.")
        }
    }

    func uploadFailed(withError error: Error, forLog log: LogFile) {
        NotificationCenter.default.post(name: WPLoggingStack.QueuedLogsDidChangeNotification, object: log)
        DDLogError("📜 Error uploading encrypted log: \(log.uuid)")
        DDLogError("📜\t\(error.localizedDescription)")

        let nserror = error as NSError
        DDLogError("📜\t Code: \(nserror.code)")
        if let details = nserror.localizedFailureReason {
            DDLogError("📜\t Details: \(details)")
        }
    }
}
