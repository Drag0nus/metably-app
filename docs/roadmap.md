# Roadmap

Order follows the agreed strategy: local app and domain model first, sync contracts designed early,
backend built incrementally after the threat model.

## 0.1 Foundation (this milestone)

- [x] Xcode project, modular package, CI
- [x] Glucose domain model, units, diary day, provenance, providers
- [x] SwiftData schema V1 with revisions and outbox
- [x] Manual glucose entry and diary list (en/uk)
- [x] Synthetic data and unit tests

## 0.2 MVP UX

- [ ] Unified timeline screen and navigation (per the UX MVP thread)
- [ ] Meals: entry, items, carbs in grams, bread units display
- [ ] Reading-to-meal link suggestions with user confirmation (`MealLinkSuggester` exists)
- [ ] Medications: tablets, schedules, reminders, history (taken / missed / postponed)
- [ ] Manual basal/bolus insulin record, hidden unless enabled (no calculator, no IOB)
- [ ] User-configured glucose targets per context
- [ ] Meter "LO"/"HI" entry
- [ ] Edit reading screen (repository `update` exists)

## 0.3 Health and reports

- [ ] HealthKit glucose import/export behind `GlucoseDataProvider`
- [ ] Body measurements, labs
- [ ] Analytics module (share of readings in range, averages, variability)
- [ ] Glucose Profile Day (7-point) and Medical Reports (PDF/CSV/JSON, 14 days default)

## 0.4 Apple Watch and widgets

- [ ] watchOS app: latest reading with freshness, quick entry, medication confirmation
- [ ] Widgets and complications (App Group store, read-only)

## Later

- [x] Threat model: server payloads end-to-end encrypted
- [ ] Client-side encryption of sync envelopes (CryptoKit, Keychain)
- [ ] Sync engine, FastAPI backend, PostgreSQL, web app
- [ ] Bluetooth meters, CGM, CSV import
