# Self-control diary traceability

Source: *Щоденник самоконтролю для людей з цукровим діабетом* (Roche Diabetes Care / Accu-Chek,
code UA.I.ACD.19.001, 53 PDF pages, reviewed by Zinych O.V., Kushnarova N.M., Skibun V.M.).
Project copy: `/mnt/project-files/Diary-of-Selfcontrol-Ua-full.pdf`.
Public copy: https://endoaging.com.ua/ua/wp-content/uploads/2020/12/Diary-of-Selfcontrol-Ua-full.pdf

Metably is a phone version of this diary. This document maps every section, field, table and
education topic of the diary to the app, so that nothing is lost by accident and every deliberate
difference has a written reason.

Reviewed against `main` at version 0.6.0 (6), PRs 1–6, on 2026-11-28.

## How to read this

Page numbers are the diary's printed numbers, with the PDF page in brackets: "p. 19 (PDF 20)".

| Status | Meaning |
|---|---|
| ✅ Implemented | In `main`; file or PR given. |
| 🟡 Partial | Some of it is in `main`; the rest is named. |
| 🗓 Planned | Already on [the roadmap](roadmap.md); item named. |
| ❗ Gap | Not implemented and not on the roadmap before this document. Listed in [Gaps](#gaps-to-schedule). |
| ⛔ Excluded | Deliberately not in the app; reason given. |

"Clinical check" notes compare the diary (printed 2019–2020) with current guidance:
ADA *Standards of Care in Diabetes—2025* (section numbers given), the IDF, and the WHO. They
explain why the app uses a different default; they are not medical advice, and clinical content
shown in the app still needs review by a clinician before release.

## 1. Diary structure at a glance

| Part | Pages | Kind | Coverage |
|---|---|---|---|
| Cover, publisher, disclaimers | 1–2, 52 (PDF 1–3, 53) | Front/back matter | ✅ disclaimer, ⛔ branding |
| Diabetes and self-monitoring basics | 3–5 (PDF 4–6) | Education | ❗ |
| Glycaemic targets, HbA1c | 5 (PDF 6) | Education + clinical values | 🟡 |
| How often to measure | 5–6 (PDF 6–7) | Education + schedules | 🟡 |
| Hypoglycaemia, hyperglycaemia | 6–8 (PDF 7–9) | Education + emergency steps | 🟡 |
| Nutrition rules | 8–9 (PDF 9–10) | Education | ❗ |
| Bread units and exchange tables | 10–15 (PDF 11–16) | Reference tables | 🟡 |
| Food pyramid | 16 (PDF 17) | Education | ⛔ / ❗ |
| Foot care | 17–18 (PDF 18–19) | Education | ❗ |
| Tests and specialist visits (type 2) | 18 (PDF 19) | Schedule table | ❗ |
| Daily diary grid | 19–42 (PDF 20–43) | Recording form | 🟡 |
| Glycaemic profile (3-day sheets) | 43–49 (PDF 44–50) | Recording form + chart | 🟡 |
| Blood pressure, pulse, weight log | 50 (PDF 51) | Recording form | 🗓 |
| HbA1c log, notes | 51 (PDF 52) | Recording form | 🟡 |

## 2. Recording forms (the diary proper)

These pages are what the patient fills in and brings to the endocrinologist. They are the core
of the app and the reference for the Journal and the Medical Report.

### 2.1 Daily diary grid — pp. 19–42 (PDF 20–43)

One row block per day; 24 pages × 7 days ≈ 6 months.

| # | Diary field | Status | Where / note |
|---|---|---|---|
| G1 | Date (Дата) | ✅ | `LocalDay`, day starts at midnight (`MetablyDomain/Time/LocalDay.swift`, PR 1). |
| G2 | Breakfast: before | ✅ | `DiarySlot.fasting` ("before breakfast" is the fasting column), `DiarySlot.swift`, PR 2. |
| G3 | Breakfast: after* | ✅ | `DiarySlot.afterBreakfast`. |
| G4 | Lunch: before / after* | ✅ | `DiarySlot.beforeLunch`, `.afterLunch`. |
| G5 | Dinner: before / after* | ✅ | `DiarySlot.beforeDinner`, `.afterDinner`. |
| G6 | Bedtime 22:00 | ✅ | `DiarySlot.bedtime`; bedtime time 22:30 default in `DailySchedule`. |
| G7 | Night 3:00 | ✅ | `DiarySlot.night`, optional and off by default (ADR 0006, PR 2). |
| G8 | "години" (time of the check) | ✅ | Every reading stores its instant and time zone (`GlucoseReading`, PR 1). |
| G9 | Footnote: *after = 2 h from the **start** of the meal | ✅ | `MealLinkSuggester` measures from `Meal.startedAt`; post-meal window 90–150 min around the 2 h point (PR 6). |
| G10 | Row "Цукор у крові" (blood glucose) | ✅ | Manual entry in mmol/L or mg/dL (PR 1), LO/HI (PR 4), Journal table `DiaryTableView.swift` (PR 3). |
| G11 | Row "Доза інсуліну" (insulin dose per slot) | 🗓 | Roadmap 0.2 "Manual basal/bolus insulin record, hidden unless enabled". Recording only; no calculation (see E-series). |
| G12 | Tablets (not on the grid, but p. 2 says "record your doctor's prescriptions") | 🗓 | Roadmap 0.2 "Medications: tablets, schedules, reminders, history". |
| G13 | Meal times implied by the columns | 🟡 | Fixed defaults 08:00 / 13:00 / 19:00 / 22:30; roadmap 0.2 "Editable meal and bed times (`DailySchedule`)". |
| G14 | Paper layout: one row per day, columns per slot | ✅ | Journal default view is the paper-diary table (PR 3). |
| G15 | The grid's insulin row shown next to glucose in the Journal table | ❗ | Gap **GAP-01**: when insulin/tablet records exist, the Journal table and report need the second row. |

### 2.2 Glycaemic profile sheets — pp. 43–49 (PDF 44–50)

Instructions page (p. 43) plus 6 sheets of 3 days each (18 profile days).

| # | Diary field / step | Status | Where / note |
|---|---|---|---|
| P1 | Step 1: dates of the profile days | 🗓 | Roadmap 0.3 "Glucose Profile Day (7-point)". Length picker 1/3/7 days decided; the diary's sheet is 3 days. |
| P2 | Step 2: seven checks — fasting, 2 h after breakfast, before lunch, 2 h after lunch, before dinner, 2 h after dinner, bedtime | ✅ | `DiarySlot.profileSlots(includingNight:)`; Today shows the 7-point strip (PR 2). |
| P3 | Step 3: time of each check (Час) | ✅ | Stored instant per reading. |
| P4 | Step 4: food volume М/С/В (small / medium / large) on the post-meal columns | ✅ | `PortionSize` on `Meal` (PR 5). The diary puts it on the after-meal check; Metably stores it on the meal and links the reading (PR 6). Same information, one source of truth. |
| P5 | Step 5: activity level 1–5 at the moment of the check, legend 1 = minimal … 5 = high | ✅ | `ActivityLevel` on every reading, schema V2 (PR 3). Legend text matches the diary's five levels. |
| P6 | Step 6: glucose value, mmol/L | ✅ | As G10. |
| P7 | Step 7: mark the value on the band chart and join the points for the day | 🗓 | Roadmap 0.3 profile chart. See P8 for the bands. |
| P8 | Band chart rows: < 2.8, 2.8–4.4, 4.5–6.1, 6.2–7.7, 7.8–10.0, 10.1–12.2, 12.3–14.4, 14.5–16.6, > 16.7 mmol/L, with "too low" / "too high" zones and a before/after-meal target band | ⛔ as default bands | The chart will draw the **user's own targets** (ADA defaults, `GlucoseTargets.swift`, ADR 0006) instead of fixed bands, and the 3.9 mmol/L low line. Clinical check: the diary's lowest "normal" band starts at 4.5 and "too low" at < 2.8; ADA section 6 uses < 3.9 (level 1) and < 3.0 (level 2). The fixed bands may be offered as an optional "paper layout" grid with no verdict colours (**GAP-02**). |
| P9 | "Combine the cells at the end of the day" (daily curve) | 🗓 | Same as P7. |
| P10 | Three days side by side for comparison | 🗓 | Profile Day length 3 shows the diary's sheet; also part of the Medical Report. |

### 2.3 Blood pressure, pulse and weight — p. 50 (PDF 51)

| # | Field | Status | Where / note |
|---|---|---|---|
| B1 | Date | 🗓 | Roadmap 0.2 "Body screen (weight, waist, blood pressure, pulse)". |
| B2 | Blood pressure (АД), morning and evening | 🗓 | Same. The **morning/evening pairing** must be kept: store each measurement with its time and show the table as morning / evening columns (**GAP-03**, a requirement on the planned screen). |
| B3 | Pulse, morning and evening | 🗓 | Same as B2. |
| B4 | Weight | 🗓 | Same. |
| B5 | Note (Примітка) per row | 🗓 | A note on body records (as readings and meals already have). |

### 2.4 HbA1c log and notes — p. 51 (PDF 52)

| # | Field | Status | Where / note |
|---|---|---|---|
| H1 | HbA1c: date + level (%) | 🗓 | Roadmap 0.3 "Body measurements, labs". Keep both % (NGSP) and mmol/mol (IFCC) and the lab's reference range. |
| H2 | Notes pages (НОТАТКИ) — free text | 🟡 | Notes on readings and meals exist (PR 1, PR 5). A stand-alone diary note (`EventKind.note`) is modelled but has no screen (**GAP-04**). |

## 3. Reference tables

### 3.1 Bread unit system — p. 10 (PDF 11)

| # | Content | Status | Where / note |
|---|---|---|---|
| X1 | 1 bread unit (ХО) = 10–12 g carbohydrate | ✅ | `BreadUnitConverter`, default 12 g, configurable; grams stored, ХО derived (PR 5). |
| X2 | ХО measured in pieces, spoons, glasses, cups | 🟡 | Portion grams typed by hand today. Household portions are planned with the food database (roadmap 0.2, PR 7) — see X5. |
| X3 | 1 uncovered ХО raises glucose by 1.7–3.0 mmol/L | ⛔ | Used in the diary to predict glucose and choose an insulin dose. The app does not predict glucose or dose (CLAUDE.md, project instructions §13). |
| X4 | ≤ 7 ХО per meal per injection; 1 ХО snack without insulin; 1 ХО needs 1.5–4 U insulin | ⛔ | Dosing and insulin-to-carb guidance. Excluded: no dose calculation or recommendations. A user may set their **own** per-meal carb goal with their doctor; the daily carb goal exists (PR 5). Per-meal goals: **GAP-05**. |

### 3.2 Food exchange tables — pp. 10–15 (PDF 11–16)

These tables are what Pavlo asked about. Each row gives the amount of a food that equals **1 ХО**,
its energy, and a household measure. They are an exchange list, not a nutrient database: carbs are
implied (10–12 g), protein/fat/fibre are not given.

| # | Table / page | Rows (approx.) | Status |
|---|---|---|---|
| F1 | Fruits and berries, p. 10 (table) + p. 11 (photos with weights) | ~37 | ❗ GAP-06 |
| F2 | Cereals and flour products, p. 12 (table) + p. 13 (photos) | ~27 | ❗ GAP-06 |
| F3 | Potato products, p. 12 | 7 | ❗ GAP-06 |
| F4 | Bread and bakery, p. 12 + p. 13 (photos) | 18 | ❗ GAP-06 |
| F5 | Side dishes / pasta, p. 12 + p. 13 | 10 | ❗ GAP-06 |
| F6 | Starches, p. 12 | 4 | ❗ GAP-06 |
| F7 | Vegetables (large portions = 1 ХО), milk/kefir/yoghurt per 250 ml, tomato juice, diabetic chocolate, nuts, p. 14 | ~14 | ❗ GAP-06 |
| F8 | Legumes, honey, caramel, dark chocolate, nuts and seeds, p. 15 | ~17 | ❗ GAP-06 |

**How the app should use them (GAP-06).** The planned food database (USDA FoodData Central subset,
roadmap 0.2 / PR 7) gives nutrients per 100 g. The diary's tables should be the **checklist of
foods and household portions** for that database: every food in F1–F8 must exist in the bundled
database with a Ukrainian name and the diary's household measure (e.g. "1 small apple, 90 g",
"½ slice rye bread 1 cm, 25 g", "2 heaped tbsp cooked rice, 50 g"). Nutrient values come from
USDA (CC0, traceable source); the diary's gram amount is used as the portion, and a unit test checks
that each diary portion gives 10–12 g carbohydrate from the USDA values, flagging rows that differ.
Diary-specific items with no USDA match (e.g. "діабетичний шоколад", Swabian dumplings) are listed
as unmatched rather than invented. The diary's kcal figures are not copied: they are rounded to 5 kcal and
the USDA values are the single nutrient source. Where the diary gives a weight with and without
peel or stone (e.g. tangerine 120 g peeled, 150 g with peel), both become portions.

### 3.3 Tests and specialist visits, type 2 diabetes — p. 18 (PDF 19)

| # | Diary item | Diary frequency | Status | Clinical check (ADA 2025) |
|---|---|---|---|---|
| T1 | Self-monitoring (fasting and 2 h after meals) | Daily at onset and when uncontrolled | ✅ recording; ❗ reminders (GAP-07) | ADA 7: frequency is individual; fine as a user-set schedule. |
| T2 | HbA1c | Every 3 months; every 6 months when at target | 🗓 recording (labs); ❗ reminder (GAP-08) | ADA 6: at least twice a year at goal, quarterly otherwise. Matches. |
| T3 | Biochemistry: protein, cholesterol, triglycerides, bilirubin, AST, ALT, urea, uric acid, creatinine, K, Na, Ca | Every 6 months | 🗓 labs; ❗ reminder | ADA 10/11: lipids at diagnosis and periodically (often yearly); creatinine/eGFR yearly. Keep the diary's 6 months as an editable default only if the user's doctor uses it. |
| T4 | Complete blood count | Every 6 months | 🗓 labs; ❗ reminder | Not a diabetes-specific ADA screening item; user-configurable reminder. |
| T5 | Urinalysis | As prescribed, ≥ 2 per year | 🗓 labs; ❗ reminder | User-configurable. |
| T6 | Microalbuminuria | Yearly | 🗓 labs (UACR); ❗ reminder | ADA 11: UACR and eGFR at least yearly. Matches. |
| T7 | Blood pressure | Every doctor visit | 🗓 body | ADA 10: every routine visit. Matches. |
| T8 | ECG | Yearly and as needed | ❗ reminder, off by default | ADA 10 does not recommend routine screening for coronary disease in people without symptoms. Offer as a custom reminder, not a default. |
| T9 | Foot examination | Every visit | ❗ reminder | ADA 12: comprehensive foot exam at least yearly; inspect at every visit if at risk. |
| T10 | Endocrinologist | Monthly and as needed | ❗ appointment reminder | Local practice; user-set. |
| T11 | Chest fluorography | Yearly | ❗ custom reminder, off by default | Ukrainian TB screening practice, not a diabetes guideline item. |
| T12 | Ophthalmologist | Yearly, more often if prescribed | ❗ reminder | ADA 12: every 1–2 years if no retinopathy, at least yearly otherwise. |
| T13 | Neurologist, diabetic foot clinic | Yearly, more often if prescribed | ❗ reminder | ADA 12: yearly neuropathy screening. Matches. |

The project instructions (§6 "Preventive Care") ask for these reminders, but the roadmap had no item
for them. **GAP-08** schedules a Preventive care module: a checklist of tests and visits with the
diary's list as the starting template, each item editable or removable, frequencies set "as your
doctor advises", last-done date from the labs/visits log, local notifications only.

## 4. Clinical and education content

The diary's text pages are patient education. The app has no education section yet. The plan
(**GAP-09**) is a short, offline "Довідка" (Reference) with the topics below, each written fresh,
sourced and dated, and reviewed by a clinician. The diary is the topic list; the content is not
copied, because parts of it are dated (see the clinical checks).

### 4.1 Basics — pp. 2–5 (PDF 3–6)

| # | Topic | Status | Note |
|---|---|---|---|
| E1 | What diabetes is; type 1 vs type 2; insulin resistance | ❗ GAP-09 | Education topic. |
| E2 | Self-monitoring definition; "absence of symptoms ≠ absence of complications" | ❗ GAP-09 | Fits the calm, no-shame tone; good onboarding message. |
| E3 | ROSSO study: −32 % complications, −51 % mortality with self-monitoring | ⛔ | An observational-study headline used as promotion by the meter maker. Not shown as a claim in the app. |
| E4 | What each check tells you (fasting, before meal, 2 h after, bedtime, emergencies) | 🟡 / ⛔ | The **contexts** are implemented (G2–G7). The diary's interpretation is about whether the **dose** of insulin or tablets is enough; that interpretation is excluded (no treatment advice). The app may say neutrally what each context is for and "discuss the pattern with your doctor". The "emergency" situations become context tags (GAP-10). |
| E5 | HbA1c reflects about 3 months; HbA1c ↔ average glucose scale | 🗓 / ❗ | HbA1c recording planned (H1). Estimated average glucose (ADAG formula, eAG = 28.7 × A1c − 46.7 mg/dL) could be shown next to a lab HbA1c, clearly labelled as an estimate (**GAP-11**). It must never be computed from fingerstick readings and shown as HbA1c. Clinical check: the diary's scale (4 % = 3.5 … 12 % = 19.5 mmol/L, 2 mmol/L per 1 %) reads higher than ADAG (7 % ≈ 8.6 mmol/L, diary ≈ 9.5); the diary's scale is not reused. |
| E6 | Normal HbA1c ≤ 5.9 %; target ≤ 7 % "in most cases"; −1 % HbA1c → −37 % microvascular complications | ⛔ as defaults | Clinical check: ADA 2 uses < 5.7 % for "normal"; ADA 6 says < 7 % for many adults, individualised. The app stores the lab's own reference range and the user's own target; it does not hard-code 5.9 %. The 37 % figure (UKPDS 35) may appear in education with citation. |
| E7 | "Normal" glucose without diabetes: fasting ≤ 6.1, 2 h after a meal ≤ 7.8 mmol/L | ⛔ as targets | These are WHO diagnostic thresholds for people without diabetes, not treatment targets. |
| E8 | "Satisfactory control": fasting ≤ 6.5–7.0, 2 h after ≤ 8.5 mmol/L | ⛔ as defaults | Older regional targets. Defaults follow ADA 6 (4.4–7.2 before meals, < 10.0 after; ADR 0006) and are **editable**, so a user whose doctor uses the diary's values can enter them. |
| E9 | Hypoglycaemia below 3.9 mmol/L | ✅ | `GlucoseTargets.lowThresholdMmolL = 3.9` (PR 2). Matches ADA level 1. |
| E10 | Hyperglycaemia "as a rule above 10 mmol/L" | 🟡 | The post-meal upper target defaults to 10.0. No separate "high" alert exists; none is planned without a clinician-agreed threshold. |

### 4.2 How often to measure — pp. 5–6 (PDF 6–7)

| # | Topic | Status | Note |
|---|---|---|---|
| M1 | "Follow your doctor's or nurse's schedule" | ✅ principle | All schedules are user-set; nothing is prescribed by the app. |
| M2 | Type 1/2 on ≥ 3 injections: fasting, before each meal, sometimes 2 h after, bedtime | 🟡 | Slots exist; reminder schedules planned with the beta reminders (memory: beta plan) — **GAP-07** makes them diary-based templates. |
| M3 | Type 2 on diet/tablets/1–2 injections: 5–6 a day until stable, then 1–2 a day 3–7 days a week, several times a month a full profile | 🟡 | Same as M2: offered as editable templates ("until stable", "stable"), chosen by the user with their doctor. |
| M4 | Glycaemic profile: fasting, before and 2 h after breakfast, lunch, dinner | 🗓 | Glucose Profile Day (roadmap 0.3). Note the diary's profile here lists **before breakfast** separately from fasting; Metably treats before-breakfast as the fasting column (G2), as the diary grid does. |
| M5 | Measure more often when: therapy change, exercise, diet change, illness/stress, travel, driving, suspected hypo | ❗ GAP-10 | Context tags on readings (illness, stress, travel, driving, exercise, therapy change, suspected hypo) so these days can be filtered in the Journal and marked in the report. |
| M6 | Pregnancy: fasting, before and 2 h after meals, bedtime, 03:00 | 🟡 / ⛔ | The 03:00 slot exists (G7). Pregnancy targets differ (ADA 15) and pregnancy is out of scope for the MVP; the app must not apply the ADA adult defaults to pregnancy. Recorded in known limitations. |

### 4.3 Emergencies — pp. 6–8 (PDF 7–9)

| # | Topic | Status | Note |
|---|---|---|---|
| U1 | Hypo symptoms: hunger, weakness, tremor, sweating, headache, irritability, dizziness | ❗ GAP-12 | Symptom logging is modelled (`EventKind.symptom`, `EventLinkRelation.symptomAt`) but has no screen. The diary's list is the starting symptom set. |
| U2 | Hypo treatment: 200 ml sweet drink or juice, or 4–5 sugar cubes, then slow carbs; recheck in 15 min; repeat | ✅ | Low-reading banner: the doctor's plan first, then the 15 g / 15 min rule with its source (ADA 6), and an optional recheck notification in 15 min (`GlucoseEntryView.swift`, `RecheckReminder.swift`, PR 2). Clinical check: matches ADA 6 (15–20 g fast carbohydrate, recheck after 15 min). |
| U3 | "Analyse why the hypo happened" | ❗ GAP-12 | A follow-up question on a low reading ("what happened?": missed meal, more activity, alcohol, medication change, other) feeds the report. No advice. |
| U4 | Always carry fast carbohydrates | ❗ GAP-09 | Education. ADA 6 also advises glucagon for people at risk of level 2/3 hypoglycaemia; the diary does not mention it. |
| U5 | Hyper symptoms: frequent urination, poor wound healing, thirst, dry/itchy skin, tiredness, weakness, weight loss, glucose/ketones in urine | ❗ GAP-12 | Same symptom picker. |
| U6 | Ketoacidosis warning signs (vomiting, drowsiness, breathlessness, fruity breath) | ❗ GAP-09 | Education with "seek urgent care". Ketone records: **GAP-13** (blood or urine ketones as a body/lab measurement). Clinical check: ADA 6/14 prefer blood β-hydroxybutyrate to urine strips where available. |
| U7 | Hyper actions: contact a specialist, check every 2 h, follow prescribed treatment, drink sugar-free fluids, liquid food if nauseous | 🟡 / ⛔ | "Check every 2 h" can be an optional sick-day reminder series (GAP-10). Treatment content is the doctor's; the app does not tell the user to take insulin. |

### 4.4 Nutrition — pp. 8–9, 16 (PDF 9–10, 17)

| # | Topic | Status | Note |
|---|---|---|---|
| N1 | Which foods contain carbohydrates (bread, potato, cereals, fruit, milk, sugar) | 🟡 | Carbs are recorded per food (PR 5); the food database will supply them (PR 7). Education text: GAP-09. |
| N2 | "Exclude sugar and sweets except for hypoglycaemia or before heavy exercise" | ⛔ as a rule | Clinical check: ADA 5 advises minimising added sugars and sugar-sweetened drinks, not a ban. The app tracks dietary sugars (planned with PR 7) without judging foods. |
| N3 | "Carbohydrates should be at least half of the diet" | ⛔ | Outdated. ADA 5 (and the 2019 ADA nutrition consensus): there is no ideal percentage of carbohydrate, protein and fat; eating plans are individualised. The app has user-set goals only (PR 5, PR 6). |
| N4 | Prefer high-fibre carbs; small, evenly spread portions | 🟡 | Fibre is recorded and has an optional goal (PR 6). Carbs per meal are visible in the Meals tab. Education: GAP-09. |
| N5 | Calories and overweight; high-calorie foods; caution with "diabetic" products | 🟡 | Energy recorded with optional goal (PR 6); weight planned. Education: GAP-09. |
| N6 | Fats: limit fatty meat, sausages, fatty dairy, fast food, sauces; nuts are high-calorie | 🟡 | Fat recorded (PR 6). Saturated fat is not split out; ADA 5 focuses on fat quality — a `saturatedFatGrams` field from USDA is a candidate for the food database (**GAP-14**). |
| N7 | Salt: less salt for blood pressure | ❗ GAP-14 | Sodium is not recorded. ADA 10 suggests < 2,300 mg/day for most people. Add sodium from USDA to the food database and an optional goal. |
| N8 | Alcohol: little; risk of hypoglycaemia on tablets/insulin; never on an empty stomach; eat carbs before and after | ❗ GAP-09, GAP-12 | Education topic; "alcohol" as a cause in U3 and a context tag (GAP-10). |
| N9 | "Diabetic" products (sorbitol, xylitol, fructose) are almost as caloric as sugar | ❗ GAP-09 | Education topic. |
| N10 | Low-calorie sweeteners (aspartame, cyclamate, saccharin) "do not affect glucose or weight at all" | ⛔ as stated | Clinical check: ADA 5 accepts non-nutritive sweeteners as a replacement for sugar in the short term; the WHO 2023 guideline advises against them for weight control. The absolute claim is not repeated. |
| N11 | Food pyramid (Harvard Healthy Eating Pyramid): vegetables, whole grains, healthy fats at the base; daily exercise, weight control, water | ⛔ graphic / ❗ water | The graphic is not reproduced. **Water intake** is in the project instructions but not on the roadmap (**GAP-15**). |
| N12 | Pyramid: "daily multivitamin and vitamin D for most people" | ⛔ | Clinical check: ADA 5 finds no clear evidence that routine vitamin or mineral supplements help people with diabetes who are not deficient. |

### 4.5 Foot care — pp. 17–18 (PDF 18–19)

| # | Topic | Status | Note |
|---|---|---|---|
| C1 | Why: neuropathy, angiopathy, ulcers, amputation | ❗ GAP-09 | Education. |
| C2 | Daily: inspect feet, wash (check water temperature), dry between toes, moisturise (not between toes), change socks, inspect shoes; well-fitting shoes; file nails straight | ❗ GAP-16 | Optional daily "feet checked" item (a one-tap diary check, off by default) and education text. Clinical check: matches ADA 12 self-care education. |
| C3 | Minor injuries: antiseptic (miramistin, chlorhexidine), sterile dressing; see the diabetic foot clinic for any problem | ⛔ product names / ❗ GAP-09 | The app names no products; it says to contact the foot clinic or doctor. |
| C4 | Yearly check by the diabetic foot clinic | ❗ GAP-08 | Preventive care reminder (T9, T13). |
| C5 | Don'ts: heat sources, chemical corn removers, cutting corns, iodine/alcohol/brilliant green, shoes without socks, barefoot, dry skin, scissors, darned socks | ❗ GAP-09 | Education. |

## 5. Front and back matter

| # | Content | Status | Note |
|---|---|---|---|
| A1 | "This information does not replace your doctor's advice; self-treatment can be harmful" | ✅ | Settings disclaimer, en/uk (`Localizable.strings` key `settings.disclaimer`). Should also appear once at first launch (**GAP-17**). |
| A2 | Purpose: "the diary helps you choose correct insulin doses" (p. 2) | ⛔ | Metably records doses but never helps choose them (CLAUDE.md). |
| A3 | Roche / Accu-Chek branding, addresses, hotlines, adverse-event contacts | ⛔ | Metably is vendor-neutral (ADR 0003) and is not affiliated with Roche. The diary is credited as a domain reference in the docs only. |
| A4 | Reviewer names | ⛔ | Credited here; not shown in the app. |

## 6. Medical report coverage

The endocrinologist sees the paper diary. The Medical Report (roadmap 0.3) must contain everything
the paper diary would show for the period:

| Paper diary content | In the report spec | Status |
|---|---|---|
| Daily grid: 7 slots + 03:00, glucose and insulin rows | 7-point table | 🗓 (needs GAP-01 for the insulin/tablet row) |
| Profile sheets with time, М/С/В, activity, curve | Glucose Profile Day | 🗓 |
| BP / pulse morning-evening, weight | Body section | 🗓 (needs GAP-03) |
| HbA1c log | Labs section | 🗓 |
| Notes | Full log, notes opt-in | 🗓 |
| Symptoms, hypo causes, context days | — | ❗ GAP-10, GAP-12 |

## Gaps to schedule

Items that were neither implemented nor on the roadmap. Suggested slot in brackets; Pavlo decides
the order.

| ID | Gap | Diary source | Suggested slot |
|---|---|---|---|
| GAP-01 | Insulin/tablet row under the glucose row in the Journal table and report | Grid pp. 19–42 | With medications (0.2) |
| GAP-02 | Optional "paper layout" band grid on the profile chart (no verdict colours) | p. 43–49 | With Profile Day (0.3) |
| GAP-03 | Body records: morning/evening BP and pulse table layout | p. 50 | With Body screen (0.2) |
| GAP-04 | Stand-alone diary note screen | p. 51 | 0.2, Journal filters |
| GAP-05 | Optional per-meal carbohydrate goal (user/doctor-set, no dosing) | p. 10 | After food DB (0.2) |
| GAP-06 | Food database covers every food in the diary's ХО tables with uk names and the diary's household portions; test checks 10–12 g carbs per diary portion; unmatched items listed | pp. 10–15 | **PR 7 (food DB), now** |
| GAP-07 | Glucose-check reminder templates from the diary's schedules (until stable / stable / profile day / pregnancy excluded) | pp. 5–6 | With reminders (0.2 beta) |
| GAP-08 | Preventive care module: tests and visits checklist from the diary's type 2 table, editable frequencies, reminders | p. 18 | 0.3, with labs |
| GAP-09 | Offline "Довідка" education section, topics from the diary, rewritten, sourced, clinician-reviewed | pp. 3–9, 16–18 | 0.3 |
| GAP-10 | Context tags on readings/days: illness, stress, travel, driving, exercise, therapy change, alcohol, suspected hypo; optional sick-day 2-hourly reminders | pp. 6, 8 | 0.2/0.3 |
| GAP-11 | Estimated average glucose next to a lab HbA1c, labelled as an estimate | p. 5 | With labs (0.3) |
| GAP-12 | Symptom logging with the diary's hypo/hyper symptom lists; "what happened?" after a low reading | pp. 6–7 | 0.2/0.3 |
| GAP-13 | Ketone records (blood or urine) | p. 7 | With body/labs (0.3) |
| GAP-14 | Sodium and saturated fat from the food database, optional goals | p. 9 | PR 7 data, goals later |
| GAP-15 | Water intake | p. 16 | 0.3 |
| GAP-16 | Optional daily foot check item | p. 17 | 0.3 |
| GAP-17 | Disclaimer shown once at first launch | pp. 1–2 | 0.2 beta |

## Deliberate exclusions (summary)

| Excluded | Why |
|---|---|
| Insulin dose choice, ХО → dose, glucose rise per ХО, max 7 ХО per injection | No dose calculation or treatment advice (CLAUDE.md; project instructions §13). |
| Interpreting readings as "dose is (in)sufficient" | Same. |
| Fixed "normal"/"satisfactory" glucose and HbA1c values as defaults | Superseded by ADA 2025 sections 2 and 6; targets are personal and editable (ADR 0006). |
| "Carbs ≥ 50 % of the diet", sugar ban, sweeteners "no effect", daily multivitamins | Not supported by ADA 2025 section 5 / WHO 2023. |
| ROSSO percentages | Promotional headline from an observational study. |
| Branded products, antiseptic names, Roche contacts | Vendor-neutral app; no product recommendations. |
| Pregnancy targets | Out of MVP scope; ADA section 15 targets differ. |

## Keeping this current

- A PR that implements a row changes its status here in the same PR.
- New features that trace to the diary cite the row ID (e.g. "GAP-06") in the PR description.
