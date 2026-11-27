# Known limitations (0.1)

- Only glucose readings exist; other domains are modelled in the design doc but not implemented.
- No edit screen yet; readings can be added and deleted (soft delete).
- No target ranges are shown: the app does not invent clinical targets and the target settings
  screen is not built yet.
- Meter "LO"/"HI" values are supported by the model but cannot be entered in the UI yet.
- HealthKit, Apple Watch, widgets, reminders, reports and sync are not implemented.
- The outbox fills but is never drained; one entry per record accumulates.
- The store is not yet in an App Group container, so widgets cannot read it.
- File protection uses the iOS default; the final level is open.
- The bundle identifier `app.metably.Metably` is a placeholder.
- The Debug synthetic data loader is the only way to populate test data.
