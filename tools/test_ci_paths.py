"""Exercise the actual configured paths-ignore sets for content and app changes."""
import ast, fnmatch, re, unittest
from pathlib import Path
class CIPathsTest(unittest.TestCase):
    def test_content_changes_skip_source_and_protocol_changes_do_not(self):
        workflow=(Path(__file__).resolve().parents[1]/'.github/workflows/checks.yml').read_text()
        exclusions=[ast.literal_eval(x) for x in re.findall(r'paths-ignore: (\[.*\])',workflow)]
        self.assertEqual(len(exclusions),2) # push and pull_request
        for patterns in exclusions:
            builds=lambda paths:any(not any(fnmatch.fnmatchcase(p,pattern) for pattern in patterns) for p in paths)
            self.assertFalse(builds(['activity-catalog/v1/catalog.json']))
            self.assertFalse(builds(['routine-bundles/v1/catalog.json','docs/CONTENT-PROTOCOL.md']))
            for path in ['assets/activities.json','schemas/activity-pack.schema.json','tools/validate_content.py','lib/services/bundle_catalog.dart','lib/ui/content_media.dart','android/app/src/main/kotlin/org/appbreak/companion/ActivityCatalog.kt','.github/workflows/content.yml']:
                self.assertTrue(builds(['activity-catalog/v1/catalog.json',path]),path)
