import copy
import json
import unittest
from pathlib import Path
from validate_catalog import validate_catalog
class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.pack = json.loads(Path('activity-catalog/catalog.json').read_text())
    def check(self): return validate_catalog(json.dumps(self.pack).encode())
    def test_valid(self): self.assertEqual(self.check(), 1)
    def test_duplicate(self):
        self.pack['activities'].append(copy.deepcopy(self.pack['activities'][0]))
        with self.assertRaises(AssertionError): self.check()
    def test_bundled_override(self):
        self.pack['activities'][0]['id'] = 'quiet.soft'
        with self.assertRaises(AssertionError): self.check()
    def test_remote_code(self):
        self.pack['activities'][0]['url'] = 'https://example.com/payload'
        with self.assertRaises(AssertionError): self.check()
    def test_step_extra(self):
        self.pack['activities'][0]['steps'][0]['script'] = 'run()'
        with self.assertRaises(AssertionError): self.check()
    def test_oversize(self):
        with self.assertRaises(AssertionError): validate_catalog(b' ' * (256*1024+1))
    def test_wrong_types(self):
        self.pack['activities'][0]['estimatedSeconds'] = True
        with self.assertRaises(AssertionError): self.check()
    def test_overlong_optional(self):
        self.pack['activities'][0]['answer'] = 'a'*2001
        with self.assertRaises(AssertionError): self.check()
