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
from world.build import build, validate_services, validate_player, navigation_geometry

class BuildTests(unittest.TestCase):
    def test_focus_heal_rejects_unusable_parameters(self):
        data=json.loads((ROOT/'config/world/player.json').read_text())
        validate_player(data)
        for key,value in [('cost',-1),('heal',0),('charge_seconds',float('nan')),('charge_seconds',True),('keyboard_key',None),('gamepad_button',128)]:
            invalid=copy.deepcopy(data);invalid['focus_heal'][key]=value
            with self.subTest(key=key,value=value),self.assertRaisesRegex(ValueError,'focus heal'):
                validate_player(invalid)

    def test_navigation_map_uses_shared_physical_seams(self):
        _, bundle=build()
        rooms=bundle['rooms']
        layouts=navigation_geometry(rooms,bundle['start']['room'])
        for key,room in rooms.items():
            for door in room['doors']:
                if not door['target_implemented']: continue
                target=door['target_room']
                paired=next(d for d in rooms[target]['doors'] if d['id']==door['target_door_id'])
                for axis in (0,1):
                    self.assertAlmostEqual(layouts[key]['origin'][axis]+door['position_candidate']['local_world_units'][axis],layouts[target]['origin'][axis]+paired['position_candidate']['local_world_units'][axis])

    def test_navigation_rejects_crowded_exits_and_conflicting_loops(self):
        _,bundle=build();rooms=bundle['rooms']
        crowded=copy.deepcopy(rooms)
        door=copy.deepcopy(crowded['P-R01']['doors'][0]);door['id']='fixture_crowded'
        crowded['P-R01']['doors'].append(door)
        with self.assertRaisesRegex(ValueError,'Crowded'): navigation_geometry(crowded,'P-R03')
        conflicting=copy.deepcopy(rooms)
        for source,target,identity,pair,direction,point in [('P-R03','P-R06','fixture_a','fixture_b','up',[1408,0]),('P-R06','P-R03','fixture_b','fixture_a','right',[1520,100])]:
            conflicting[source]['doors'].append({'id':identity,'target_room':target,'target_door_id':pair,'direction':direction,'position_candidate':{'local_world_units':point}})
        with self.assertRaisesRegex(ValueError,'conflict'): navigation_geometry(conflicting,'P-R03')

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

    def test_invalid_content_refuses_runtime_bundle(self):
        data=json.loads((ROOT/'config/world/demo_services.json').read_text())
        npcs=[{'id':data['quest']['npc_id']}]
        validate_services(data,{'P-R06'},npcs)
        for change in ('negative_price','duplicate_item','bad_npc','unknown_effect','bad_pickup'):
            with self.subTest(change=change):
                invalid=copy.deepcopy(data)
                if change=='negative_price': invalid['items'][0]['price']=-1
                if change=='duplicate_item': invalid['items'].append(invalid['items'][0])
                if change=='bad_npc': invalid['quest']['npc_id']='missing'
                if change=='unknown_effect': invalid['items'][0]['effect']='unimplemented'
                if change=='bad_pickup': invalid['pickups'][0]['room_id']='not_implemented'
                with self.assertRaises(ValueError): validate_services(invalid,{'P-R06'},npcs)

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
