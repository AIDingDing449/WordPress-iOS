import Foundation

public enum BuildSettingsEnvironment: Sendable {
    case live
    case preview
    case test

    public static let current: BuildSettingsEnvironment = {
#if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.isXcodePreview {
            return .preview
        }
        if processInfo.isTesting {
            return .test
        }
#endif
        return .live
    }()
}

private extension ProcessInfo {
    var isXcodePreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" || environment["WP_USE_PREVIEW_ENVIRONMENT"] == "1"
    }

    var isTesting: Bool {
        if environment.keys.contains("XCTestBundlePath") { return true }
        if environment.keys.contains("XCTestConfigurationFilePath") { return true }
        if environment.keys.contains("XCTestSessionIdentifier") { return true }

        return arguments.contains { argument in
            let path = URL(fileURLWithPath: argument)
            return path.lastPathComponent == "swiftpm-testing-helper"
            || argument == "--testing-library"
            || path.lastPathComponent == "xctest"
            || path.pathExtension == "xctest"
        }
    }
}
