"""Validate the public catalogue before publication; no third-party dependencies."""
import json
from pathlib import Path
from validate_packs import validate
KEYS = set('schemaVersion id title category language estimatedSeconds description steps requiresVisualAttention requiresInput accessibleAlternatives author attribution contentLicense answer reflectionQuestion contentVersion source reveal media'.split())
def validate_catalog(raw):
    assert len(raw) <= 256 * 1024
    def depth(x):
        if isinstance(x, dict): return 1 + max(map(depth, x.values()), default=0)
        if isinstance(x, list): return 1 + max(map(depth, x), default=0)
        return 0
    pack = json.loads(raw)
    assert depth(pack) <= 8
    assert set(pack) == {'schemaVersion', 'activities'}
    count = validate(pack)
    for a in pack['activities']:
        assert set(a) <= KEYS
        assert a['id'].startswith('community.')
        assert a['contentLicense'] == 'CC-BY-4.0'
        for key in ('answer', 'reflectionQuestion'):
            if key in a: assert isinstance(a[key], str) and len(a[key]) <= 2000
        for step in a['steps']:
            assert set(step) == ({'kind', 'seconds'} if step['kind'] in ('thinking', 'silence') else {'kind', 'text'})
    return count
if __name__ == '__main__':
    print(f"{validate_catalog(Path('activity-catalog/catalog.json').read_bytes())} valid community activities")
