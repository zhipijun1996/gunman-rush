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

    def test_navigation_survey_preserves_physical_size_and_paired_interfaces(self):
        _, bundle=build(); rooms=bundle['rooms']
        layouts=navigation_geometry(rooms,bundle['start']['room'])
        opposites={'up':'down','down':'up','left':'right','right':'left'}
        for key,room in rooms.items():
            layout=layouts[key]
            self.assertEqual(layout['projection'],'survey_with_explicit_connections')
            self.assertEqual(layout['origin'],room['world_geometry']['map_origin'])
            self.assertEqual([layout['polygon'][2][i]-layout['polygon'][0][i] for i in (0,1)],room['world_geometry']['bounds_world_units'][2:])
            for door in room['doors']:
                if not door['target_implemented']:continue
                target=rooms[door['target_room']]
                paired=next(d for d in target['doors'] if d['id']==door['target_door_id'])
                self.assertEqual(paired['target_room'],key)
                self.assertEqual(paired['target_door_id'],door['id'])
                self.assertEqual(paired['direction'],opposites[door['direction']])

    def test_navigation_rejects_crowded_exits_and_overlapping_envelopes(self):
        _,bundle=build();rooms=bundle['rooms']
        crowded=copy.deepcopy(rooms)
        door=copy.deepcopy(crowded['P-R01']['doors'][0]);door['id']='fixture_crowded'
        crowded['P-R01']['doors'].append(door)
        with self.assertRaisesRegex(ValueError,'Crowded'):navigation_geometry(crowded,'P-R03')
        overlap=copy.deepcopy(rooms)
        overlap['P-R01']['world_geometry']['map_origin']=overlap['P-R03']['world_geometry']['map_origin']
        with self.assertRaisesRegex(ValueError,'overlap'):navigation_geometry(overlap,'P-R03')
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
            self.assertEqual(set(bundle['rooms']),{f'P-R{i:02}' for i in range(1,36)})
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
