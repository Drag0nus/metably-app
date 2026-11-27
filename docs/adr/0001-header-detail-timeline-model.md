# ADR 0001: Timeline header plus typed detail records in SwiftData

- Status: Accepted
- Date: 2026-11-27

## Context

The app shows one unified timeline (glucose, meals, medication, body, labs, activity, sleep,
symptoms, notes) and also domain-specific screens and reports. We need fast date-ordered queries
across all kinds and honest, typed validation per domain.

## Decision

Every timeline row is a `TimelineEventRecord` header (instant, time zone, local diary day, kind,
source, provider, external id, sync metadata) with exactly one typed detail record. Schema V1
contains only the glucose detail (`GlucoseReadingRecord`). We use composition (a one-to-one
relationship with cascade delete), not SwiftData model inheritance.

Storage is SwiftData behind the `GlucoseRepository` protocol. Features never import SwiftData
types; the composition root picks the implementation.

## Consequences

- One small, indexed table serves the timeline, search and reports.
- Adding a domain is a new detail model plus a new schema version, without touching others.
- Feature tests use `InMemoryGlucoseRepository`, so they run without a database.
- A Core Data or SQLite fallback stays possible behind the same protocol if SwiftData limits bite.
