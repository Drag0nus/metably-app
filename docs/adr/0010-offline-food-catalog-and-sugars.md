# ADR 0010: Offline food catalog, schema V5 and individual dietary sugars

- Status: Accepted
- Date: 2026-11-28

## Context

Pavlo wants to add "2 boiled eggs" and get carbohydrates, protein and fat computed, and to see
which sugars he ate in a day (lactose, glucose, sucrose and so on). The app is local-first and must
work offline. He uses the Ukrainian self-control diary, whose bread-unit tables (pp. 11–16) list the
foods and household measures people actually use.

## Decision

- Bundle a curated catalog of about 250 foods (`Resources/Foods/foods.json`) built from USDA
  FoodData Central SR Legacy (April 2018, public domain, CC0 1.0) by `tools/food-catalog`. Each food
  has uk/en names, a category, the USDA description, nutrients per 100 g and household portions.
  A nutrient USDA does not report is absent, never zero.
- Which foods to include and how to measure them follows the diary where possible: its foods were
  added, and 58 of its measures are stored as portions marked `"source": "diary p. N"`, as edible
  weight per one unit. Where the diary contradicts itself the measure is left out. Nutrient values
  always come from USDA; bread units are computed from carbohydrate grams and the user's factor,
  never taken from the diary table. `tools/food-catalog/diary-check.md` lists how each diary amount
  compares with USDA carbohydrates.
- Domain: `Food`, `FoodCatalog` (search across uk/en names, case- and accent-insensitive, every word
  must match, ranked by name prefix, then word prefix, then substring) and `DietarySugar` with
  `DietarySugarBreakdown`. Domain still imports Foundation only; Features loads the file.
- `MealItem` gains `foodID` and six optional sugars. `MetablySchemaV5` adds the matching optional
  attributes to `MealItemRecord`; V4 is frozen and a lightweight stage maps V4 to V5.
  `SyncEnvelope.currentSchemaVersion` becomes 5.
- Meal entry: typing a name suggests catalog foods. Picking one fills the name, the first measure
  and quantity 1 (or 100 g), and computes weight, carbohydrates and tracked nutrients. Carbs stay
  editable and what is typed is what is saved. Unlinking the food keeps typed values and drops the
  catalog-only ones. Editing an item whose food is no longer in the catalog keeps everything stored.
- The Meals tab shows "Sugars eaten" for eaten meals only, with the subtitle "grams of sugar in food,
  not blood glucose". A sugar is listed only when some food knows it, and the card says
  "no data for N foods" instead of counting gaps as zero.
- Settings › About credits USDA FoodData Central and the diary.

## Consequences

- Values are reference averages, not the user's food; the meal sheet says so when a catalog food is
  used. Open Food Facts barcodes (optional, online) can be added later as another source.
- Individual sugars are known for only about half of the foods; the UI is honest about that.
- Sodium and saturated fat are not imported yet; adding them is a catalog rebuild plus new optional
  fields in a later schema version.
