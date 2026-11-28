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
    public let mealRepository: any MealRepository
    public let linkRepository: any EventLinkRepository
    public let preferences: UserPreferencesStore
    public let dateProvider: any DateProvider
    public let reminders: any RecheckReminderScheduling
    /// Kept alive for the lifetime of the app; repositories use its main context.
    private let modelContainer: ModelContainer?

    public init(
        glucoseRepository: any GlucoseRepository,
        mealRepository: (any MealRepository)? = nil,
        linkRepository: (any EventLinkRepository)? = nil,
        preferences: UserPreferencesStore,
        dateProvider: any DateProvider = SystemDateProvider(),
        reminders: any RecheckReminderScheduling = NoopRecheckReminder(),
        modelContainer: ModelContainer? = nil
    ) {
        self.reminders = reminders
        self.glucoseRepository = glucoseRepository
        self.mealRepository = mealRepository ?? InMemoryMealRepository()
        self.linkRepository = linkRepository ?? InMemoryEventLinkRepository()
        self.preferences = preferences
        self.dateProvider = dateProvider
        self.modelContainer = modelContainer
    }

    /// An entry sheet model with the user's unit, targets and schedule. Pass `editing` to
    /// edit an existing reading instead of adding one.
    public func makeGlucoseEntryModel(editing: GlucoseReading? = nil) -> GlucoseEntryModel {
        GlucoseEntryModel(
            repository: glucoseRepository,
            unit: preferences.displayGlucoseUnit,
            dateProvider: dateProvider,
            targets: preferences.glucoseTargets,
            schedule: preferences.dailySchedule,
            nightCheckEnabled: preferences.nightCheckEnabled,
            activityLevel: preferences.lastActivityLevel,
            reminders: reminders,
            meals: mealRepository,
            links: linkRepository,
            editing: editing
        )
    }

    /// A meal sheet model: a new meal (eaten or planned) or editing an existing one.
    public func makeMealEntryModel(status: MealStatus = .eaten, editing: Meal? = nil) -> MealEntryModel {
        MealEntryModel(
            repository: mealRepository,
            dateProvider: dateProvider,
            schedule: preferences.dailySchedule,
            breadUnits: preferences.breadUnitConverter,
            trackedNutrients: preferences.trackedNutrients,
            status: status,
            editing: editing
        )
    }

    /// The real on-device store.
    public static func live() throws -> AppDependencies {
        let container = try MetablyModelContainer.make()
        let dateProvider = SystemDateProvider()
        let deviceID = DeviceIdentity.current()
        let repository = SwiftDataGlucoseRepository(
            context: container.mainContext,
            deviceID: deviceID,
            dateProvider: dateProvider
        )
        let meals = SwiftDataMealRepository(context: container.mainContext, deviceID: deviceID, dateProvider: dateProvider)
        let links = SwiftDataEventLinkRepository(context: container.mainContext, deviceID: deviceID, dateProvider: dateProvider)
        return AppDependencies(
            glucoseRepository: repository,
            mealRepository: meals,
            linkRepository: links,
            preferences: UserPreferencesStore(),
            dateProvider: dateProvider,
            reminders: NotificationRecheckReminder(),
            modelContainer: container
        )
    }

    /// In-memory dependencies with two weeks of synthetic readings and meals, for SwiftUI previews.
    public static func preview(days: Int = 14) -> AppDependencies {
        let timeZone = TimeZone.current
        let today = LocalDay(instant: Date(), timeZone: timeZone)
        let readings = SyntheticGlucoseGenerator()
            .makeReadings(days: days, endingOn: today, timeZone: timeZone)
            .filter { $0.measuredAt <= Date() }
        let meals = SyntheticMealGenerator()
            .makeMeals(days: days, endingOn: today, timeZone: timeZone, now: Date())
        let defaults = UserDefaults(suiteName: "app.metably.preview") ?? .standard
        return AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(readings: readings),
            mealRepository: InMemoryMealRepository(meals: meals),
            preferences: UserPreferencesStore(defaults: defaults)
        )
    }

    /// "2 h 5 min after lunch" for each reading that has a confirmed meal link.
    /// Links to a meal that was deleted are left out.
    public func mealLinkTexts(for readings: [GlucoseReading]) -> [UUID: String] {
        guard let links = try? linkRepository.links(fromIDs: Set(readings.map(\.id))) else { return [:] }
        let byID = Dictionary(readings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var texts: [UUID: String] = [:]
        for link in links {
            guard let reading = byID[link.fromID],
                  let meal = try? mealRepository.meal(id: link.toID), !meal.isDeleted
            else { continue }
            // From the current times, so editing the reading's time keeps the text true.
            let minutes = Int((reading.measuredAt.timeIntervalSince(meal.startedAt) / 60).rounded())
            texts[link.fromID] = MealLinkText.text(slot: meal.slot, minutes: minutes)
        }
        return texts
    }
}
