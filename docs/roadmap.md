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

- [x] Navigation shell: 5 tabs, Record reading accessory, iPad sidebar
- [x] Today screen: latest reading, 7-point strip, timeline
- [x] Journal: paper-diary table view
- [ ] Journal: filters (Glucose, Meals, Medications, Body, Notes) and entry detail
- [x] Activity level 1–5 on every reading (schema V2)
- [ ] Body screen (weight, waist, blood pressure, pulse) from Today and Journal
- [x] Meals: entry, items, carbs in grams, bread units display, planned/eaten, portion М/С/В (schema V3)
- [x] Daily carbohydrate goal (off until set)
- [ ] Other nutrient goals (protein, fat, energy, fibre) and carbs card on Today
- [x] Version, build number and build time in Settings
- [ ] Reading-to-meal link suggestions with user confirmation (`MealLinkSuggester` exists)
- [ ] Medications: tablets, schedules, reminders, history (taken / missed / postponed)
- [ ] Manual basal/bolus insulin record, hidden unless enabled (no calculator, no IOB)
- [x] User-configured glucose targets (ADA defaults, editable)
- [ ] Editable meal and bed times (`DailySchedule`)
- [x] Meter "LO"/"HI" entry
- [x] Edit reading screen

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
