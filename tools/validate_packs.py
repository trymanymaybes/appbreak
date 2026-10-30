#!/usr/bin/env python3
"""Validate inert activity content with the Python standard library."""
import json, re, sys
from pathlib import Path
CATEGORIES={'quiet','movement','breathing','hydration','quiz','imagination','read-aloud'}
def validate(pack):
    assert pack['schemaVersion']==1, 'Unsupported schema'
    activities=pack['activities']; assert 1<=len(activities)<=200
    seen=set()
    for a in activities:
        assert a['schemaVersion']==1
        assert re.fullmatch(r'[a-z0-9._-]{1,80}',a['id']) and a['id'] not in seen
        seen.add(a['id'])
        assert a['category'] in CATEGORIES and type(a['estimatedSeconds']) is int and 20<=a['estimatedSeconds']<=300
        for key in ['title','language','description','author','attribution','contentLicense']:
            assert isinstance(a[key],str) and 1<=len(a[key])<=2000, key
        for key in ['requiresVisualAttention','requiresInput']: assert type(a[key]) is bool
        assert 1<=len(a['accessibleAlternatives'])<=20
        assert all(isinstance(s,str) and 1<=len(s)<=2000 for s in a['accessibleAlternatives'])
        assert 1<=len(a['steps'])<=30
        silent=0
        for step in a['steps']:
            assert step['kind'] in {'instruction','narration','thinking','silence','completion'}
            if step['kind'] in {'silence','thinking'}:
                assert type(step['seconds']) is int and 1<=step['seconds']<=300
                silent+=step['seconds']
            else: assert isinstance(step['text'],str) and 1<=len(step['text'])<=2000
        assert silent<=a['estimatedSeconds']
        if 'contentVersion' in a: assert type(a['contentVersion']) is int and a['contentVersion']>=1
        if 'source' in a: assert isinstance(a['source'],str) and 1<=len(a['source'].strip())<=2000
        if 'reveal' in a: assert a['reveal']=='manual' and 'answer' in a
        if 'media' in a:
            assert isinstance(a['media'],list) and len(a['media'])<=4
            from urllib.parse import urlsplit
            for m in a['media']:
                assert set(m)=={'url','alt','fallbackText'}
                assert all(isinstance(v,str) and 1<=len(v.strip())<=2000 for v in m.values())
                u=urlsplit(m['url']); assert u.scheme=='https' and u.hostname and not u.username and not u.password and not u.port
    return len(activities)
if __name__=='__main__':
    for name in sys.argv[1:] or ['assets/activities.json']:
        p=Path(name); assert p.stat().st_size<=1024*1024
        print(f'{name}: {validate(json.loads(p.read_text()))} valid activities')
