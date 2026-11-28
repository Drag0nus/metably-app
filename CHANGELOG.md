# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Documentation
- `docs/diary-traceability.md`: page-by-page traceability of the Ukrainian self-control diary to the
  app (implemented, planned, gap or excluded with reason, with clinical checks against ADA 2025),
  and a "Self-control diary coverage" section in the roadmap with 17 gaps to schedule. Version 0.7.0 (7).

### Fixed
- The "Record reading" accessory and the tab bar no longer show on the pushed Settings screen.

### Added
- Reading-to-meal links: the entry sheet suggests the nearby meal ("Link to lunch at 13:10, 2 h 5 min
  after lunch") as a switch that starts off; only confirmed links are saved. Editing shows and can
  remove the link. Journal and Today show "2 h 5 min after lunch" on linked readings.
- SwiftData schema V4 with a lightweight migration from V3: `EventLinkRecord` (ADR 0009). Sync payload
  schema version 4.
- Today shows a carbohydrates card (eaten vs your goal, planned apart) once there is a meal or a goal.
- Daily goals for protein, fat, fibre and energy in Settings, each off until set. A tracked nutrient
  gets a field per food on the meal sheet and a progress row on the Meals tab that counts foods
  without a value. Version 0.6.0 (6).
- Meals tab: one diary day with previous/next, carbohydrates eaten (grams and bread units) against the
  user's own daily goal, eaten and planned meals apart, "Eaten as planned" in one tap, tap to edit.
- Meal entry: breakfast/lunch/dinner/snack suggested from the time, eaten or planned, foods with
  portion grams and carbohydrate grams, live total in g and bread units, optional portion size
  М/С/В, note, delete.
- SwiftData schema V3 with a lightweight migration from V2: `MealRecord` and `MealItemRecord`
  (ADR 0008). Sync payload schema version 3.
- Daily carbohydrate goal in Settings, off until the user sets one.
- Settings shows the app version, build number and build time. Version 0.5.0 (5).
- The Debug synthetic data loader also adds two weeks of synthetic meals.
- Edit reading: tap a reading on Today, in the Journal list or in the diary table to view its source and
  history dates, change it (previous values stay in the revision history) or delete it (soft delete).
- Meter "LO"/"HI" entry: prefilled with typical meter limits (editable), stored with meter flags,
  exempt from the typo bounds, shown as below/above target; LO shows the low-glucose guidance.
- SwiftData schema V2 with a lightweight migration from V1: optional `activityLevel` on glucose
  readings (ADR 0007). Sync payload schema version 2.
- Activity level 1–5 on the entry sheet, preset to the last choice; shown in the Journal list.
- Journal "Diary table" view: one row per day, one column per diary slot, out-of-target values bold
  with an arrow, a count when a slot has several readings.
- Synthetic readings now include an activity level.
- MVP navigation shell: five tabs (Today, Journal, Meals, Medications, Reports), iPad sidebar, and an
  always visible "Record reading" button in the iOS 26 tab bar accessory (ADR 0005).
- Today screen: latest reading with its age, source and target status (marked as old after 8 hours),
  the day's 7-point strip, today's timeline and an empty first-day card. Settings moved behind its gear.
- `GlucoseTargets` with ADA defaults, editable in Settings; target status with symbol, word and colour
  on Today, the Journal and the entry sheet (ADR 0006).
- `DiarySlot` and `DailySchedule`: the entry sheet suggests the diary slot from the time of day.
- Likely-duplicate warning (same value within 5 minutes) before saving another reading.
- Low-glucose guidance on the entry sheet (doctor's plan first, then the 15 g / 15 min rule with its
  source) with an optional local recheck reminder that never shows a value.
- Placeholder screens for Meals, Medications and Reports.
- Xcode project for iOS/iPadOS 26 with a thin app target and the local `MetablyKit` package.
- `MetablyDomain`: `GlucoseConcentration` (canonical mmol/L, 18.016 conversion), `GlucoseReading`,
  measurement contexts, specimen and meter flags, `LocalDay` (diary day from local midnight),
  `Provenance`, `GlucoseDataProvider` with `ManualGlucoseProvider`, `GlucoseSampleIngestor`,
  input parsing (decimal comma and point) and plausibility validation, `BreadUnitConverter`
  (12 g default, configurable), `MealLinkSuggester`, sync contracts (`SyncEnvelope`).
- `MetablyPersistence`: SwiftData schema V1 with `TimelineEventRecord`, `GlucoseReadingRecord`,
  `RecordRevisionRecord`, `OutboxEntryRecord`; migration plan; `SwiftDataGlucoseRepository`
  with transactional revision + outbox writes and soft delete.
- `MetablyHealthKit`: contracts for authorization, anchored import and writing (no implementation).
- `MetablySyntheticData`: deterministic synthetic glucose diaries.
- `MetablyFeatures`: glucose diary list, quick manual entry, settings (units, bread unit,
  insulin module and night check switches, Debug synthetic data), English and Ukrainian strings.
- Swift Testing suites for domain, persistence, synthetic data and feature models.
- GitHub Actions CI: package tests and iOS simulator build.
- Documentation: architecture overview, ADR 0001–0004, data dictionary, roadmap, known limitations.
