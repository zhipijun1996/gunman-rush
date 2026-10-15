"""Real unprivileged filesystem UID guard cases, not engine execution or filesystem mocks."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = r'''
import hashlib,json,os,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(sys.argv[1])/'tools'))
from run_forest_h_slice_tests import DEV_UIDS,preserve_new_unreferenced_uids
case=sys.argv[2]
assert os.geteuid()==1000, 'Permission-denial evidence requires actual unprivileged euid1000'
with tempfile.TemporaryDirectory() as temp:
 root=Path(temp);relative=DEV_UIDS[0];side=root/relative;side.parent.mkdir(parents=True)
 original=b'uid://actual_permission_guard_fixture\n';side.write_bytes(original)
 private=root/'private';private.mkdir()
 reference=private/'consumer.gd'
 reference.write_text('const CONSUMER=preload("uid://actual_permission_guard_fixture")\n' if case!='readable_unreferenced' else 'const NO_UID_REFERENCE=true\n')
 denied=False
 try:
  if case=='denied_reference':
   private.chmod(0)
   try:list(private.iterdir())
   except PermissionError:denied=True
   assert denied, 'chmod000 must actually deny directory enumeration before helper runs'
  outcome=preserve_new_unreferenced_uids(root,{},[],root/'archive')
  archived=root/'archive'/relative
  result={'scope':'real temporary filesystem helper fixture; no Godot/native run','case':case,
          'euid':os.geteuid(),'actual_directory_permission_denied':denied,
          'uid_preserved':side.is_file(),'preserved_original_bytes':side.read_bytes()==original if side.is_file() else False,
          'archive_exists':archived.is_file(),'archive_matches_original':archived.read_bytes()==original if archived.is_file() else False,
          'original_sha256':hashlib.sha256(original).hexdigest(),'outcome':outcome}
 finally:private.chmod(0o700)
 print(json.dumps(result))
'''


def run_actual_case(case):
    def unprivileged():
        os.setgroups([])
        os.setgid(1000)
        os.setuid(1000)
    completed = subprocess.run([sys.executable, '-c', PROBE, str(ROOT), case],
                               capture_output=True, text=True, timeout=30,
                               preexec_fn=unprivileged if os.geteuid() == 0 else None)
    if completed.returncode:
        raise AssertionError({'exit_code': completed.returncode, 'stdout': completed.stdout, 'stderr': completed.stderr})
    return json.loads(completed.stdout)


class ForestUIDPreservationTests(unittest.TestCase):
    def test_actual_chmod000_directory_scan_failure_preserves_uid(self):
        result = run_actual_case('denied_reference')
        self.assertEqual(result['euid'], 1000)
        self.assertTrue(result['actual_directory_permission_denied'])
        self.assertTrue(result['uid_preserved'], result)
        self.assertTrue(result['preserved_original_bytes'], result)
        self.assertFalse(result['archive_exists'], result)
        self.assertTrue(result['outcome'][0]['unreadable_or_unresolved'], result)

    def test_readable_reference_preserves_uid(self):
        result = run_actual_case('readable_reference')
        self.assertFalse(result['actual_directory_permission_denied'])
        self.assertTrue(result['uid_preserved'], result)
        self.assertTrue(result['preserved_original_bytes'], result)
        self.assertFalse(result['archive_exists'], result)
        self.assertTrue(result['outcome'][0]['references'], result)

    def test_readable_unreferenced_known_uid_is_archived_then_removed(self):
        result = run_actual_case('readable_unreferenced')
        self.assertFalse(result['actual_directory_permission_denied'])
        self.assertFalse(result['uid_preserved'], result)
        self.assertTrue(result['archive_exists'], result)
        self.assertTrue(result['archive_matches_original'], result)
        self.assertTrue(result['outcome'][0]['removed'], result)
        self.assertEqual(result['outcome'][0]['sha256'], result['original_sha256'])


if __name__ == '__main__':
    unittest.main()
