# Working on Metably

- All app code lives in `Packages/MetablyKit`; the Xcode app target stays a thin shell.
- Dependency direction: Features -> Persistence/SyntheticData -> Domain. Domain imports Foundation only.
- Never log health values, notes or identifiers. Log error types only.
- Use synthetic data only (MetablySyntheticData) in previews, tests and fixtures.
- No iCloud/CloudKit for health data: keep `cloudKitDatabase: .none`.
- Persisted enum raw values are part of the schema: never rename them; add a new schema version instead.
- Never add dose calculation, insulin-on-board or treatment recommendations.
- Fingerstick statistics are "share of readings in range", never "Time in Range".
- Docs, code and comments in English. UI strings in `Resources/{en,uk}.lproj`.
- Record significant decisions as ADRs in `docs/adr/` and keep `CHANGELOG.md` and `docs/roadmap.md` current.
- Raise `CURRENT_PROJECT_VERSION` (and `MARKETING_VERSION` 0.<PR number>.0 for now) in `Metably.xcodeproj` with every pull request, so the build in Settings tells testers what they run.
