"""Published protocol profile plus schema/reference/capability checks."""
import json
from pathlib import Path
from jsonschema import Draft202012Validator
from validate_packs import validate
from validate_catalog import validate_catalog
ROOT = Path(__file__).resolve().parents[1]
def load(p): return json.loads((ROOT / p).read_text())
def validate_bundle(b, activities):
    Draft202012Validator(load('schemas/routine-bundle.schema.json')).validate(b)
    ids=set()
    for d in b['dependencies']:
        assert d['id'] not in ids, 'Duplicate dependency'
        ids.add(d['id'])
        assert d['id'] in activities, 'Missing dependency'
        a=activities[d['id']]
        assert a.get('contentVersion',1)>=d['minimumVersion'], 'Dependency version'
        assert a['estimatedSeconds']<=b['defaults']['breakSeconds'], 'Activity exceeds break'
    return True

def main():
    schema=Draft202012Validator(load('schemas/activity-pack.schema.json'))
    available={}
    for path in ['assets/activities.json','activity-catalog/v1/catalog.json','activity-catalog/activity.template.json']:
        pack=load(path);schema.validate(pack);validate(pack)
        for a in pack['activities']:
            assert a.get('contentVersion',0)>=1 and a.get('source','').strip(), 'Publication metadata missing'
            assert all(a[k].strip() for k in ['title','description','author','attribution','contentLicense'])
            assert any(s['kind']=='instruction' for s in a['steps'])
            assert any(s['kind']=='completion' for s in a['steps'])
            if not path.endswith('template.json'):
                assert a['id'] not in available, 'Identity collision'
                available[a['id']]=a
    validate_catalog((ROOT/'activity-catalog/catalog.json').read_bytes())
    validate_catalog((ROOT/'activity-catalog/v1/catalog.json').read_bytes())
    p=load('routine-bundles/v1/catalog.json')
    assert set(p)=={'schemaVersion','bundles'} and type(p['schemaVersion']) is int and p['schemaVersion']==1
    assert len(p['bundles'])<=100
    ids=set()
    for b in p['bundles']:
        assert b['id'] not in ids;ids.add(b['id']);validate_bundle(b,available)
    validate_bundle(load('routine-bundles/bundle.template.json'),available)
    print(f'Validated {len(available)} activities and {len(ids)} optional bundles')
if __name__=='__main__': main()
