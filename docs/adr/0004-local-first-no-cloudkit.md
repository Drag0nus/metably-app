# ADR 0004: Local-first storage, CloudKit off, sync-ready records

- Status: Accepted
- Date: 2026-11-27

## Context

Health data is sensitive. The product supports three modes: Local Only (default), Cloud Backup
and Cloud Sync through Metably's own backend. Apple's rules and the project's privacy goals rule
out iCloud/CloudKit for personal health information. A threat model must precede cloud work.

## Decision

- The SwiftData container is created with `cloudKitDatabase: .none` and no App Group yet.
- Every record carries sync metadata from V1: `version`, `serverVersion`, `originDeviceID`,
  `lastModifiedDeviceID`, `syncCategory`, `isHealthKitDerived`, `schemaVersion`, `deletedAt`.
- Each change writes, in one transaction, the record, a `RecordRevisionRecord` with the previous
  values, and a coalesced `OutboxEntryRecord` holding a `SyncEnvelope`.
- Deletes are tombstones (`deletedAt`), never hard deletes.
- The outbox is not drained in this milestone.

## Consequences

- Switching from Local Only to a cloud mode later is lossless; no backfill is needed.
- Edited measurements keep their original values in the revision history.
- Outbox entries accumulate (one per record) until the sync engine exists. Compaction or
  skipping the outbox in Local Only mode is to be decided with the sync engine design.
- Server payloads will be end-to-end encrypted (decided in the threat model, 2026-11-27): the
  envelope's `payload` becomes ciphertext, and analytics, reports, deduplication and conflict
  comparison run on the client. The envelope shape does not change.
