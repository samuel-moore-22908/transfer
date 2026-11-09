import sys, json, re
sys.path.insert(0, sys.argv[3]); from common import *
sys.stdout.reconfigure(encoding='utf-8')
root=sys.argv[1]; F=json.load(open(sys.argv[2])); out=sys.argv[4]
sns=sys.argv[5].split(',') if len(sys.argv)>5 else list(YRS)
def tform(F, sn, k, cols):
    """household-total formula: adult formula (B codes as is, C codes -> their t version) + child-only C codes"""
    ka, kc = ('p620p','p620cp') if k=='p620' else (k, k+'c')
    a=terms(F[sn][ka]['text']); c=terms(F[sn][kc]['text'])
    f={}
    for s,code in a:
        if re.match(r'c[a-z0-9]', code) and (code+'t') in cols: f[code+'t']=s
        else: f[code]=s
    adult={code for _,code in a}
    for s,code in c:
        base=code[:-1] if code.endswith('c') else code
        if base in adult: continue            # already covered by base+'t'
        if code in cols: f.setdefault(code, s)  # child-only spending: add the child variable itself
        elif (base+'t') in cols: f.setdefault(base+'t', s)
        else: f.setdefault(code, s)
    return f
res={}
for sn in sns:
    df,lab=load(root,sn); cols=set(df.columns)
    tol=0.3 if sn=='9603' else 0.011
    num=[c for c in df.columns if pd.api.types.is_numeric_dtype(df[c]) and not c.startswith(('p6','weight','cal_','case','non_'))]
    X=df[num].fillna(0).astype(float)
    res[sn]={}
    for k in [f'p6{i:02d}' for i in range(1,13)]+['p620']:
        tgt=k+'t' if k!='p620' else 'p620tp'
        f=tform(F,sn,k,cols)
        f2={}; missing=[]
        for code,s in f.items():
            rc=resolve(code,cols)
            if rc: f2[rc]=f2.get(rc,0)+s
            else: missing.append(code)
        est=sum(s*X[c] if c in X else s*df[c].fillna(0) for c,s in f2.items())
        r=(df[tgt]-est).values; start=(np.abs(r)<tol).mean()
        steps=[]
        for it in range(10):
            base=(np.abs(r)<tol).mean()
            if base>0.9995: break
            best=None
            for s in (1,-1):
                sc=(np.abs(r[:,None]-s*X.values)<tol).mean(0); j=sc.argmax()
                if best is None or sc[j]>best[0]: best=(sc[j],s,num[j])
            if best[0]<=base+0.0005: break
            r=r-best[1]*X[best[2]].values; f2[best[2]]=f2.get(best[2],0)+best[1]
            steps.append((('+' if best[1]>0 else '-')+best[2], lab.get(best[2],'')[:50], round(best[0]*100,1)))
        final=(np.abs(r)<tol).mean()
        res[sn][tgt]={'formula':{c:s for c,s in f2.items() if s!=0},'missing':missing,'start':start,'final':final,'steps':steps,
                      'wresid': float(np.average(r, weights=df['weighta'] if 'weighta' in df else df['cal_weight_annual']))}
        print(f'{YRS[sn]} {tgt}: built {start*100:.1f}% -> {final*100:.1f}%  resid(wmean)={res[sn][tgt]["wresid"]:+.3f} missing={missing}')
        for s in steps: print('        ',s)
json.dump(res, open(out,'w'), indent=1)
