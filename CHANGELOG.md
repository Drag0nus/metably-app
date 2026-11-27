# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
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
