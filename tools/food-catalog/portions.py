import json, re
d = json.load(open('foods.json'))
SIZE = {'large': ('piece, large','шт. (великий розмір)'), 'medium': ('piece, medium','шт. (середній розмір)'), 'small': ('piece, small','шт. (малий розмір)'), 'extra large': ('piece, extra large','шт. (дуже великий)')}
FIXED = {
 'cup': ('cup (240 ml)','склянка (240 мл)'),
 'cup, chopped': ('cup, chopped','склянка нарізаного'), 'cup chopped': ('cup, chopped','склянка нарізаного'),
 'cup, sliced': ('cup, sliced','склянка нарізаного скибками'), 'cup slices': ('cup, sliced','склянка нарізаного скибками'),
 'cup, diced': ('cup, diced','склянка кубиками'), 'cup, shredded': ('cup, shredded','склянка тертого'),
 'cup, whole': ('cup, whole','склянка цілих'), 'cup (8 fl oz)': ('cup (240 ml)','склянка (240 мл)'),
 'tbsp': ('tbsp','ст. ложка'), 'tablespoon': ('tbsp','ст. ложка'), 'tsp': ('tsp','ч. ложка'),
 'slice': ('slice','скибка'), 'slice, thin': ('thin slice','тонка скибка'), 'fillet': ('fillet','філе'),
 'NLEA serving': ('serving (label)','порція (за етикеткою)'), 'cherry': ('berry','ягода'), 'clove': ('clove','зубчик'),
 'breast, bone and skin removed': ('breast, boneless','філе, 1 шт.'), 'bar': ('bar','плитка'), 'leaf': ('leaf','листок'),
 'fruit without refuse': ('piece','шт.'), 'pepper': ('piece','шт.'), 'egg': ('egg', 'яйце'),
}
def rank(p):
    n = p['nameEN']
    if n.startswith('piece, medium'): return 0
    if n.startswith(('piece', 'egg', 'slice', 'fillet', 'breast', 'bar', 'clove', 'berry', 'leaf', 'thin slice')): return 1
    if n in ('tbsp', 'tsp'): return 2
    if n.startswith('serving'): return 3
    return 4
def fmt(a):
    a = float(a); return str(int(a)) if a == int(a) else str(a).replace('.', ',')
total = 0
for r in d:
    out, seen = [], set()
    for p in r['portions']:
        m = re.match(r'^([\d.]+)\s+(.*)$', p['label'])
        if not m: continue
        amount, rest = m.group(1), m.group(2).strip()
        key = None
        for s in ['extra large','large','medium','small']:
            if rest == s or rest.startswith(s + ' (') or rest.startswith(s + ','):
                key = SIZE[s]; break
        if key is None:
            if rest.startswith('fruit (') : key = ('piece','шт.')
            else: key = FIXED.get(rest)
        if key is None or key[0] in seen: continue
        seen.add(key[0])
        if float(amount) <= 0: continue
        # Normalised to one unit, e.g. "0.5 cup = 120 g" becomes "1 cup = 240 g".
        out.append({'nameEN': key[0], 'nameUK': key[1], 'grams': round(p['grams'] / float(amount), 1)})
    # Countable units first: "2 eggs" is the most natural way to log, then spoons, then cups.
    out.sort(key=rank)
    r['portions'] = out; total += len(out)
catalog = {'source': 'USDA FoodData Central, SR Legacy (April 2018 release), public domain (CC0 1.0)',
           'sourceURL': 'https://fdc.nal.usda.gov/', 'foods': d}
json.dump(catalog, open('foods.json','w',encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(total, sum(1 for r in d if not r['portions']))
for r in d[:6]: print(r['nameUK'], [(p['nameUK'],p['grams']) for p in r['portions']])
