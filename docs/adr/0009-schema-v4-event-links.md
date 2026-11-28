# ADR 0009: Schema V4 for confirmed reading-to-meal links

- Status: Accepted
- Date: 2026-11-28

## Context

Pavlo decided (27 Nov 2026) that a reading is linked to a meal by suggestion and user
confirmation, never automatically. The data model keeps links in a generic `EventLink` table, so a
reading or a meal does not change when a link is added or removed.

## Decision

- Add `MetablySchemaV4` with full copies of all V3 models plus `EventLinkRecord` (fromID, toID,
  relation, minutes from meal start, sync metadata), indexed on both ids. V3 is frozen; a
  lightweight stage maps V3 to V4. `SyncEnvelope.currentSchemaVersion` becomes 4.
- `SwiftDataEventLinkRepository` writes the link, a revision and a coalesced outbox entry in one
  save, like the other repositories. Removing a link is a soft delete.
- The glucose entry sheet asks `MealLinkSuggester` for the best meal near the reading's time and
  context. A reading after a meal needs an eaten meal; one before a meal may precede a planned one.
  The suggestion is shown as a switch that starts **off**; only a switched-on link is saved. A
  confirmation belongs to one meal: if the time or slot changes the suggestion, it resets.
- Editing a reading shows its existing link; switching it off soft-deletes the link.
- Lists show "2 h 5 min after lunch" computed from the current reading and meal times, so editing
  either keeps the text true. Links to a deleted meal are not shown.
- Ukrainian needs the meal in the genitive ("після обіду"), so each meal and direction has its own
  localized string instead of a composed phrase.

## Consequences

- Insulin doses (`doseForMeal`) and symptoms can reuse the same table later.
- Links are one per reading for now; the table allows more.
- The meal screen does not yet list the readings linked to it.
