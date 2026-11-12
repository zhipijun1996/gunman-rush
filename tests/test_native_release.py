"""Native shipping uses the real formal world, not all project experiments."""
import sys,json,re,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import export_native as native
import export_workbench as shared
from world.build import build
class NativeRelease(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  build();cls.plan=shared.manifest(formal_only=True);cls.original=(native.ROOT/'export_presets.cfg').read_text()
 def test_formal_rooms_and_raw_catalog(self):
  p=self.plan;self.assertEqual(p['rooms'],p['formal_rooms']);self.assertEqual(len(p['rooms']),43)
  self.assertNotIn('V-R12',p['rooms']);self.assertTrue(p['formal_only'])
  icon=re.search(r'^config/icon="res://([^"\n]+)"$',(native.ROOT/'project.godot').read_text(),re.M)
  self.assertIsNotNone(icon)
  self.assertTrue(any(r['path']==icon[1] for r in p['files']))
  self.assertFalse(any(r['path']=='game/application/demo_app.gd' for r in p['files']))
  self.assertIn('assets/plains_v3/hero/manifest.json',p['raw_files'])
  self.assertTrue(any(r['path']=='assets/plains_v3/effects/combat_atlas.png' for r in p['files']))
  self.assertFalse(any(r['path'].startswith(native.DENIED) or re.search(r'assets/underworld_plains/[^/]+/sources/',r['path']) for r in p['files']))
  self.assertNotIn('build/workbench/preview-world.json',p['raw_files'])
 def test_both_native_presets_use_controlled_runtime(self):
  for platform,n in [('windows',0),('android',1)]:
   text=native.configured_preset(self.original,self.plan,platform)
   header=text.split(f'[preset.{n}]',1)[1].split(f'[preset.{n}.options]',1)[0]
   self.assertIn('export_filter="resources"',header);self.assertIn('custom_features="fixed_world_release"',header)
   self.assertIn('res://game/world/regions/P/rooms/P-R21.tscn',header);self.assertNotIn('V-R12',header)
   self.assertIn('include_filter=""',header)
 def test_development_payload_rejected_before_runtime_validation(self):
  class BadPack:
   entries={'docs/stale-report.json':None}
  with self.assertRaisesRegex(ValueError,'Development payload leaked'):native.verify_resources(BadPack(),self.plan)
 def test_signing_credentials_not_in_repo(self):
  import sign_android_release as signing
  self.assertFalse(signing.KEY_DIR.resolve().is_relative_to(native.ROOT.resolve()))
  self.assertIn('package/signed=false',self.original)
if __name__=='__main__':unittest.main()
