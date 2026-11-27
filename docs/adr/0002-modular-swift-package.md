# ADR 0002: All code in a local Swift package with one-way module dependencies

- Status: Accepted
- Date: 2026-11-27

## Context

The project targets iPhone, iPad, Apple Watch, widgets and App Intents, and must keep business
logic testable on its own. Xcode project files are hard to review and merge.

## Decision

The Xcode project contains only a thin app target. All code lives in `Packages/MetablyKit`, split
into `MetablyDomain`, `MetablyPersistence`, `MetablyHealthKit`, `MetablySyntheticData` and
`MetablyFeatures`. Dependencies point one way, towards `MetablyDomain`, which imports Foundation
only. The app target uses a file-system synchronized group, so adding files needs no project edits.

## Consequences

- `swift test` runs every test without the app or a simulator (CI runs it on macOS).
- The Watch app, widgets and App Intents can link exactly the modules they need.
- Module boundaries are enforced by the compiler (`public` API), not by convention.
- iOS-only SwiftUI modifiers in `MetablyFeatures` need `#if os(iOS)` because the package also
  builds for macOS to run tests.
