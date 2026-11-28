# Known limitations (0.2 in progress)

- Only glucose readings exist; other domains are modelled in the design doc but not implemented.
- No edit screen yet; readings can be added and deleted (soft delete).
- Targets default to the ADA values; bedtime and night readings have no default target.
- Meal and bed times used to suggest diary slots are fixed defaults (08:00, 13:00, 19:00, 22:30)
  until the schedule settings screen exists.
- Activity level 1–5 is not recorded yet (needs schema V2).
- Meals, Medications and Reports tabs are placeholders.
- Meter "LO"/"HI" values are supported by the model but cannot be entered in the UI yet.
- HealthKit, Apple Watch, widgets, reports and sync are not implemented. The only reminder is the
  optional recheck after a low reading.
- The outbox fills but is never drained; one entry per record accumulates.
- The store is not yet in an App Group container, so widgets cannot read it.
- File protection uses the iOS default; the final level is open.
- The bundle identifier `app.metably.Metably` is a placeholder.
- The Debug synthetic data loader is the only way to populate test data.
