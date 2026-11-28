# ADR 0011: User profile, day routine and the daily reminder plan

- Status: Accepted
- Date: 2026-11-28

## Context

Pavlo wants to set Metably up as a profile: diabetes type, insulin or tablets with doses, meals per
day, height and weight (with BMI), and have the app work out when to remind him to eat, drink water,
check glucose before and after meals, and take medicines. iOS keeps at most 64 pending local
notifications per app. Notifications can show on the Lock Screen.

## Decision

- Domain: `UserProfile` (diabetes type, optional height and weight, medicines), `ProfileMedicine`
  (name, kind, the user's own dose text, times of day), `DayRoutine` (wake time, main meal and bed
  times via `DailySchedule`, skipped meals, up to three snacks), `ReminderSettings` and
  `ReminderPlanner`. Domain still imports Foundation only.
- Storage: the profile is health data, so `ProfileStore` keeps it in `Application Support/Profile/
  profile.json`, written atomically with complete file protection, never in `UserDefaults`, never
  in logs and never in iCloud Drive or CloudKit. Like the SwiftData store it stays in the device
  backup. The routine and reminder choices are not health data and live in `UserDefaults`.
  Persisted enum raw values (`DiabetesType`, `MedicineKind`) are part of the schema.
- BMI is shown as a plain number with one decimal and a neutral explanation; no category, colour or
  judgement.
- Doses are free text copied from the prescription. The app never calculates, derives or suggests a
  dose or a dose change from the profile. Insulin in the profile only switches the insulin module on.
- Plan: fasting check 15 min after waking, a check 15 min before each main meal, a bedtime check
  15 min before bed, each meal and snack, each medicine time, and water every N minutes while awake
  (off by default). Ids are stable (`check.fasting`, `meal.lunch`, `med.<uuid>.<minute>`, …), so a
  reminder the user switched off stays off when times change. The plan is capped at 56 daily
  reminders, keeping medicines first and dropping water first, which leaves room for one-off
  reminders.
- The check after a meal is event-driven: logging an eaten meal schedules one notification at
  start + 60/90/120 min (default 120); planning or deleting the meal cancels it.
- Permission is asked only when the user taps "Allow notifications". The plan is re-applied at
  launch and after the profile or reminder screen changes, only if already allowed.
- Notification titles and bodies are generic: no values, doses or medicine names. The in-app plan
  list may show the medicine name and dose because only the user sees it.
- First launch shows Profile, then Reminders; everything is optional and "Skip" goes to the app.
  Both screens are also in Settings › Me.

## Consequences

- Times are local wall-clock times; a time zone change moves reminders with the clock.
- Medication history (taken, missed, postponed) and notification actions come with the medications
  PR; this one only reminds.
- A meal edited later re-schedules its post-meal check from the new start time.
