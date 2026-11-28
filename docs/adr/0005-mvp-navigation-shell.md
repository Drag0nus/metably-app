# ADR 0005: MVP navigation shell

- Status: Accepted
- Date: 2026-11-28

## Context

The approved MVP screens prototype (design artifact, 27 Nov 2026) defines five tabs, an always
visible way to log a fingerstick reading, and no separate tab for body measurements. Logging a
reading must take under five seconds from anywhere in the app.

## Decision

- `MainTabView` uses the iOS 18+ `TabView(selection:)` with `Tab(value:)` items: Today, Journal,
  Meals, Medications, Reports. `.tabViewStyle(.sidebarAdaptable)` turns the tabs into a sidebar
  on iPad.
- On iOS 26 the "Record reading" button lives in `.tabViewBottomAccessory`, so it stays one tap
  away on every tab. The entry sheet is owned by `MainTabView` and shared with the Today screen's
  first-reading card.
- Settings opens from the gear on Today (pushed, not a tab).
- Body measurements get no tab: they will open from Today's weight card, the Journal filter and the
  iPad sidebar (decided by Pavlo, 27 Nov 2026).
- Tabs whose screens are not built yet show an honest "Coming soon" placeholder, never mock data.

## Consequences

- Each tab has its own `NavigationStack`, so switching tabs keeps each tab's place.
- The accessory is iOS-only API; the package still compiles for macOS (used by `swift test`)
  through `#if os(iOS)`.
- Adding a sixth tab later would push the iPhone tab bar to "More"; new areas should be sections
  inside the existing tabs instead.
