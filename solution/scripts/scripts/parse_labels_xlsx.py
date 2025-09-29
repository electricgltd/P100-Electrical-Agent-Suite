"""
Parse docs/GitHub/Colour_Labels_GitHub.xlsx and generate:
 - .github/labels.yml (merged)
 - docs/labels.md (human readable rollup)

Usage: python scripts/parse_labels_xlsx.py
"""
import sys
from pathlib import Path
import yaml

xlsx_path = Path('docs/GitHub/Colour_Labels_GitHub.xlsx')
if not xlsx_path.exists():
    print(f"Excel file not found: {xlsx_path}")
    sys.exit(2)

try:
    import pandas as pd
except Exception as e:
    print("pandas not installed. Please run: pip install pandas openpyxl")
    raise

# Read first sheet
xls = pd.read_excel(xlsx_path, sheet_name=None)
# Choose the first sheet
sheet_name = list(xls.keys())[0]
df = xls[sheet_name]

# Normalize column names
cols = {c.strip().lower(): c for c in df.columns}
# helper for finding likely columns
def find_column(*candidates):
    for cand in candidates:
        k = cand.lower()
        if k in cols:
            return cols[k]
    return None

name_col = find_column('name','label','label name')
color_col = find_column('color','colour','hex','hex colour','hexcolor')
desc_col = find_column('description','desc')
# Prefer an explicit 'Label roll ups' column (user provided). Also accept several common variants.
group_col = find_column('label roll ups', 'label roll-ups', 'label rollups', 'label roll up', 'label roll-up',
                        'group','type','category','area','agent')

if not name_col:
    print(f"Couldn't find a name/label column. Found columns: {list(df.columns)}")
    sys.exit(3)

labels = []
for _, row in df.iterrows():
    name = str(row[name_col]).strip() if pd.notna(row[name_col]) else None
    if not name or name.lower() in ['nan','none']:
        continue
    color = None
    if color_col and pd.notna(row[color_col]):
        color = str(row[color_col]).strip()
        # strip leading # and whitespace
        color = color.lstrip('#').strip()
        # if it's a float (Excel), format as int hex
        try:
            if color.replace('.','',1).isdigit():
                # treat as number
                color = format(int(float(color)),'06x')
        except Exception:
            pass
    desc = str(row[desc_col]).strip() if desc_col and pd.notna(row[desc_col]) else ''
    group = str(row[group_col]).strip() if group_col and pd.notna(row[group_col]) else ''
    labels.append({'name': name, 'color': color or 'ffffff', 'description': desc, 'group': group})

# Load existing labels.yml if present
labels_yml = Path('.github/labels.yml')
existing = {'labels': []}
if labels_yml.exists():
    try:
        existing = yaml.safe_load(labels_yml.read_text(encoding='utf-8')) or {'labels': []}
    except Exception:
        existing = {'labels': []}

# Build map by name (preserve existing if not overridden)
existing_map = {l['name']: l for l in existing.get('labels', [])}
for l in labels:
    # merge: override color/description if provided
    if l['name'] in existing_map:
        e = existing_map[l['name']]
        if l.get('color'):
            e['color'] = l['color']
        if l.get('description'):
            e['description'] = l['description']
        # preserve existing group if already present
        if l.get('group'):
            e['group'] = l['group']
    else:
        # new add
        nl = {'name': l['name'], 'color': l['color'], 'description': l['description']}
        if l.get('group'):
            nl['group'] = l['group']
        existing_map[l['name']] = nl

# Write merged labels.yml (sorted by name)
merged = {'labels': [existing_map[k] for k in sorted(existing_map.keys(), key=lambda s: s.lower())]}
labels_yml.write_text(yaml.safe_dump(merged, sort_keys=False, allow_unicode=True), encoding='utf-8')
print(f"Wrote {labels_yml} ({len(merged['labels'])} labels)")

# Create docs/labels.md rollup grouped by group
from collections import defaultdict
groups = defaultdict(list)
for l in merged['labels']:
    grp = l.get('group') or 'Ungrouped'
    groups[grp].append(l)

md = []
md.append('# Project labels rollup')
md.append('This file is generated from `docs/GitHub/Colour_Labels_GitHub.xlsx` and `.github/labels.yml`.')
md.append('')
for grp in sorted(groups.keys()):
    md.append(f'## {grp} ({len(groups[grp])})')
    md.append('')
    md.append('| Name | Color | Description |')
    md.append('| --- | --- | --- |')
    for l in sorted(groups[grp], key=lambda x: x['name'].lower()):
        color = l.get('color','')
        swatch = f"<span style='display:inline-block;width:14px;height:14px;background:#${color};border:1px solid #000;margin-right:6px;'></span> #{color}" if color else ''
        desc = l.get('description','') or ''
        md.append(f"| {l['name']} | {swatch} | {desc} |")
    md.append('')

out_md = Path('docs/labels.md')
out_md.write_text('\n'.join(md), encoding='utf-8')
print(f"Wrote {out_md}")

# Summary output
print('Groups:')
for grp in sorted(groups.keys()):
    print(f" - {grp}: {len(groups[grp])} labels")

# Done
sys.exit(0)
