# Data dictionary (schema V5)

Implemented entities only. The full model, including planned entities, is in the
[data model document](https://claude.ai/artifact/6aKcmbXqPNhsDwwVPnbyfR).

## TimelineEventRecord

| Field | Type | Notes |
|---|---|---|
| id | UUID, unique | Generated on the device; same id in exports, sync and HealthKit sync metadata |
| kindRaw | String | `EventKind`: glucose (V1), meal, medication, bodyMeasurement, lab, activity, sleep, symptom, note |
| startDate / endDate | Date | UTC instant; equal for point events |
| timeZoneID | String | IANA zone where it happened, e.g. `Europe/Kyiv` |
| timeZoneIsInferred | Bool | Zone was assumed at import |
| localDay | String | `YYYY-MM-DD` in the event's zone; day starts at local midnight |
| sourceRaw | String | `EventSource`: manual, watch, healthKit, bluetoothMeter, cgm, csvImport, vendorAPI, synthetic |
| providerID | String | Id of the `GlucoseDataProvider`, e.g. `manual` |
| sourceDetail | String? | Source app bundle id or similar |
| externalID | String? | Id in the source system; unique together with providerID (enforced by the repository) |
| isUserVerified | Bool | Manual = true; imports need confirmation |
| note | String? | Free text |
| createdAt / modifiedAt | Date | Entry time vs last change |
| deletedAt | Date? | Tombstone |
| version | Int | Local version, starts at 1 |
| serverVersion | Int64? | Last acknowledged server version; nil = never synced |
| originDeviceID / lastModifiedDeviceID | UUID | Random per-install id |
| syncCategoryRaw | String | `SyncCategory` for selective sync |
| isHealthKitDerived | Bool | Upload requires separate consent (planned) |
| schemaVersion | Int | Payload shape version |
| glucose | GlucoseReadingRecord? | Detail, cascade delete |
| meal | MealRecord? | V3. Detail, cascade delete |

Indexes: startDate, localDay, kindRaw, externalID.

## GlucoseReadingRecord

| Field | Type | Notes |
|---|---|---|
| valueMmolL | Double | Canonical value (1 mmol/L = 18.016 mg/dL) |
| enteredValue | Double | Exactly as entered |
| enteredUnitRaw | String | `mmol/L` or `mg/dL` |
| contextRaw | String | fasting, beforeMeal, afterMeal, bedtime, night, random |
| specimenRaw | String | capillary (default), cgmInterstitial, lab |
| flagsRaw | Int | Bit set: meterLow, meterHigh, controlSolution |
| minutesAfterMeal | Int? | When linked to a meal |
| deviceName | String? | Meter name |
| deviceSerialHash | String? | Hashed serial, never raw |
| activityLevel | Int? | V2. Self-reported activity 1–5 (paper diary scale); nil when not recorded or created before V2 |

## MealRecord (V3)

| Field | Type | Notes |
|---|---|---|
| slotRaw | String | `MealSlot`: breakfast, lunch, dinner, snack |
| statusRaw | String | `MealStatus`: planned, eaten |
| portionSizeRaw | String? | `PortionSize`: small, medium, large (paper diary М / С / В); nil when not recorded |
| items | [MealItemRecord] | Cascade delete |

The event's `startDate` is when the meal starts (or is planned to). Bread units are not stored.

## MealItemRecord (V3, extended in V5)

| Field | Type | Notes |
|---|---|---|
| id | UUID, unique | |
| position | Int | Order within the meal |
| name | String | Food name as typed |
| amountGrams | Double? | Portion weight (ml counted as g) |
| carbohydrateGrams | Double | Required; 0–500 per food |
| sugarsGrams, fiberGrams, proteinGrams, fatGrams | Double? | Optional; dietary sugars, never blood glucose |
| energyKilocalories | Double? | Optional |
| foodID | String? | V5. Catalog food id, e.g. `usda-sr-173424`; nil when typed by hand |
| sucroseGrams, glucoseGrams, fructoseGrams, lactoseGrams, maltoseGrams, galactoseGrams | Double? | V5. Individual dietary sugars in food, never blood glucose; nil means unknown |

## EventLinkRecord (V4)

| Field | Type | Notes |
|---|---|---|
| id | UUID, unique | |
| fromID | UUID | The glucose reading (indexed) |
| toID | UUID | The meal (indexed) |
| relationRaw | String | `EventLinkRelation`: preMeal, postMeal (doseForMeal, correction, symptomAt, treatedBy reserved) |
| minutesFromMealStart | Int? | Signed minutes at the time of linking; display uses current times |
| createdAt / modifiedAt / deletedAt | Date | Soft delete when the user unlinks |
| version / serverVersion | Int / Int64? | As on the timeline header |
| originDeviceID / lastModifiedDeviceID | UUID | |
| schemaVersion | Int | Payload shape version |

Only links the user confirmed are stored.

## RecordRevisionRecord

Append-only history: id, recordID, entityType, version, changedAt, deviceID,
changeKindRaw (create, update, delete, merge, conflictResolved), previousValues (JSON of the
record before the change).

## OutboxEntryRecord

id, recordID, entityType, operationRaw (upsert, delete), baseVersion (server version the change
is based on), envelope (JSON `SyncEnvelope`), createdAt, attempts, nextAttemptAt, lastError.
At most one pending entry per record.

## Derived values (not stored)

- Diary slot (fasting, after breakfast, … bedtime, night, other): from `contextRaw`, local time and
  the user's meal times. See ADR 0006.
- Target status (below / in target / above): from the value and the user's targets.

## Validation rules

- Glucose input accepts `6,4` and `6.4`; ASCII digits only.
- Plausibility bounds 0.5–35.0 mmol/L (9–631 mg/dL) catch typos. They are **not** clinical
  targets. Meter "LO"/"HI" readings are stored with flags and bypass the bounds.
- Activity level: 1–5 only; any other stored number is read as "not recorded".
- Measurement time may not be more than 5 minutes in the future.
- Bread units: grams stored; XE = grams ÷ factor; factor 12 g default, 10 g selectable,
  allowed 5–20 g.
