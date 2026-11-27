# ADR 0003: Vendor-neutral GlucoseDataProvider and a single ingestion path

- Status: Accepted
- Date: 2026-11-27

## Context

Today the user records fingerstick values by hand. Later sources are Apple Health (high
priority), Bluetooth meters, CGMs, CSV import and vendor APIs. The architecture must not depend on
a specific manufacturer.

## Decision

- Every source implements `GlucoseDataProvider` (`id`, `displayName`, `kind`, `isAvailable`,
  `fetchSamples(since:)`) and delivers raw `GlucoseSample`s.
- `GlucoseSampleIngestor` is the only way a sample becomes a `GlucoseReading`. It validates,
  keeps the entered value and unit, the instant and time zone, and fills `Provenance` (source,
  provider id, source detail, device name, hashed serial, external id).
- Manual entry uses `ManualGlucoseProvider` for identity; the entry screen pushes samples
  directly to the ingestor.
- Imported readings start as `isUserVerified = false`; manual readings are verified.
- Duplicates are rejected by id and by (provider id, external id).
- HealthKit is a separate source, never the primary database. `MetablyHealthKit` defines the
  contracts now and does not import HealthKit until the feature is built, so the app requests no
  HealthKit entitlement yet.

## Consequences

- New sources add a provider, not new storage or validation code.
- Analytics can separate capillary and CGM data by `specimen`.
