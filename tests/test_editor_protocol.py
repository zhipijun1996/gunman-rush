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
        package={'schema':2,'source':base['source'],'base':base,'project':project,'selected_rooms':['P-R13']}
        before=(ROOT/'config/world/world.json').read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            receipt=prepare(ROOT,package,Path(folder)/'candidate')
            self.assertEqual([c['path'] for c in receipt['changes']],['config/world/world.json'])
            self.assertFalse(receipt['actual_controller_playtest'])
        self.assertEqual(before,(ROOT/'config/world/world.json').read_bytes())
if __name__=='__main__':unittest.main()
