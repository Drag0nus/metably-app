# Metably

Personal diabetes and metabolic health diary for iPhone and iPad (Apple Watch later).
Local-first and privacy-first: health records live on the device; cloud backup and sync are
optional and come in a later milestone.

> Metably is a tracking and educational tool. It does not diagnose, prescribe, or recommend
> medication or insulin doses.

## Status

Milestone 0.1, the app foundation. **Implemented:**

- Modular Swift package `MetablyKit` (domain, persistence, HealthKit contracts, synthetic data, features).
- Domain model for glucose readings with lossless units, local diary day and provenance.
- Vendor-neutral `GlucoseDataProvider` abstraction with the manual provider.
- SwiftData schema V1 (timeline header + glucose detail, revision history, sync outbox), CloudKit off.
- Manual glucose entry and a glucose diary grouped by day, in English and Ukrainian.
- Synthetic data generator (Debug only) and unit tests with Swift Testing.

**Planned** (not implemented yet): meals and nutrition, medications, body measurements, labs,
HealthKit import/export, Apple Watch app, widgets, reports, backend and web. See
[docs/roadmap.md](docs/roadmap.md).

## Requirements

- Xcode 26 or later (Swift 6.2)
- iOS / iPadOS 26 deployment target (watchOS 26 for the future Watch app)

## Getting started

```bash
git clone https://github.com/Drag0nus/metably-app.git
cd metably-app
open Metably.xcodeproj
```

1. Select the **Metably** scheme and an iPhone simulator, then Run (⌘R).
2. To run on a device, choose your team under *Signing & Capabilities* and change the bundle
   identifier `app.metably.Metably` if needed.
3. In a Debug build, *Settings → Developer → Add synthetic readings* fills the diary with
   invented data. Never use real health data in development.

Run the tests:

```bash
cd Packages/MetablyKit
swift test
```

or press ⌘U in Xcode (the scheme includes all package test targets).

## Repository layout

```
Metably.xcodeproj          Xcode project (app shell only)
Metably/                   App target: MetablyApp.swift, Info.plist
Packages/MetablyKit/       All app code, as a local Swift package
  Sources/MetablyDomain        Pure Swift domain: values, rules, protocols (Foundation only)
  Sources/MetablyPersistence   SwiftData schema, migrations, repositories
  Sources/MetablyHealthKit     HealthKit contracts (no implementation yet)
  Sources/MetablySyntheticData Deterministic synthetic data for previews and tests
  Sources/MetablyFeatures      SwiftUI screens and their @Observable models
  Tests/                       Swift Testing suites per module
docs/                      Architecture, ADRs, data dictionary, roadmap, limitations
```

## Documentation

- [Architecture overview](docs/architecture/overview.md)
- [Architecture Decision Records](docs/adr/)
- [Data dictionary](docs/data-dictionary.md)
- [Roadmap](docs/roadmap.md)
- [Known limitations](docs/known-limitations.md)
- [Changelog](CHANGELOG.md)
