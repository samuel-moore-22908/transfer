import sys, json, re, glob, os
sys.path.insert(0, sys.argv[3]); from common import *
sys.stdout.reconfigure(encoding='utf-8')
root=sys.argv[1]; FINAL=json.load(open(sys.argv[2])); F=json.load(open(sys.argv[4])); out=sys.argv[5]
CAT={'p601t':'01 Food & non-alcoholic drinks','p602t':'02 Alcohol, tobacco & narcotics','p603t':'03 Clothing & footwear','p604t':'04 Housing, water, electricity, gas','p605t':'05 Furnishings & household equipment','p606t':'06 Health','p607t':'07 Transport','p608t':'08 Communication','p609t':'09 Recreation & culture','p610t':'10 Education','p611t':'11 Restaurants & hotels','p612t':'12 Misc goods & services','p620tp':'Non-consumption expenditure'}
rows=[]
for sn,yr in YRS.items():
    df,lab=load(root,sn); cols=set(df.columns)
    for tgt,v in FINAL[sn].items():
        k=tgt[:4]; keys=[k,k+'c',k+'t'] if tgt!='p620tp' else ['p620p','p620cp','p620tp']
        doc=set()
        for kk in keys:
            for s,c in terms(F[sn][kk]['text']):
                rc=resolve(c,cols); doc.add(rc or c)
                if rc and re.match(r'c[a-z0-9]',rc) and rc+'t' in cols: doc.add(rc+'t')
                if rc and rc.endswith('c') and rc[:-1]+'t' in cols: doc.add(rc[:-1]+'t')
        for c,s in v['formula'].items():
            rows.append(dict(year=yr, sn=sn, total=tgt, category=CAT[tgt], variable=c, sign=s,
                             source='Volume F' if c in doc else 'empirical (not in Volume F)',
                             kind='diary/COICOP item (c-code, adults+children)' if re.match(r'c',c) and c.endswith('t') else ('diary item, children only' if re.match(r'c',c) and c.endswith('c') else ('diary item' if c.startswith('c') else ('questionnaire (b-code)' if c.startswith('b') else 'derived (p-code)'))),
                             label=lab.get(c,'')))
        if v['extra']:
            rows.append(dict(year=yr,sn=sn,total=tgt,category=CAT[tgt],variable=v['extra'],sign=1,source='empirical (not in Volume F)',kind='rule',label='b2291 = accident, sickness & animal insurance; p087 = other insurance incl. deductions from wages'))
        # documented but not in public file
        for kk in keys:
            for s,c in terms(F[sn][kk]['text']):
                if resolve(c,cols) is None:
                    rows.append(dict(year=yr,sn=sn,total=tgt,category=CAT[tgt],variable=c,sign=s,source='in Volume F but NOT in public dvhh',kind='',label=''))
D=pd.DataFrame(rows).drop_duplicates(subset=['year','total','variable','source'])
D.to_csv(out,index=False)
print(D.groupby(['year','source']).size().unstack().to_string())
print(D[D.source.str.startswith('empirical')].groupby('variable').agg(years=('year',lambda x: f"{x.iloc[0]}..{x.iloc[-1]} ({len(set(x))})"), total=('total',lambda x: ','.join(sorted(set(x)))), label=('label','last')).to_string())
print(D[D.source.str.startswith('in Volume')].groupby('variable').agg(years=('year',lambda x: len(set(x))), total=('total',lambda x: ','.join(sorted(set(x))))).to_string())
# 2015 Q1 check with 2014 and 2015-16 formulas
q=[f for f in glob.glob(os.path.join(root,'8210/*/stata/*/2015q1_dvhh_ukanon.dta'))][0]
dq,_=load(root,'8210',q); dq=dq[dq.gorx<=9]
for src in ['7992','8210']:
    res=[]
    for tgt,v in FINAL[src].items():
        if not all(c in dq for c in v['formula']): res.append(f'{tgt}:missing {[c for c in v["formula"] if c not in dq]}'); continue
        e=sum(s*dq[c].fillna(0) for c,s in v['formula'].items())
        if v['extra']=='max(b2291-p087,0)': e=e+(dq.b2291-dq.p087).clip(lower=0)
        res.append(f'{tgt}:{((dq[tgt]-e).abs()<0.011).mean()*100:.1f}')
    print('2015Q1 file with',YRS[src],'formulas:',' '.join(res))
