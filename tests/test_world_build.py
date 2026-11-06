"""Current source ownership, export completeness and manual scene preservation."""
from pathlib import Path
import copy
import json
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from world.build import build

class BuildTests(unittest.TestCase):
    def test_build_without_imported_archive_preserves_authored_scenes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            shutil.copytree(ROOT/'config/world',root/'config/world')
            shutil.copytree(ROOT/'game/world/regions',root/'game/world/regions')
            before={str(p.relative_to(root)):p.read_bytes() for p in (root/'game').rglob('*.tscn')}
            contracts,bundle=build(root)
            self.assertEqual(len(contracts['rooms']),216)
            actions={a['action_ref']:a for r in contracts['rooms'] for a in r['interactions']}
            self.assertEqual(actions['tutorial_move']['trigger'],'accepted_player_action')
            self.assertEqual(actions['defeat_P_WINDKEEPER']['trigger'],'actual_boss_victory')
            self.assertFalse(actions['station_briefing']['arriving_does_not_grant'])
            self.assertEqual(set(bundle['rooms']),{'P-R03','P-R01','P-R08','P-R06','P-R14'})
            self.assertEqual(before,{str(p.relative_to(root)):p.read_bytes() for p in (root/'game').rglob('*.tscn')})
            (root/'game/world/regions/P/rooms/P-R03.tscn').unlink()
            with self.assertRaisesRegex(ValueError,'scene missing'):build(root)

    def test_changed_manual_geometry_is_consumed(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            shutil.copytree(ROOT/'config/world',root/'config/world')
            shutil.copytree(ROOT/'game/world/regions',root/'game/world/regions')
            original,bundle=build(root)
            compiled=copy.deepcopy(original)
            next(r for r in compiled['rooms'] if r['room_id']=='P-R03')['camera']['lookahead_basis']='compiler_semantic_change'
            with patch('world.build.compile_contracts',return_value=(compiled,{'passed':True})):
                _,compiler_bundle=build(root)
            self.assertEqual(bundle['sources'],compiler_bundle['sources'])
            self.assertNotEqual(bundle['content_version'],compiler_bundle['content_version'])
            path=root/'config/world/construction.json'
            data=json.loads(path.read_text())
            room=next(r for r in data['rooms'] if r['room_id']=='P-R03')
            room['camera']['lookahead_basis']='test_explicit_camera_intent'
            path.write_text(json.dumps(data))
            changed,new_bundle=build(root)
            self.assertNotEqual(bundle['content_version'],new_bundle['content_version'])
            self.assertEqual(next(r for r in changed['rooms'] if r['room_id']=='P-R03')['camera']['lookahead_basis'],'test_explicit_camera_intent')

if __name__=='__main__':unittest.main()
