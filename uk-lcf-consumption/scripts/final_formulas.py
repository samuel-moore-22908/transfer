"""Final household-total formulas per release (England), from Volume F + empirical fixes, verified against published p6xxt."""
import sys, json, re
sys.path.insert(0, sys.argv[3]); from common import *
sys.stdout.reconfigure(encoding='utf-8')
root=sys.argv[1]; Bt=json.load(open(sys.argv[2])); out=sys.argv[4]
NONLIN={}   # (sn,tgt) -> extra series function
FINAL={}; SUMMARY=[]
for sn,yr in YRS.items():
    df,lab=load(root,sn); df=df[df.gorx<=9].reset_index(drop=True); cols=set(df.columns)
    tol=0.3 if sn=='9603' else 0.011
    w=df['weighta'] if 'weighta' in df else df['cal_weight_annual']
    FINAL[sn]={}
    for tgt in [f'p6{i:02d}t' for i in range(1,13)]+['p620tp']:
        f=dict(Bt[sn][tgt]['formula'])
        if tgt=='p611t':
            for c in ('b260','b260c'): f.pop(c,None)
            f['b260t']=1
        extra=None
        if tgt=='p607t' and 'b487' in f:   # from 2013 air fares come from b487/b488; only children's diary air fares remain
            for code in ('c73311','c73312'):
                f.pop(code,None); f.pop(code+'t',None)
                if code+'c' in cols: f[code+'c']=1
        if tgt=='p612t' and 'b2291' in cols:
            extra=('max(b2291-p087,0)', (df.b2291.fillna(0)-df.p087.fillna(0)).clip(lower=0))
        if tgt=='p620tp':
            if 'b2291' in cols:
                f.pop('b2291',None); extra=('min(b2291,p087)', np.minimum(df.b2291.fillna(0), df.p087.fillna(0)))
            if 'p129t' not in f:  # second dwelling: try p129t in place of its item codes, keep if it fits better
                g=dict(f); g['p129t']=1
                for c in ('ck1411','c41211','c45112','c94232'):
                    if g.get(c)==1: g.pop(c)
                ex=extra[1] if extra is not None else 0
                sc=lambda h: ((df[tgt]-sum(s*df[c].fillna(0) for c,s in h.items())-ex).abs()<tol).mean()
                if sc(g)>sc(f): f=g
        f={c:s for c,s in f.items() if s!=0}
        est=sum(s*df[c].fillna(0) for c,s in f.items())
        if extra is not None: est=est+extra[1]
        r=df[tgt]-est
        FINAL[sn][tgt]={'formula':f,'extra':extra[0] if extra else None}
        SUMMARY.append(dict(year=yr,var=tgt,n=len(df),match=round((r.abs()<tol).mean()*100,2),
            wmean_pub=round(np.average(df[tgt],weights=w),2), wmean_resid=round(np.average(r,weights=w),3),
            wmeanabs_resid=round(np.average(r.abs(),weights=w),3)))
    # total consumption from rebuilt categories
    est_tot=0
    for i in range(1,13):
        t=f'p6{i:02d}t'; ff=FINAL[sn][t]
        e=sum(s*df[c].fillna(0) for c,s in ff['formula'].items())
        if ff['extra']=='max(b2291-p087,0)': e=e+(df.b2291.fillna(0)-df.p087.fillna(0)).clip(lower=0)
        est_tot=est_tot+e
    r=df.p600t-est_tot
    SUMMARY.append(dict(year=yr,var='p600t',n=len(df),match=round((r.abs()<max(tol,0.05)).mean()*100,2),
        wmean_pub=round(np.average(df.p600t,weights=w),2), wmean_resid=round(np.average(r,weights=w),3), wmeanabs_resid=round(np.average(r.abs(),weights=w),3)))
    # identities
    SUMMARY.append(dict(year=yr,var='p600t==sum(p601t..p612t)',n=len(df),match=round(((df.p600t-df[[f"p6{i:02d}t" for i in range(1,13)]].sum(axis=1)).abs()<max(tol,0.05)).mean()*100,2)))
    SUMMARY.append(dict(year=yr,var='p630tp==p600t+p620tp',n=len(df),match=round(((df.p630tp-df.p600t-df.p620tp).abs()<max(tol,0.05)).mean()*100,2)))
json.dump(FINAL, open(out,'w'), indent=1)
S=pd.DataFrame(SUMMARY); S.to_csv(out.replace('.json','_verification.csv'), index=False)
pv=S.pivot(index='var', columns='year', values='match')[list(YRS.values())]
print(pv.to_string())
print(); print(S[S['var'].isin(['p600t','p604t','p609t','p612t','p620tp'])].pivot(index='var',columns='year',values='wmeanabs_resid')[list(YRS.values())].to_string())
