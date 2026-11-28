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
- [x] Other nutrient goals (protein, fat, energy, fibre) and carbs card on Today
- [x] Built-in offline food database (USDA FoodData Central, uk/en names, household portions,
      diary foods and measures with page references; schema V5)
- [x] Individual dietary sugars per food and a daily sugars card
- [ ] Sodium and saturated fat from USDA
- [ ] Open Food Facts barcode lookup (optional, online)
- [x] User profile (diabetes type, medicines, meals per day, height, weight, BMI) that proposes a
      reminder plan (PR 10)
- [x] Local reminders: glucose checks, meals, medicines, water, check after a meal (PR 10)
- [x] Version, build number and build time in Settings
- [x] Reading-to-meal link suggestions with user confirmation (schema V4)
- [ ] Medications: tablets, schedules, reminders, history (taken / missed / postponed)
- [ ] Manual basal/bolus insulin record, hidden unless enabled (no calculator, no IOB)
- [x] User-configured glucose targets (ADA defaults, editable)
- [x] Editable meal, wake and bed times (PR 10)
- [x] Meter "LO"/"HI" entry
- [x] Edit reading screen

## 0.3 Health and reports

- [ ] HealthKit glucose import/export behind `GlucoseDataProvider`
- [ ] Body measurements, labs
- [ ] Analytics module (share of readings in range, averages, variability)
- [ ] Glucose Profile Day (7-point) and Medical Reports (PDF/CSV/JSON, 14 days default)

## Self-control diary coverage

Gaps found by [the diary traceability matrix](diary-traceability.md). IDs match that document.

- [x] GAP-06 Food database covers the diary's bread unit tables with household measures (PR 8)
- [ ] GAP-06 follow-up: list diary foods and measures that are not in the catalog
- [ ] GAP-14 Sodium and saturated fat in the food database
- [ ] GAP-01 Insulin/tablet row under glucose in the Journal table and report (with medications)
- [ ] GAP-03 Morning/evening blood pressure and pulse layout (with the Body screen)
- [ ] GAP-04 Stand-alone diary note
- [ ] GAP-07 Glucose-check reminder templates from the diary's schedules (daily plan in PR 10; diary templates still to do)
- [ ] GAP-17 Disclaimer once at first launch
- [ ] GAP-10 Context tags: illness, stress, travel, driving, exercise, therapy change, alcohol, suspected low
- [ ] GAP-12 Symptom logging (diary's low/high symptom lists) and "what happened?" after a low
- [ ] GAP-05 Optional per-meal carbohydrate goal (no dosing)
- [ ] GAP-08 Preventive care: tests and visits checklist with reminders
- [ ] GAP-09 Offline reference section (education), clinician-reviewed
- [ ] GAP-11 Estimated average glucose next to a lab HbA1c
- [ ] GAP-13 Ketone records
- [ ] GAP-02 Optional paper-layout bands on the profile chart
- [ ] GAP-15 Water intake
- [ ] GAP-16 Optional daily foot check

## 0.4 Apple Watch and widgets

- [ ] watchOS app: latest reading with freshness, quick entry, medication confirmation
- [ ] Widgets and complications (App Group store, read-only)

## Later

- [x] Threat model: server payloads end-to-end encrypted
- [ ] Client-side encryption of sync envelopes (CryptoKit, Keychain)
- [ ] Sync engine, FastAPI backend, PostgreSQL, web app
- [ ] Bluetooth meters, CGM, CSV import
