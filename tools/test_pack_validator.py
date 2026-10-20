import json,unittest
from pathlib import Path
from validate_packs import validate
class PackTests(unittest.TestCase):
    def setUp(self): self.pack=json.loads(Path('assets/activities.json').read_text())
    def test_valid(self): self.assertEqual(validate(self.pack),12)
    def test_duplicate_id(self):
        self.pack['activities'][1]['id']=self.pack['activities'][0]['id']
        with self.assertRaises(AssertionError):validate(self.pack)
    def test_oversize_duration(self):
        self.pack['activities'][0]['estimatedSeconds']=999
        with self.assertRaises(AssertionError):validate(self.pack)
    def test_missing_alternative(self):
        self.pack['activities'][0]['accessibleAlternatives']=[]
        with self.assertRaises(AssertionError):validate(self.pack)
    def test_unknown_step(self):
        self.pack['activities'][0]['steps'][0]['kind']='execute'
        with self.assertRaises(AssertionError):validate(self.pack)
    def test_unknown_version(self):
        self.pack['schemaVersion']=99
        with self.assertRaises(AssertionError):validate(self.pack)
if __name__=='__main__':unittest.main()
