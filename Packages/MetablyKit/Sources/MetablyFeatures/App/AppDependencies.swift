import Foundation
import MetablyDomain
import MetablyPersistence
import MetablySyntheticData
import SwiftData

/// Composition root: builds the concrete implementations behind the domain protocols.
/// Views and models receive what they need from here (constructor injection).
@MainActor
public final class AppDependencies {
    public let glucoseRepository: any GlucoseRepository
    public let preferences: UserPreferencesStore
    public let dateProvider: any DateProvider
    public let reminders: any RecheckReminderScheduling
    /// Kept alive for the lifetime of the app; repositories use its main context.
    private let modelContainer: ModelContainer?

    public init(
        glucoseRepository: any GlucoseRepository,
        preferences: UserPreferencesStore,
        dateProvider: any DateProvider = SystemDateProvider(),
        reminders: any RecheckReminderScheduling = NoopRecheckReminder(),
        modelContainer: ModelContainer? = nil
    ) {
        self.reminders = reminders
        self.glucoseRepository = glucoseRepository
        self.preferences = preferences
        self.dateProvider = dateProvider
        self.modelContainer = modelContainer
    }

    /// A fresh entry sheet model with the user's unit, targets and schedule.
    public func makeGlucoseEntryModel() -> GlucoseEntryModel {
        GlucoseEntryModel(
            repository: glucoseRepository,
            unit: preferences.displayGlucoseUnit,
            dateProvider: dateProvider,
            targets: preferences.glucoseTargets,
            schedule: preferences.dailySchedule,
            nightCheckEnabled: preferences.nightCheckEnabled,
            reminders: reminders
        )
    }

    /// The real on-device store.
    public static func live() throws -> AppDependencies {
        let container = try MetablyModelContainer.make()
        let dateProvider = SystemDateProvider()
        let repository = SwiftDataGlucoseRepository(
            context: container.mainContext,
            deviceID: DeviceIdentity.current(),
            dateProvider: dateProvider
        )
        return AppDependencies(
            glucoseRepository: repository,
            preferences: UserPreferencesStore(),
            dateProvider: dateProvider,
            reminders: NotificationRecheckReminder(),
            modelContainer: container
        )
    }

    /// In-memory dependencies with two weeks of synthetic readings, for SwiftUI previews.
    public static func preview(days: Int = 14) -> AppDependencies {
        let timeZone = TimeZone.current
        let today = LocalDay(instant: Date(), timeZone: timeZone)
        let readings = SyntheticGlucoseGenerator()
            .makeReadings(days: days, endingOn: today, timeZone: timeZone)
            .filter { $0.measuredAt <= Date() }
        let defaults = UserDefaults(suiteName: "app.metably.preview") ?? .standard
        return AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(readings: readings),
            preferences: UserPreferencesStore(defaults: defaults)
        )
    }
}
