import glob, os, re, json
import pandas as pd, numpy as np
YRS={'7272':'2011','7472':'2012','7702':'2013','7992':'2014','8210':'2015-16','8351':'2016-17','8459':'2017-18','8686':'2018-19','8803':'2019-20','9022':'2020-21','9123':'2021-22','9335':'2022-23','9468':'2023-24','9603':'2024-25'}
def dvhh_path(root, sn):
    fs=[f for f in glob.glob(os.path.join(root,sn,'*/stata/*/*dvhh*.dta')) if 'urban' not in f and 'q1' not in f and 'quarter' not in f]
    if sn=='9603': fs=[f for f in fs if 'v3' in f]
    assert len(fs)==1, fs; return fs[0]
def load(root, sn, path=None):
    r=pd.io.stata.StataReader(path or dvhh_path(root,sn)); df=r.read(convert_categoricals=False)
    lab={k.lower():v for k,v in r.variable_labels().items()}
    df.columns=[c.lower() for c in df.columns]; return df, lab
def clean(text):
    t=re.sub(r'(?i)sum of (the )?codes?|sum of|equals the|straight copy of|\(see note \d+\)\.?|\(as [^)]*\)','',text)
    t=re.sub(r'(?i)\bminus\b','-',t); t=re.sub(r'(?i)\band\b',',',t)
    return t
def terms(text):
    """return list of (sign, code) handling nested parens with minus"""
    t=clean(text)
    toks=re.findall(r'[A-Za-z]{1,2}[0-9][0-9A-Za-z]*|[+\-(),]', t)
    out=[]; stack=[1]; sign=1; prev=None
    for tk in toks:
        if tk in '+,': sign=1
        elif tk=='-': sign=-1
        elif tk=='(':
            stack.append(stack[-1]*sign); sign=1
        elif tk==')':
            stack.pop(); sign=1
        else:
            out.append((stack[-1]*sign, tk.lower())); sign=1
    return out
def resolve(code, cols):
    if code in cols: return code
    for alt in (re.sub(r'u$','p',code), re.sub(r'p$','',code), code+'p'):
        if alt in cols: return alt
    return None
