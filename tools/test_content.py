import copy, unittest
from jsonschema import ValidationError
from validate_content import load, validate_bundle, main
from validate_packs import validate
class ContentTests(unittest.TestCase):
    def setUp(self):
        self.b=load('routine-bundles/bundle.template.json')
        self.pack=load('assets/activities.json')
        self.activities={a['id']:a for a in self.pack['activities']}
    def test_all_published(self): main()
    def test_invalid_bundles(self):
        for field,value in [('schemaVersion',2),('minimumProtocol',2),('version',0),('customisable',['enabled'])]:
            b=copy.deepcopy(self.b);b[field]=value
            with self.assertRaises(ValidationError):validate_bundle(b,self.activities)
        b=copy.deepcopy(self.b);b['defaults']['enabled']=True
        with self.assertRaises(ValidationError):validate_bundle(b,self.activities)
    def test_dependencies(self):
        for deps in [[{'id':'missing','minimumVersion':1}],[{'id':'quiet.soft','minimumVersion':9}],self.b['dependencies']*2]:
            b=copy.deepcopy(self.b);b['dependencies']=deps
            with self.assertRaises(AssertionError):validate_bundle(b,self.activities)
    def test_media_alternative_and_version(self):
        for media in [[{'url':'javascript:alert(1)','alt':'A circle','fallbackText':'Imagine a circle'}],[{'url':'https://example.org/a.png','alt':' ','fallbackText':'Imagine a circle'}]]:
            p=copy.deepcopy(self.pack);p['activities'][0]['media']=media
            with self.assertRaises(AssertionError):validate(p)
        p=copy.deepcopy(self.pack);p['activities'][0]['contentVersion']=True
        with self.assertRaises(AssertionError):validate(p)
