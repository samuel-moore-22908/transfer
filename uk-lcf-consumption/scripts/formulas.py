import sys, glob, os, re, json
import pandas as pd
sys.stdout.reconfigure(encoding='utf-8')
root, out = sys.argv[1], sys.argv[2]
res={}
for f in sorted(glob.glob(os.path.join(root,'*/UKDA-*/mrdoc/excel/*volume_f*'))):
    sn=os.path.relpath(f,root).split(os.sep)[0]
    d=pd.read_excel(f, sheet_name='Part 3', header=None, dtype=str).fillna('')
    rows=[' '.join(c.strip() for c in r if c.strip()) for r in d.values]
    cur=None; defs={}
    for i,r in enumerate(rows):
        m=re.match(r'^(P\d{3}[a-z]*)\s+(.*)$', r, re.I)
        if m and ('|' not in r) and len(m.group(1))<=7 and not r.lower().startswith('p') is False:
            pass
        # first column code, second desc
        cells=[c.strip() for c in d.values[i] if c.strip()]
        if cells and re.fullmatch(r'P\d{3}[a-z]{0,2}', cells[0], re.I) and len(cells)>=2:
            cur=cells[0].lower(); defs[cur]={'desc':' '.join(cells[1:]),'text':''}
        elif cur and r:
            defs[cur]['text']+=(' '+r)
    res[sn]={k:v for k,v in defs.items() if re.match(r'p(5[0-9]{2}|6[0-3][0-9])',k)}
json.dump(res, open(out,'w'), indent=1)
for sn,v in res.items(): print(sn, len(v), sorted(k for k in v if k.startswith('p6'))[:60])
