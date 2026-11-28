import Foundation
import MetablyDomain
import Observation

/// Keeps the user's profile (diabetes type, medicines, height, weight) on the device.
///
/// The profile is health data, so it lives in its own file with complete file protection and
/// never in `UserDefaults`. Like the SwiftData store it stays in the device backup, so moving to a
/// new iPhone keeps it; it is never sent to iCloud Drive or CloudKit. Only the "onboarding done" flag,
/// which says nothing about health, is kept in `UserDefaults`.
@Observable
@MainActor
public final class ProfileStore {
    public private(set) var profile: UserProfile?
    public private(set) var hasCompletedOnboarding: Bool
    /// True when the last save failed; the UI says so instead of losing the edit silently.
    public private(set) var saveFailed = false

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let defaults: UserDefaults
    private static let onboardingKey = "profile.onboardingCompleted"

    /// - Parameter directory: where to keep `profile.json`; nil keeps the profile in memory only.
    public init(directory: URL?, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fileURL = directory?.appending(path: "profile.json")
        hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        }
    }

    /// The app's protected support folder.
    public static func defaultDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base.appending(path: "Profile", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public func save(_ profile: UserProfile) {
        self.profile = profile
        guard let fileURL else {
            saveFailed = false
            return
        }
        do {
            let data = try JSONEncoder().encode(profile)
            #if os(iOS) || os(watchOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #else
            try data.write(to: fileURL, options: [.atomic])
            #endif
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    public func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Self.onboardingKey)
    }
}
