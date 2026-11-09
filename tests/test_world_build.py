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

    def test_navigation_is_one_physical_region_with_closed_door_seams(self):
        contracts, bundle=build(); rooms={r['room_id']:r for r in contracts['rooms'] if r['room_id'].startswith('P-')}
        layouts=navigation_geometry(rooms,bundle['start']['room'])
        opposites={'up':'down','down':'up','left':'right','right':'left'}
        pairs=set()
        self.assertTrue(any(len(v['polygon'])>4 for v in layouts.values()))
        for key,room in rooms.items():
            layout=layouts[key]
            self.assertNotIn('projection',layout)
            self.assertNotIn('map_origin',room['world_geometry'])
            for door in room['doors']:
                if door['target_room'] not in rooms:continue
                target=rooms[door['target_room']]
                paired=next(d for d in target['doors'] if d['id']==door['target_door_id'])
                self.assertEqual(paired['target_room'],key)
                self.assertEqual(paired['target_door_id'],door['id'])
                self.assertEqual(paired['direction'],opposites[door['direction']])
                self.assertEqual([layout['origin'][i]+door['position_candidate']['local_world_units'][i] for i in (0,1)],
                                 [layouts[door['target_room']]['origin'][i]+paired['position_candidate']['local_world_units'][i] for i in (0,1)])
                pairs.add(tuple(sorted([door['id'],paired['id']])))
        self.assertEqual(len(rooms),35)
        self.assertEqual(len(pairs),43)

    def test_navigation_rejects_crowding_open_loops_and_old_projection(self):
        contracts,bundle=build();rooms={r['room_id']:r for r in contracts['rooms'] if r['room_id'].startswith('P-')}
        crowded=copy.deepcopy(rooms)
        door=copy.deepcopy(crowded['P-R01']['doors'][0]);door['id']='fixture_crowded'
        crowded['P-R01']['doors'].append(door)
        with self.assertRaisesRegex(ValueError,'Crowded'):navigation_geometry(crowded,'P-R03')
        displaced=copy.deepcopy(rooms)
        door=next(d for d in displaced['P-R01']['doors'] if d['target_room']=='P-R08')
        door['position_candidate']['local_world_units'][1]+=32
        with self.assertRaisesRegex(ValueError,'seam'):navigation_geometry(displaced,'P-R03')
        obsolete=copy.deepcopy(rooms)
        obsolete['P-R01']['world_geometry']['map_origin']=[0,0]
        with self.assertRaisesRegex(ValueError,'map_origin'):navigation_geometry(obsolete,'P-R03')
        disconnected=copy.deepcopy(rooms)
        for row in disconnected.values():row['doors']=[d for d in row['doors'] if d['target_room']!='P-R21']
        with self.assertRaisesRegex(ValueError,'connected'):navigation_geometry(disconnected,'P-R03')

    def test_build_without_imported_archive_preserves_authored_scenes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            shutil.copytree(ROOT/'config/world',root/'config/world')
            shutil.copytree(ROOT/'game/world/regions',root/'game/world/regions')
            before={str(p.relative_to(root)):p.read_bytes() for p in (root/'game').rglob('*.tscn')}
            contracts,bundle=build(root)
            self.assertEqual(len(contracts['rooms']),309)
            actions={a['action_ref']:a for r in contracts['rooms'] for a in r['interactions']}
            self.assertEqual(actions['tutorial_move']['trigger'],'accepted_player_action')
            self.assertEqual(actions['defeat_P_WINDKEEPER']['trigger'],'actual_boss_victory')
            self.assertFalse(actions['station_briefing']['arriving_does_not_grant'])
            self.assertEqual(set(bundle['rooms']),{f'P-R{i:02}' for i in (1,3,21,22,23,24)})
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
