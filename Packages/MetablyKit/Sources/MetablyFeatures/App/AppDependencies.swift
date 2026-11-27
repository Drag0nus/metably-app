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
    /// Kept alive for the lifetime of the app; repositories use its main context.
    private let modelContainer: ModelContainer?

    public init(
        glucoseRepository: any GlucoseRepository,
        preferences: UserPreferencesStore,
        dateProvider: any DateProvider = SystemDateProvider(),
        modelContainer: ModelContainer? = nil
    ) {
        self.glucoseRepository = glucoseRepository
        self.preferences = preferences
        self.dateProvider = dateProvider
        self.modelContainer = modelContainer
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
