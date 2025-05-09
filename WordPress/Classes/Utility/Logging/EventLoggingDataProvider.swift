import BuildSettingsKit
import Foundation
import AutomatticTracks
import AutomatticEncryptedLogs
import CocoaLumberjack

struct EventLoggingDataProvider: EventLoggingDataSource {

    typealias LogFilesCallback = (() -> [URL])

    /// A block that returns all existing log files
    private let fetchLogFiles: LogFilesCallback?

    let loggingAuthenticationToken: String
    let loggingEncryptionKey: String

    /// Initialize the data provider using a block.
    ///
    /// Because the most recent log file path can change at runtime, we must determine which is the most recent log file each time we access it.
    /// For example: if a given session spans a day boundary the logging system may roll the log file transparently in the background.
    init(
        loggingAuthenticationToken: String = BuildSettings.current.secrets.oauth.secret,
        loggingEncryptionKey: String = BuildSettings.current.secrets.encryptedLogsKey,
        _ block: @escaping LogFilesCallback
    ) {
        self.loggingAuthenticationToken = loggingAuthenticationToken
        self.loggingEncryptionKey = loggingEncryptionKey
        self.fetchLogFiles = block
    }

    /// The current session log will almost always be the correct one, because they're split by day
    func logFilePath(forErrorLevel: EventLoggingErrorType, at date: Date) -> URL? {
        return fetchLogFiles?().first
    }

    static func fromDDFileLogger(_ logger: DDFileLogger) -> EventLoggingDataSource {
        EventLoggingDataProvider {
            logger.logFileManager.sortedLogFileInfos.map {
                URL(fileURLWithPath: $0.filePath)
            }
        }
    }
}
