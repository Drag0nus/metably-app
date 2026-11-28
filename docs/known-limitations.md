# Known limitations (0.2 in progress)

- Glucose readings and meals exist; other domains are modelled in the design doc but not implemented.
- The built-in food list has about 250 foods with reference averages from USDA; dishes such as
  borscht or varenyky are approximations. There are no barcodes yet, and foods cannot be added to
  the list yet.
- Individual sugars are known for only about half of the foods, and come only from the food list:
  they cannot be typed by hand. Sodium and saturated fat are not imported.
- Nutrient fields other than carbohydrates appear only for nutrients with a goal.
- One meal link per reading; the meal screen does not list its linked readings yet.
- The revision history of an edited reading is stored but not shown in the app yet.
- Targets default to the ADA values; bedtime and night readings have no default target.
- Meal and bed times used to suggest diary slots are fixed defaults (08:00, 13:00, 19:00, 22:30)
  until the schedule settings screen exists.
- The Journal shows glucose only; filters arrive with meals, medications and body records.
- Medications and Reports tabs are placeholders.
- The build shows version, build number and build time, but not the git commit.
- "LO"/"HI" prefill typical meter limits (0.6 / 33.3 mmol/L); per-meter limits are not configurable yet.
- HealthKit, Apple Watch, widgets, reports and sync are not implemented. The only reminder is the
  optional recheck after a low reading.
- The outbox fills but is never drained; one entry per record accumulates.
- The store is not yet in an App Group container, so widgets cannot read it.
- File protection uses the iOS default; the final level is open.
- The bundle identifier `app.metably.Metably` is a placeholder.
- The Debug synthetic data loader is the only way to populate test data.
