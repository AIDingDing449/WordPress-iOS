// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [
        .iOS(.v16),
    ],
    products: XcodeSupport.products + [
        .library(name: "AsyncImageKit", targets: ["AsyncImageKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "FormattableContentKit", targets: ["FormattableContentKit"]),
        .library(name: "JetpackStatsWidgetsCore", targets: ["JetpackStatsWidgetsCore"]),
        .library(name: "NotificationServiceExtensionCore", targets: ["NotificationServiceExtensionCore"]),
        .library(name: "ShareExtensionCore", targets: ["ShareExtensionCore"]),
        .library(name: "SFHFKeychainUtils", targets: ["SFHFKeychainUtils"]),
        .library(name: "WordPressFlux", targets: ["WordPressFlux"]),
        .library(name: "WordPressShared", targets: ["WordPressShared"]),
        .library(name: "WordPressUI", targets: ["WordPressUI"]),
        .library(name: "WordPressReader", targets: ["WordPressReader"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.4.0"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.1"),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", from: "9.1.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/Automattic/Automattic-Tracks-iOS", from: "3.5.2"),
        .package(url: "https://github.com/Automattic/AutomatticAbout-swift", from: "1.1.5"),
        .package(url: "https://github.com/Automattic/Gravatar-SDK-iOS", from: "3.4.0"),
        .package(url: "https://github.com/Automattic/Gridicons-iOS", branch: "develop"),
        .package(url: "https://github.com/Automattic/ScreenObject", from: "0.3.0"),
        .package(url: "https://github.com/buildkite/test-collector-swift", from: "0.3.0"),
        .package(url: "https://github.com/ChartsOrg/Charts", from: "5.0.0"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.8.5"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.8"),
        .package(url: "https://github.com/erikdoe/ocmock", revision: "2c0bfd373289f4a7716db5d6db471640f91a6507"),
        .package(url: "https://github.com/johnxnguyen/Down", branch: "master"),
        .package(url: "https://github.com/kaishin/Gifu", from: "3.4.1"),
        .package(url: "https://github.com/Quick/Nimble", from: "10.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", exact: "2.7.5"),
        .package(url: "https://github.com/squarefrog/UIDeviceIdentifier", from: "2.3.0"),
        .package(url: "https://github.com/SVProgressHUD/SVProgressHUD", from: "2.3.1"),
        .package(url: "https://github.com/Automattic/Reachability", branch: "framework-support-via-spm"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
        .package(url: "https://github.com/wordpress-mobile/FSInteractiveMap", from: "0.3.0"),
        .package(url: "https://github.com/wordpress-mobile/MediaEditor-iOS", branch: "task/spm-support"),
        .package(url: "https://github.com/wordpress-mobile/NSObject-SafeExpectations", from: "0.0.6"),
        .package(url: "https://github.com/wordpress-mobile/NSURL-IDN", revision: "b34794c9a3f32312e1593d4a3d120572afa0d010"),
        .package(
            url: "https://github.com/wordpress-mobile/WordPressKit-iOS",
            revision: "ae3961ce89ac0c43a90e88d4963a04aa92008443" // see wpios-edition branch
        ),
        .package(url: "https://github.com/zendesk/support_sdk_ios", from: "8.0.3"),
        // We can't use wordpress-rs branches nor commits here. Only tags work.
        .package(url: "https://github.com/Automattic/wordpress-rs", revision: "alpha-20250715"),
        .package(url: "https://github.com/wordpress-mobile/GutenbergKit", from: "0.4.1"),
        .package(
            url: "https://github.com/Automattic/color-studio",
            revision: "bf141adc75e2769eb469a3e095bdc93dc30be8de"
        ),
        .package(url: "https://github.com/wordpress-mobile/AztecEditor-iOS", from: "1.20.0"),
    ],
    targets: XcodeSupport.targets + [
        .target(name: "AsyncImageKit", dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "Gifu", package: "Gifu"),
        ]),
        .target(name: "AztecExtensions", dependencies: [
            "WordPressShared",
            .product(name: "Gridicons", package: "Gridicons-iOS"),
            .product(name: "Aztec", package: "AztecEditor-iOS"),
        ], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "BuildSettingsKit"),
        .target(
            name: "DesignSystem",
            dependencies: [
                "BuildSettingsKit",
                .product(name: "ColorStudio", package: "color-studio"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "FormattableContentKit",
            dependencies: [
                "WordPressShared",
                "WordPressUI",
                .product(name: "Gridicons", package: "Gridicons-iOS"),
                // TODO: Remove — It's here just for a NSMutableParagraphStyle init helper
                .product(name: "WordPressKit", package: "WordPressKit-iOS"),
            ],
            // Set to v5 to avoid @Sendable warnings and errors
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(name: "JetpackStatsWidgetsCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(
            name: "ShareExtensionCore",
            dependencies: [
                "BuildSettingsKit",
                "SFHFKeychainUtils",
                "WordPressShared",
                // Even though the extension is all in Swift, we need to include the Objective-C
                // version of CocoaLumberjack to avoid linking issues with other dependencies that
                // use it.
                //
                // Example:
                //
                // Undefined symbols for architecture arm64:
                //  "_OBJC_CLASS_$_DDLog", referenced from:
                //       in SharedCoreDataStack.o
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "WordPressKit", package: "WordPressKit-iOS"),
            ],
            resources: [.process("Resources/Extensions.xcdatamodeld")]
        ),
        .target(
            name: "NotificationServiceExtensionCore",
            dependencies: ["BuildSettingsKit"]
        ),
        // SFHFKeychainUtils is an old Objective-C keychain wrapper.
        // The implementatoin predates ARC, hence the dedicated target with ARC disabled, for the time being.
        .target(
            name: "SFHFKeychainUtils",
            cSettings: [.unsafeFlags(["-fno-objc-arc"])]
        ),
        .target(name: "TextBundle"),
        .target(
            name: "TracksMini",
            dependencies: ["BuildSettingsKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(name: "UITestsFoundation", dependencies: [
            .product(name: "ScreenObject", package: "ScreenObject"),
            .product(name: "XCUITestHelpers", package: "ScreenObject"),
        ], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "WordPressFlux", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "WordPressCore", dependencies: [
                "WordPressShared",
                .product(name: "WordPressAPI", package: "wordpress-rs")
            ]
        ),
        .target(name: "WordPressLegacy", dependencies: ["DesignSystem", "WordPressShared"]),
        .target(name: "WordPressSharedObjC", resources: [.process("Resources")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(
            name: "WordPressShared",
            dependencies: [
                .product(name: "Reachability", package: "Reachability"),
                .target(name: "SFHFKeychainUtils"),
                .target(name: "WordPressSharedObjC"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(name: "WordPressTesting", resources: [.process("Resources")]),
        .target(
            name: "WordPressUI",
            dependencies: [
                "AsyncImageKit",
                "DesignSystem",
                "WordPressShared",
                "WordPressLegacy",
                .product(name: "Reachability", package: "Reachability"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "WordPressReader",
            dependencies: ["AsyncImageKit", "WordPressUI", "WordPressShared"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "JetpackStatsWidgetsCoreTests", dependencies: [.target(name: "JetpackStatsWidgetsCore")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "DesignSystemTests", dependencies: [.target(name: "DesignSystem")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "WordPressFluxTests",
            dependencies: ["WordPressFlux"],
            exclude: ["WordPressFluxTests.xctestplan"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "AsyncImageKitTests", dependencies: [
            .target(name: "AsyncImageKit"),
            .target(name: "WordPressTesting"),
            .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")
        ]),
        .testTarget(name: "WordPressSharedTests", dependencies: [.target(name: "WordPressShared")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "WordPressSharedObjCTests", dependencies: [.target(name: "WordPressShared"), .target(name: "WordPressTesting")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "WordPressUIUnitTests", dependencies: [.target(name: "WordPressUI")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "WordPressCoreTests", dependencies: [.target(name: "WordPressCore")]),
    ]
)

// MARK: - XcodeSupport (Xcode Targets)

/// The following section specifies dependencies for the respective Xcode targets.
/// You can add internal or third-party dependencies to these targets or even
/// source files and resources.
///
/// - note: SwiftPM automatically detects which modules are shared between
/// multiple targets and decides when to use dynamic frameworks.
///
/// ## Known Issues
///
///   - SwiftPM copies resource bundles from a target, including dynamic frameworks,
/// into every target that depends on it. Make sure to avoid including frameworks
/// with large resources bundled into multiple targets.
enum XcodeSupport {
    static var products: [Product] {
        [
            .library(name: "XcodeTarget_App", targets: ["XcodeTarget_App"]),
            .library(name: "XcodeTarget_Keystone", targets: ["XcodeTarget_Keystone"]),
            .library(name: "XcodeTarget_WordPressTests", targets: ["XcodeTarget_WordPressTests"]),
            .library(name: "XcodeTarget_WordPressData", targets: ["XcodeTarget_WordPressData"]),
            .library(name: "XcodeTarget_WordPressAuthentificator", targets: ["XcodeTarget_WordPressAuthentificator"]),
            .library(name: "XcodeTarget_WordPressAuthentificatorTests", targets: ["XcodeTarget_WordPressAuthentificatorTests"]),
            .library(name: "XcodeTarget_ShareExtension", targets: ["XcodeTarget_ShareExtension"]),
            .library(name: "XcodeTarget_DraftActionExtension", targets: ["XcodeTarget_DraftActionExtension"]),
            .library(name: "XcodeTarget_NotificationServiceExtension", targets: ["XcodeTarget_NotificationServiceExtension"]),
            .library(name: "XcodeTarget_Intents", targets: ["XcodeTarget_Intents"]),
            .library(name: "XcodeTarget_StatsWidget", targets: ["XcodeTarget_StatsWidget"]),
            .library(name: "XcodeTarget_UITests", targets: ["XcodeTarget_UITests"]),
        ]
    }

    static var targets: [Target] {
        let wordPresAuthentificatorDependencies: [Target.Dependency] = [
            "BuildSettingsKit",
            "WordPressShared",
            "WordPressUI",
            .product(name: "Gridicons", package: "Gridicons-iOS"),
            .product(name: "NSURL-IDN", package: "NSURL-IDN"),
            .product(name: "SVProgressHUD", package: "SVProgressHUD"),
            .product(name: "WordPressKit", package: "WordPressKit-iOS"),
            .product(name: "Gravatar", package: "Gravatar-SDK-iOS"),
            .product(name: "GravatarUI", package: "Gravatar-SDK-iOS"),
        ]

        let shareAndDraftExtensionsDependencies: [Target.Dependency] = [
            "AztecExtensions",
            "BuildSettingsKit",
            "SFHFKeychainUtils",
            "ShareExtensionCore",
            "WordPressShared",
            "WordPressUI",
            "TextBundle",
            "TracksMini",
            // Even though the extensions are all in Swift, we need to include the Objective-C
            // version of CocoaLumberjack to avoid linking issues with other dependencies that
            // use it.
            //
            // Example:
            //
            // Undefined symbols for architecture arm64:
            //  "_OBJC_CLASS_$_DDLog", referenced from:
            //       in AppExtensionsService.o
            .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            .product(name: "Down", package: "Down"),
            .product(name: "Gridicons", package: "Gridicons-iOS"),
            .product(name: "Reachability", package: "Reachability"),
            .product(name: "SVProgressHUD", package: "SVProgressHUD"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            .product(name: "Aztec", package: "AztecEditor-iOS"),
            .product(name: "WordPressEditor", package: "AztecEditor-iOS"),
        ]

        let testDependencies: [Target.Dependency] = [
            .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            .product(name: "OCMock", package: "OCMock"),
        ]

        let keystoneDependencies: [Target.Dependency] = [
            "AsyncImageKit",
            "AztecExtensions",
            "DesignSystem",
            "BuildSettingsKit",
            "FormattableContentKit",
            "JetpackStatsWidgetsCore",
            "NotificationServiceExtensionCore",
            "SFHFKeychainUtils",
            "ShareExtensionCore",
            "WordPressFlux",
            "WordPressShared",
            "WordPressLegacy",
            "WordPressReader",
            "WordPressUI",
            "WordPressCore",
            .product(name: "Alamofire", package: "Alamofire"),
            .product(name: "AutomatticAbout", package: "AutomatticAbout-swift"),
            .product(name: "AutomatticTracks", package: "Automattic-Tracks-iOS"),
            .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            .product(name: "DGCharts", package: "Charts"),
            .product(name: "Down", package: "Down"),
            .product(name: "FSInteractiveMap", package: "FSInteractiveMap"),
            .product(name: "Gifu", package: "Gifu"),
            .product(name: "Gravatar", package: "Gravatar-SDK-iOS"),
            .product(name: "GravatarUI", package: "Gravatar-SDK-iOS"),
            .product(name: "Gridicons", package: "Gridicons-iOS"),
            .product(name: "GutenbergKit", package: "GutenbergKit"),
            .product(name: "Lottie", package: "lottie-ios"),
            .product(name: "MediaEditor", package: "MediaEditor-iOS"),
            .product(name: "NSObject-SafeExpectations", package: "NSObject-SafeExpectations"),
            .product(name: "NSURL-IDN", package: "NSURL-IDN"),
            .product(name: "Reachability", package: "Reachability"),
            .product(name: "Starscream", package: "Starscream"),
            .product(name: "SVProgressHUD", package: "SVProgressHUD"),
            .product(name: "SwiftSoup", package: "SwiftSoup"),
            .product(name: "UIDeviceIdentifier", package: "UIDeviceIdentifier"),
            .product(name: "WordPressKit", package: "WordPressKit-iOS"),
            .product(name: "ZendeskSupportSDK", package: "support_sdk_ios"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            .product(name: "WordPressAPI", package: "wordpress-rs"),
            .product(name: "ColorStudio", package: "color-studio"),
            .product(name: "Aztec", package: "AztecEditor-iOS"),
            .product(name: "WordPressEditor", package: "AztecEditor-iOS"),
        ]

        return [
            .xcodeTarget("XcodeTarget_App", dependencies: keystoneDependencies),
            .xcodeTarget("XcodeTarget_Keystone", dependencies: keystoneDependencies),
            .xcodeTarget("XcodeTarget_WordPressTests", dependencies: testDependencies + [
                "WordPressShared",
                "WordPressUI",
                .product(name: "Gravatar", package: "Gravatar-SDK-iOS"),
                .product(name: "Nimble", package: "Nimble"),
                .product(name: "BuildkiteTestCollector", package: "test-collector-swift"),
                // Needed by WordPressData because of how linkage works...
                //
                "BuildSettingsKit",
                "FormattableContentKit",
                "SFHFKeychainUtils",
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "NSObject-SafeExpectations", package: "NSObject-SafeExpectations"),
                .product(name: "NSURL-IDN", package: "NSURL-IDN"),
                .product(name: "WordPressAPI", package: "wordpress-rs"),
                .product(name: "WordPressKit", package: "WordPressKit-iOS"),
            ]),
            .xcodeTarget("XcodeTarget_WordPressAuthentificator", dependencies: wordPresAuthentificatorDependencies),
            .xcodeTarget("XcodeTarget_WordPressAuthentificatorTests", dependencies: wordPresAuthentificatorDependencies + testDependencies),
            .xcodeTarget("XcodeTarget_ShareExtension", dependencies: shareAndDraftExtensionsDependencies),
            .xcodeTarget("XcodeTarget_DraftActionExtension", dependencies: shareAndDraftExtensionsDependencies),
            .xcodeTarget("XcodeTarget_NotificationServiceExtension", dependencies: [
                "BuildSettingsKit",
                "FormattableContentKit",
                "NotificationServiceExtensionCore",
                "SFHFKeychainUtils",
                "TracksMini",
                "WordPressShared",
                // Even though the extensions are all in Swift, we need to include the Objective-C
                // version of CocoaLumberjack to avoid linking issues with other dependencies that
                // use it.
                //
                // Example:
                //
                // EmitSwiftModule normal arm64 (in target 'WordPressNotificationServiceExtension' from project 'WordPress')
                //    cd /path/to/repo/WordPress
                //
                // <unknown>:0: error: missing required modules: 'CocoaLumberjack', 'CocoaLumberjackSwiftSupport'
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ]),
            .xcodeTarget("XcodeTarget_StatsWidget", dependencies: [
                "BuildSettingsKit",
                "JetpackStatsWidgetsCore",
                "SFHFKeychainUtils",
                "TracksMini",
                "WordPressShared",
                "WordPressUI",
                // Even though the extensions are all in Swift, we need to include the Objective-C
                // version of CocoaLumberjack to avoid linking issues with other dependencies that
                // use it.
                //
                // Example:
                //
                // Undefined symbols for architecture arm64:
                //  "_OBJC_CLASS_$_DDLog", referenced from:
                //       in AppExtensionsService.o
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                .product(name: "WordPressAPI", package: "wordpress-rs"),
            ]),
            .xcodeTarget("XcodeTarget_Intents", dependencies: [
                "BuildSettingsKit",
                "JetpackStatsWidgetsCore",
                // Even though the extensions are all in Swift, we need to include the Objective-C
                // version of CocoaLumberjack to avoid linking issues with other dependencies that
                // use it.
                //
                // Example:
                //
                // Undefined symbols for architecture arm64:
                //  "_OBJC_CLASS_$_DDLog", referenced from:
                //       in AppExtensionsService.o
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            ]),
            .xcodeTarget("XcodeTarget_UITests", dependencies: [
                "UITestsFoundation",
                .product(name: "BuildkiteTestCollector", package: "test-collector-swift"),
            ]),
            .xcodeTarget(
                "XcodeTarget_WordPressData",
                dependencies: [
                    "BuildSettingsKit",
                    "FormattableContentKit",
                    "SFHFKeychainUtils",
                    "WordPressShared",
                    .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
                    .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
                    .product(name: "Gravatar", package: "Gravatar-SDK-iOS"),
                    .product(name: "NSObject-SafeExpectations", package: "NSObject-SafeExpectations"),
                    .product(name: "NSURL-IDN", package: "NSURL-IDN"),
                    .product(name: "WordPressAPI", package: "wordpress-rs"),
                    .product(name: "WordPressKit", package: "WordPressKit-iOS"),
                ]
            ),
        ]
    }
}

extension Target {
    static func xcodeTarget(_ name: String, dependencies: [Dependency]) -> Target {
        .target(name: name, dependencies: dependencies, path: "Sources/XcodeSupport/\(name)")
    }
}
