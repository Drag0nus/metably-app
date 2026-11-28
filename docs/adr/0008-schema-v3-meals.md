# ADR 0008: Schema V3 for meals, and visible build numbers

- Status: Accepted
- Date: 2026-11-28

## Context

The Meals tab needs persisted meals with their foods. Pavlo counts carbohydrates in grams and
bread units (ХО) and uses the paper diary's М / С / В portion size for meals he did not weigh. Meals
can also be planned ahead and later marked as eaten. Separately, Pavlo asked to see which build is
installed on the simulator.

## Decision

- Add `MetablySchemaV3` with full copies of all V2 models; V2 is frozen. A lightweight stage maps
  V2 to V3. New: `MealRecord` (detail of a `TimelineEventRecord` with kind `meal`) and
  `MealItemRecord` (one food, ordered by `position`), both cascade-deleted with their parent.
- Carbohydrate grams are the stored fact. Bread units are derived on display from the factor in
  Settings (12 g by default), so changing the factor never rewrites history.
- Other nutrients (sugars, fibre, protein, fat, energy) are optional per food. A meal total is
  "unknown" when no food has the nutrient, never zero.
- `MealStatus` planned / eaten. Planned meals are listed apart and never count as eaten. "Eaten as
  planned" is one tap; a meal planned for later is then recorded at the current time.
- `PortionSize` small / medium / large is optional, shown as М / С / В in Ukrainian.
- The daily carbohydrate goal is off until the user sets one: the app does not invent a dietary
  target. The bar is neutral, not a warning.
- Edits replace the item rows; the previous meal (with items) is kept in the revision history and
  the outbox holds one coalesced entry per meal. `SyncEnvelope.currentSchemaVersion` becomes 3.
- Synthetic meals use a different seed from synthetic readings so ids never collide in the shared
  event table.
- Settings shows "Version (build)" and the build time. `MARKETING_VERSION` follows the pull request
  number for now (0.5.0 for PR 5) and `CURRENT_PROJECT_VERSION` is raised with every pull request.
  The build time is the executable's modification date, so two builds of the same commit differ.

## Consequences

- No food database yet: names and carbs are typed. A food catalogue can later fill an item without
  a schema change, since items already store all nutrients.
- Reading-to-meal links (`EventLink`) and the carbs card on Today come in the next pull request.
- The git commit is not shown; adding it needs a build script and is left for later.
