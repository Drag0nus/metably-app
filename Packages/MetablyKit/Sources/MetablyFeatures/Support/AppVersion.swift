import Foundation

/// What build is running, shown in Settings so a tester can tell builds apart.
///
/// Version and build come from the app's Info.plist (`MARKETING_VERSION` and
/// `CURRENT_PROJECT_VERSION` in the Xcode project, raised with every pull request).
/// The build time is the modification date of the app's executable, which changes on every build.
public struct AppVersion: Sendable, Hashable {
    public var version: String
    public var build: String
    public var builtAt: Date?

    public init(version: String, build: String, builtAt: Date?) {
        self.version = version
        self.build = build
        self.builtAt = builtAt
    }

    public init(bundle: Bundle) {
        self.init(
            infoDictionary: bundle.infoDictionary ?? [:],
            builtAt: bundle.executableURL.flatMap {
                try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            }
        )
    }

    init(infoDictionary: [String: Any], builtAt: Date?) {
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "–"
        build = infoDictionary["CFBundleVersion"] as? String ?? "–"
        self.builtAt = builtAt
    }

    public static var current: AppVersion { AppVersion(bundle: .main) }

    /// "0.5.0 (5)"
    public var versionAndBuild: String { "\(version) (\(build))" }
}
