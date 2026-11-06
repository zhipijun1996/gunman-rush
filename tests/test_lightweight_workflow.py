"""User-facing workflow boundaries: ordinary work, opt-in review, current design."""
from contextlib import redirect_stdout
import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import quality
import production_loop as loop
import level_design
import region_creative_direction as creative


class LightweightWorkflowTests(unittest.TestCase):
    def test_current_card_scan_ignores_archived_broken_json_and_reads_active_card(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archived = root/'docs/evidence/quality/records/old.json'
            archived.parent.mkdir(parents=True)
            archived.write_text('{ invalid historical fixture')
            active = root/'docs/project/worklines/current/quality/record.json'
            active.parent.mkdir(parents=True)
            active.write_text(json.dumps(quality.initialize('CURRENT', 'enemy', 'a'*40)))
            policy = root/'docs/project/policy.json'
            policy.write_bytes((ROOT/'docs/project/policy.json').read_bytes())
            self.assertEqual(list(quality.task_record_paths(root)), [active])
            self.assertEqual(set(quality.task_record_paths(root, include_archive=True)), {active, archived})
            with patch.object(quality, 'ROOT', root), patch.object(sys, 'argv', ['quality.py','check']), redirect_stdout(io.StringIO()):
                self.assertEqual(quality.main(), 0)
                phase=active.with_name('phase.json')
                phase.write_text(active.read_text())
                self.assertEqual(set(quality.task_record_paths(root)), {active,phase})
                phase.unlink()
                data=json.loads(active.read_text())
                data['dimensions']['visual']['status']='invented'
                active.write_text(json.dumps(data))
                self.assertEqual(quality.main(), 1)

    def test_new_content_card_has_no_workflow_graybox_or_inapplicable_placeholders(self):
        card = quality.initialize('NEW-ENEMY', 'enemy', 'a'*40)
        self.assertNotIn('workflow', card)
        self.assertNotIn('G1', card['gates'])
        self.assertEqual(set(card['dimensions']), {'visual','gameplay'})
        self.assertNotIn('device', card['dimensions'])
        card['gates']['G1']={'status':'unverified','reason':'retired','evidence':[]}
        self.assertTrue(quality.validate_record(card)['errors'])

    def test_default_execution_does_not_allocate_an_extra_reviewer(self):
        task={'id':'READ','goal':'SIMULATED ordinary inspection','skills':['gameplay-reviewer'],
              'checks':['docs'],'read_only':True}
        mission={'schema_version':1,'objective':'one actual fake-worker call','max_calls':1,
                 'max_rounds':1,'call_timeout_seconds':10,'tasks':[task]}
        roles=[]
        def worker(task, mission, role, folder, feedback):
            roles.append(role)
            return {'status':'ready_for_review','summary':'SIMULATED observation','findings':[]}
        with tempfile.TemporaryDirectory() as folder, patch.object(loop,'snapshot',return_value={}), patch.object(loop,'required_input_preflight',return_value={'status':'passed'}), patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
            result=loop.run(mission,Path(folder),worker)
        self.assertEqual(result['status'],'complete')
        self.assertEqual(result['calls'],1)
        self.assertEqual(roles,['implement'])
        self.assertTrue(loop.needs_independent_review({**task,'independent_review':True}))

    def test_ordinary_rule_fix_can_execute_without_a_content_card(self):
        task={'id':'FIX','goal':'SIMULATED existing rule fix','skills':['project-integration'],
              'checks':['docs'],'read_only':False,'allowed_paths':['tools/fix.py'],'max_calls':1}
        mission={'schema_version':1,'objective':'ordinary scoped delivery','max_calls':1,
                 'max_rounds':1,'call_timeout_seconds':10,'tasks':[task]}
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            skill=root/'.agents/skills/project-integration/SKILL.md'
            skill.parent.mkdir(parents=True)
            skill.write_text('SIMULATED skill fixture')
            target=root/'tools/fix.py'
            def worker(*args):
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_text('VALUE = 2\n')
                return {'status':'ready_for_review','summary':'SIMULATED fix','findings':[]}
            def snapshot():
                return {'tools/fix.py':loop.hashlib.sha256(target.read_bytes()).hexdigest()} if target.exists() else {}
            with patch.object(loop,'ROOT',root), patch.object(loop,'snapshot',side_effect=snapshot), patch.object(loop,'required_input_preflight',return_value={'status':'passed'}), patch.object(loop.harness,'run_check',return_value={'status':'passed'}):
                result=loop.run(mission,root/'evidence',worker)
            self.assertEqual(target.read_text(),'VALUE = 2\n')
            self.assertEqual(result['status'],'complete')
            self.assertFalse(result['content_complete'])
            self.assertEqual(result['calls'],1)

    def test_authored_canonical_bible_does_not_require_an_uploaded_attachment(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            def put(name, data):
                path=root/name
                path.parent.mkdir(parents=True,exist_ok=True)
                path.write_text(data if isinstance(data,str) else json.dumps(data))
                return path
            bible=put('docs/bible/regions/test_region.md','# Test Region\nConfirmed current design\n')
            evidence=put('docs/evidence/user-selection.json',{'source':'SIMULATED user chat','quote':'Use the reviewed design','authorization_scope':'fixture only'})
            put('docs/bible/world_regions.json',{'regions':[{'id':'test_region','working_name':'Test Region'}]})
            put(creative.BIBLE_REGISTRY,{'schema_version':1,'kind':'region_bible_registry_direction_only','regions':[{'region_id':'test_region','current_bible':{
                'path':'docs/bible/regions/test_region.md','sha256':loop.hashlib.sha256(bible.read_bytes()).hexdigest(),
                'bible_id':'test_region_v1','version':'1.0','status':'user_selected_direction_only','direction_path':'direction.json',
                'music_status':'deferred_user_supplied','operations':['create','optimize'],
                'selection_evidence':{'path':'docs/evidence/user-selection.json','sha256':loop.hashlib.sha256(evidence.read_bytes()).hexdigest()}}}]})
            with patch.object(creative,'_supplemental_authority',return_value=None):
                _,binding=creative.bind_region_bible('test_region',root)
            self.assertEqual(binding['path'],'docs/bible/regions/test_region.md')

    def test_forest_creator_reads_canonical_and_only_relevant_object_specs(self):
        from mission_fixtures import selected_mission
        mission=selected_mission(skills=['enemy-creator'])
        self.assertTrue(all('G1' not in task.get('required_gates',[]) for task in mission['tasks']))
        self.assertFalse(any(task.get('requires_visual_admission') for task in mission['tasks']))
        task=mission['tasks'][0]
        bible=loop.region_bible_input(task)
        self.assertEqual(bible['binding']['path'],'docs/bible/regions/thorn_forest.md')
        names={document['path'] for document in bible['object_documents']}
        self.assertIn('docs/data/enemies/forest.md',names)
        self.assertFalse(any('/bosses/' in name for name in names))
        with tempfile.TemporaryDirectory() as folder:
            prompt,*_=loop.prepare_call(task,mission,'implement',Path(folder),'{}',check_contracts={'checks':[]})
        self.assertIn((ROOT/'docs/bible/regions/thorn_forest.md').read_text(),prompt)
        self.assertIn((ROOT/'docs/data/enemies/forest.md').read_text(),prompt)
        original=(ROOT/'docs/evidence/creative_direction/bibles/2-thorn_forest_region_bible_v2.md').read_text()
        self.assertNotIn(original,prompt)
        self.assertIn('docs/data/enemies/forest.md',{row['path'] for row in loop.bound_source_inputs(task)})


if __name__ == '__main__':
    unittest.main()
