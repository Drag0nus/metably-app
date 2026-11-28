import Foundation
import MetablyDomain

/// Mapping between domain `Meal` values and SwiftData records.
enum MealRecordMapping {
    static let entityType = "meal"

    static func makeRecords(for meal: Meal, deviceID: UUID) -> (TimelineEventRecord, MealRecord, [MealItemRecord]) {
        let event = TimelineEventRecord(
            id: meal.id,
            kindRaw: EventKind.meal.rawValue,
            startDate: meal.startedAt,
            endDate: meal.startedAt,
            timeZoneID: meal.timeZoneID,
            timeZoneIsInferred: false,
            localDay: meal.localDay.isoString,
            sourceRaw: meal.provenance.source.rawValue,
            providerID: meal.provenance.providerID,
            sourceDetail: meal.provenance.sourceDetail,
            externalID: meal.provenance.externalID,
            isUserVerified: true,
            note: meal.note,
            createdAt: meal.createdAt,
            modifiedAt: meal.modifiedAt,
            deletedAt: meal.deletedAt,
            version: meal.version,
            serverVersion: nil,
            originDeviceID: deviceID,
            lastModifiedDeviceID: deviceID,
            syncCategoryRaw: EventKind.meal.syncCategory.rawValue,
            isHealthKitDerived: meal.provenance.source == .healthKit,
            schemaVersion: SyncEnvelope.currentSchemaVersion
        )
        let detail = MealRecord(
            slotRaw: meal.slot.rawValue,
            statusRaw: meal.status.rawValue,
            portionSizeRaw: meal.portionSize?.rawValue
        )
        return (event, detail, makeItemRecords(meal.items))
    }

    static func makeItemRecords(_ items: [MealItem]) -> [MealItemRecord] {
        items.enumerated().map { index, item in
            MealItemRecord(
                id: item.id,
                position: index,
                name: item.name,
                amountGrams: item.amountGrams,
                carbohydrateGrams: item.carbohydrateGrams,
                sugarsGrams: item.sugarsGrams,
                fiberGrams: item.fiberGrams,
                proteinGrams: item.proteinGrams,
                fatGrams: item.fatGrams,
                energyKilocalories: item.energyKilocalories,
                foodID: item.foodID,
                sucroseGrams: item.sucroseGrams,
                glucoseGrams: item.glucoseGrams,
                fructoseGrams: item.fructoseGrams,
                lactoseGrams: item.lactoseGrams,
                maltoseGrams: item.maltoseGrams,
                galactoseGrams: item.galactoseGrams
            )
        }
    }

    /// Copies mutable fields onto the event and detail. Items are replaced by the caller.
    static func apply(_ meal: Meal, to event: TimelineEventRecord, detail: MealRecord) {
        event.startDate = meal.startedAt
        event.endDate = meal.startedAt
        event.timeZoneID = meal.timeZoneID
        event.localDay = meal.localDay.isoString
        event.note = meal.note
        event.deletedAt = meal.deletedAt
        event.schemaVersion = SyncEnvelope.currentSchemaVersion
        detail.slotRaw = meal.slot.rawValue
        detail.statusRaw = meal.status.rawValue
        detail.portionSizeRaw = meal.portionSize?.rawValue
    }

    static func makeMeal(from event: TimelineEventRecord) throws(RepositoryError) -> Meal {
        guard let detail = event.meal,
              let slot = MealSlot(rawValue: detail.slotRaw),
              let status = MealStatus(rawValue: detail.statusRaw),
              let source = EventSource(rawValue: event.sourceRaw),
              let timeZone = TimeZone(identifier: event.timeZoneID)
        else { throw .corruptRecord }
        let items = detail.items
            .sorted { $0.position < $1.position }
            .map {
                MealItem(
                    id: $0.id,
                    name: $0.name,
                    amountGrams: $0.amountGrams,
                    carbohydrateGrams: $0.carbohydrateGrams,
                    sugarsGrams: $0.sugarsGrams,
                    fiberGrams: $0.fiberGrams,
                    proteinGrams: $0.proteinGrams,
                    fatGrams: $0.fatGrams,
                    energyKilocalories: $0.energyKilocalories,
                    foodID: $0.foodID,
                    sucroseGrams: $0.sucroseGrams,
                    glucoseGrams: $0.glucoseGrams,
                    fructoseGrams: $0.fructoseGrams,
                    lactoseGrams: $0.lactoseGrams,
                    maltoseGrams: $0.maltoseGrams,
                    galactoseGrams: $0.galactoseGrams
                )
            }
        return Meal(
            id: event.id,
            slot: slot,
            status: status,
            startedAt: event.startDate,
            timeZone: timeZone,
            items: items,
            // An unknown stored portion reads as "not recorded" instead of failing the meal.
            portionSize: detail.portionSizeRaw.flatMap(PortionSize.init(rawValue:)),
            note: event.note,
            provenance: Provenance(
                source: source,
                providerID: event.providerID,
                sourceDetail: event.sourceDetail,
                externalID: event.externalID
            ),
            createdAt: event.createdAt,
            modifiedAt: event.modifiedAt,
            version: event.version,
            deletedAt: event.deletedAt
        )
    }
}
