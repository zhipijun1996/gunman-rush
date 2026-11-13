"""Cross-owner editor imports use the real world compiler, without mutating source."""
import copy,json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/world'))
from editor_apply import merge,MISSING,prepare

class EditorProtocol(unittest.TestCase):
    def test_three_way_preserves_disjoint_changes_and_rejects_competing_or_deleted_instances(self):
        base={'a':1,'b':2,'entities':{'id':{'x':0}}};draft=copy.deepcopy(base);current=copy.deepcopy(base)
        draft['a']=3;current['b']=4
        self.assertEqual(merge(base,draft,current,''),{'a':3,'b':4,'entities':{'id':{'x':0}}})
        current['a']=5
        with self.assertRaisesRegex(ValueError,'Concurrent design conflict'):merge(base,draft,current,'')
        with self.assertRaisesRegex(ValueError,'Concurrent design conflict'):merge(base['entities']['id'],{'x':2},MISSING,'/id')
    def test_real_world_scoped_rename_only_changes_world_owner(self):
        path=ROOT/'build/editor/project.json'
        if not path.exists():self.fail('Run world build, export_editor_documents.gd and export_editor_project.py first')
        base=json.loads(path.read_text());project=copy.deepcopy(base);project['rooms']['P-R13']['name']='导入验证';project['revision']+=1
        package={'schema':3,'source':base['source'],'base':base,'project':project,'selected_rooms':['P-R13']}
        before=(ROOT/'config/world/world.json').read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            receipt=prepare(ROOT,package,Path(folder)/'candidate')
            self.assertEqual([c['path'] for c in receipt['changes']],['config/world/collections.json','config/world/world.json'])
            self.assertFalse(receipt['actual_controller_playtest'])
        self.assertEqual(before,(ROOT/'config/world/world.json').read_bytes())
    def test_new_room_and_stable_paired_ports_compile_without_inheriting_another_rooms_story(self):
        base=json.loads((ROOT/'build/editor/project.json').read_text());p=copy.deepcopy(base)
        rid,cid,ap,bp='P-RTEST99','editor-test-link','editor-test-a','editor-test-b';parent=p['rooms']['P-R04'];w,h=parent['bounds'][2:]
        origin=[parent['origin'][0]+w,parent['origin'][1]+h/2-360]
        p['rooms'][rid]={'id':rid,'region':'P','name':'测试','purpose':'连通灰盒','origin':origin,'layer':'world','bounds':[0,0,1280,720],'spaces':[[0,0,1280,720]],'sections':{'main':{'id':'main','name':'主体','kind':'main','known':True}},'routes':{},'ports':{bp:{'id':bp,'connection':cid,'target_room':'P-R04','target_port':ap,'position':[0,360],'direction':'left','section':'main'}},'entities':{},'root':{'definition_id':'room.standard','definition_version':1,'component':'FixedWorldRoom','properties':{}},'camera':{'profile':'bounded_follow','transition':'occluded','zones':[],'links':[]},'implemented':False}
        parent['ports'][ap]={'id':ap,'connection':cid,'target_room':rid,'target_port':bp,'position':[w,h/2],'direction':'right','section':'main'}
        p['connections'][cid]={'id':cid,'a':{'room':'P-R04','port':ap},'b':{'room':rid,'port':bp},'requires':[[]],'direction':'both'};p['revision']+=1
        with tempfile.TemporaryDirectory() as folder:
            receipt=prepare(ROOT,{'schema':3,'source':base['source'],'base':base,'project':p,'selected_rooms':[rid]},Path(folder)/'candidate')
            stage=Path(receipt['candidate']);world=json.loads((stage/'config/world/world.json').read_text());row=next(r for r in world['rooms'] if r['id']==rid)
            self.assertEqual(row['npc_ids'],[]);self.assertNotIn('sanctuary_contract',row)
            self.assertEqual(set(receipt['rooms']),{rid,'P-R04'})
            construction=json.loads((stage/'config/world/construction.json').read_text());added=next(r for r in construction['rooms'] if r['room_id']==rid)
            self.assertFalse(added['implemented']);self.assertTrue(added['doors'][0]['landing_contract']['needs_support_validation'])
class EditorPlanningSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from export_editor_project import export
        from preview_catalog import preview_catalog
        cls.project=export(ROOT)
        cls.world=json.loads((ROOT/'config/world/world.json').read_text())
        cls.construction={r['room_id']:r for r in json.loads((ROOT/'config/world/construction.json').read_text())['rooms']}
        cls.maps={r['id']:r for r in preview_catalog(ROOT)['map_rooms']}

    def test_unplaced_rooms_do_not_acquire_invented_world_positions(self):
        unplaced=[r for rid,r in self.project['rooms'].items() if rid not in self.maps and 'world_origin' not in self.construction[rid]]
        self.assertEqual(len(unplaced),265)
        for room in unplaced:
            self.assertEqual(room['origin'],[0,0])
            self.assertEqual(room['spatial_source']['kind'],'unplaced')
            self.assertEqual(room['layout_status'],'planned')

    def test_actual_room_origins_and_collision_shapes_are_preserved(self):
        for rid,source in self.maps.items():
            self.assertEqual(self.project['rooms'][rid]['origin'],source['origin'])
            self.assertEqual(self.project['rooms'][rid]['spaces'],self.construction[rid]['space_rects'])

    def test_forest_blueprint_retains_source_frame_without_installing_runtime_geometry(self):
        blueprint=self.project['planning']['blueprints']['F']
        self.assertEqual(blueprint['source'],'game/world/regions/F/room_design.json')
        plan=blueprint['design']
        self.assertEqual(plan['status'],'proposal_for_review')
        self.assertEqual(plan['units'],'world_units')
        self.assertEqual(len(plan['rooms']),24)
        self.assertEqual(plan['anchor']['world_point'],[0,-576])
        f02=next(r for r in plan['rooms'] if r['room_id']=='F-R02')
        self.assertNotEqual(self.project['rooms']['F-R02']['bounds'],f02['bounds'])
        for source in self.world['rooms']:
            self.assertEqual(self.project['planning']['rooms'][source['id']]['position'],source.get('map_centre'))

if __name__=='__main__':unittest.main()
