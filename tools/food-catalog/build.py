import csv, json, sys, os
src = sys.argv[1]; out = sys.argv[2]
foods = {f['description']: f for f in csv.DictReader(open(f'{src}/food.csv'))}
want = {'1008':'kcal','1003':'protein','1004':'fat','1005':'carbohydrate','2000':'sugars','1079':'fiber',
        '1010':'sucrose','1011':'glucose','1012':'fructose','1013':'lactose','1014':'maltose','1075':'galactose'}
units = {u['id']: u['name'] for u in csv.DictReader(open(f'{src}/measure_unit.csv'))}
rows = [l.rstrip('\n').split('\t') for l in open('foods.tsv', encoding='utf-8') if l.strip()]
ids = {}
missing = []
for desc, en, uk, cat in rows:
    f = foods.get(desc)
    if not f: missing.append(desc); continue
    ids[f['fdc_id']] = (desc, en, uk, cat)
if missing:
    print("MISSING", missing); sys.exit(1)
nut = {i: {} for i in ids}
for r in csv.DictReader(open(f'{src}/food_nutrient.csv')):
    if r['fdc_id'] in nut and r['nutrient_id'] in want:
        nut[r['fdc_id']][want[r['nutrient_id']]] = round(float(r['amount']), 2)
portions = {i: [] for i in ids}
for r in csv.DictReader(open(f'{src}/food_portion.csv')):
    if r['fdc_id'] in portions:
        unit = units.get(r['measure_unit_id'], '')
        desc = (r['modifier'] or '').strip()
        if r['portion_description']: desc = r['portion_description'].strip()
        amount = r['amount'] or '1'
        label = f"{amount} {unit if unit and unit!='undetermined' else ''} {desc}".replace('  ',' ').strip()
        portions[r['fdc_id']].append({'label': label, 'grams': round(float(r['gram_weight']), 1), 'seq': int(r['seq_num'] or 0)})
result = []
for fid, (desc, en, uk, cat) in ids.items():
    n = nut[fid]
    for key in ['kcal','protein','fat','carbohydrate']:
        if key not in n: print("WARN missing", key, desc)
    p = sorted(portions[fid], key=lambda x: x['seq'])
    result.append({'id': f'usda-sr-{fid}', 'fdcId': int(fid), 'nameEN': en, 'nameUK': uk, 'category': cat,
                   'sourceDescription': desc, 'per100g': n,
                   'portions': [{'label': x['label'], 'grams': x['grams']} for x in p if 'oz' not in x['label'].split() and x['grams'] > 0]})
json.dump(result, open(out,'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(result), "foods")
cov = {k: sum(1 for r in result if k in r['per100g']) for k in want.values()}
print(cov)
