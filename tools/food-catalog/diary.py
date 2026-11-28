"""Adds household portions from the Ukrainian self-control diary to foods.json.

Each added portion carries `source` with the diary page, so it can be checked against the paper.
Diary portions go first: they are the measures Ukrainian users know. Nutrient values stay USDA.
"""
import json, sys
catalog = json.load(open('foods.json', encoding='utf-8'))
by_uk = {f['nameUK']: f for f in catalog['foods']}
missing, added = [], 0
for line in open('diary-portions.tsv', encoding='utf-8'):
    if not line.strip() or line.startswith('#'): continue
    food_uk, en, uk, grams, page, _wording = line.rstrip('\n').split('\t')
    food = by_uk.get(food_uk)
    if not food: missing.append(food_uk); continue
    portion = {'nameEN': en, 'nameUK': uk, 'grams': float(grams), 'source': f'diary p. {page}'}
    # A diary measure replaces a USDA one with the same Ukrainian label.
    rest = [p for p in food['portions'] if p['nameUK'] != uk]
    diary = [p for p in rest if p.get('source')]
    usda = [p for p in rest if not p.get('source')]
    food['portions'] = diary + [portion] + usda
    added += 1
if missing:
    print('MISSING', missing); sys.exit(1)
json.dump(catalog, open('foods.json', 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(added, 'diary portions')
