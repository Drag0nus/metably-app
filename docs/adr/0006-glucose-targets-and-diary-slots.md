# ADR 0006: Glucose targets and diary slots

- Status: Accepted
- Date: 2026-11-28

## Context

The Today screen and the diary show whether a reading is inside the user's target, and place
readings in the columns of the paper self-control diary (7-point profile). Foundation 0.1 showed no
targets at all. The clinician report spec (v0.1) fixed defaults from the ADA Standards of Care and
made them user-editable.

## Decision

- `GlucoseTargets` (Domain) holds the user's targets in mmol/L. Defaults: before meals and fasting
  4.4–7.2 mmol/L (80–130 mg/dL), after meals up to 10.0 mmol/L (180 mg/dL). Users edit them in
  Settings; inconsistent targets are never stored.
- Bedtime, night and "other" readings have no default target. For them the app only reports
  "below" when the value is under 3.9 mmol/L; otherwise it gives no verdict.
- The low-glucose threshold is fixed at ADA level 1 (below 3.9 mmol/L / 70 mg/dL). It triggers the
  low-glucose guidance on the entry sheet: the doctor's plan first, then the general 15 g / 15 min
  rule with its source and an optional recheck reminder. No medication or dose advice.
- Status is computed at the display precision of the unit the value was entered in, so 130 mg/dL
  is in target for 7.2 mmol/L although it converts to 7.22 mmol/L.
- Status is always shown with a symbol (checkmark, up or down arrow) and a word as well as colour.
- `DiarySlot` (fasting, after breakfast, before lunch, after lunch, before dinner, after dinner,
  bedtime, optional night, other) is derived, not persisted: from the stored
  `GlucoseMeasurementContext`, the local time and the user's `DailySchedule`. The entry sheet
  suggests a slot from the time of day; the user confirms or changes it.

## Consequences

- No schema change: slots and targets live outside the SwiftData schema (targets in preferences).
- If the user changes their schedule later, older readings may move between "before lunch" and
  "before dinner" columns. Storing the slot explicitly would need schema V2; revisit with the
  Glucose Profile Day, which has planned slots of its own.
- The 2019 paper diary's targets are not used; current ADA defaults replace them.
