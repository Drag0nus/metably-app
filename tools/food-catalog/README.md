# Food catalog builder

Builds `Packages/MetablyKit/Sources/MetablyFeatures/Resources/Foods/foods.json`, the offline food
catalog bundled with the app, from the USDA FoodData Central SR Legacy CSV release (April 2018,
public domain, CC0 1.0): https://fdc.nal.usda.gov/download-datasets

- `foods.tsv`: the curated list. Columns: exact SR description, English name, Ukrainian name, category.
- `build.py <csv-folder> foods.json`: picks nutrients per 100 g (energy, protein, fat, carbohydrate,
  total sugars, fiber, sucrose, glucose, fructose, lactose, maltose, galactose) and raw portions.
  A nutrient USDA does not report is left out, never written as zero.
- `portions.py`: normalises household portions to one unit with Ukrainian labels, orders them
  (pieces first), and wraps the list with the source attribution.
- `diary-portions.tsv` and `diary.py`: household measures from the Ukrainian self-control diary
  ("Щоденник самоконтролю", bread-unit tables on pages 11–16), as edible weight per one unit.
  Each such portion has `"source": "diary p. N"`. The diary chose which everyday foods to include
  and how people measure them; nutrient values still come only from USDA. Where the diary
  contradicts itself (for example two different weights for the same spoon), the measure is left out.

Run from this folder:

```sh
python3 build.py ~/Downloads/FoodData_Central_sr_legacy_food_csv_2018-04 foods.json
python3 portions.py
python3 diary.py
python3 diary_check.py   # writes diary-check.md
cp foods.json ../../Packages/MetablyKit/Sources/MetablyFeatures/Resources/Foods/foods.json
```
