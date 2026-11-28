# ADR 0007: Schema V2 for the activity level

- Status: Accepted
- Date: 2026-11-28

## Context

Pavlo decided (27 Nov 2026) that every glucose reading asks for the paper diary's activity level
1–5. V1 has no place for it. Persisted fields are part of the schema, so the change needs a new
schema version rather than an edit to V1.

## Decision

- Add `MetablySchemaV2` with full copies of all models; V1 stays frozen as shipped.
- `GlucoseReadingRecord.activityLevel: Int?` is the only difference. `MetablyMigrationPlan` maps
  V1 to V2 with a lightweight stage; existing rows get nil.
- Domain type `ActivityLevel` accepts 1–5 only and encodes as a bare number. An unknown stored
  number reads as "not recorded" instead of failing the whole reading.
- `SyncEnvelope.currentSchemaVersion` becomes 2. The payload only gains an optional field, so V1
  payloads still decode.
- The entry sheet presets the level to the user's last choice (stored in preferences) and allows
  clearing it, so logging stays a two-tap action.
- A test writes a V1 store to disk and opens it through the app container to prove the migration.

## Consequences

- Each later schema change follows the same pattern: copy the models into V(n+1), add a stage.
- The level is optional: readings imported from Apple Health or meters will not have one.
