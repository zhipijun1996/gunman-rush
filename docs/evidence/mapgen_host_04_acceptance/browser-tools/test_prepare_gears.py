"""Pure synthetic event tests. These are never native or Web evidence."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from prepare_gears import extract_expected

class NativeExtraction(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)/'synthetic.log'
        self.identity = dict(host_load_identity='a'*64, map_content_identity='b'*64,
                             host_load=dict(spawn=[7,9], selected_instances=['native-instance']))
        self.commit = dict(event='committed', source_kind='generated_memory', profile='native-profile',
                           identity=self.identity, output=dict(seed=930007, status='PASS', instances=43, connections=55, content_entries=43, request_fingerprint='c'*64))
        self.loaded = dict(event='loaded', host_load_identity='a'*64, player=[7,9],
                           mechanisms=[dict(instance_id='native-instance', ferries=[dict(id='first'),dict(id='second')], saws=[dict(id='saw')])],
                           static_contacts=[dict(rect=[1,2,3,4], enabled=True, shared_policy=True, fall_plane=True)])
    def write(self, commits=None, loaded=None, marker='RUNTIME_MAP_M35_RUNTIME checks=69 failures=0'):
        text = '\n'.join(['MAPGEN_RUNTIME '+json.dumps(v) for v in (commits if commits is not None else [self.commit])])+'\n'
        text += 'MAPGEN_HOST_V2 '+json.dumps(loaded if loaded is not None else self.loaded)+'\n'+marker+'\n'
        self.path.write_text(text)
    def test_actual_values_not_prior_fallback(self):
        self.write(); value=extract_expected(self.path,'d'*40)
        self.assertEqual(value['spawn'],[7,9]); self.assertEqual(value['selected_instances'],['native-instance'])
        self.assertEqual(value['mechanisms']['static_contact_rect'],[1,2,3,4])
        self.assertEqual(value['source'],'d'*40)
    def test_failure_marker_rejected(self):
        self.write(marker='RUNTIME_MAP_M35_RUNTIME checks=69 failures=1')
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_missing_marker_rejected(self):
        self.write(marker='')
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_wrong_seed_rejected(self):
        self.commit['output']['seed']=930001; self.write()
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_spawn_mismatch_rejected(self):
        self.loaded['player']=[0,0]; self.write()
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_ambiguous_identity_rejected(self):
        other=copy.deepcopy(self.commit); other['identity']['map_content_identity']='e'*64
        self.write(commits=[self.commit,other])
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_contact_policy_rejected(self):
        self.loaded['static_contacts'][0]['enabled']=False; self.write()
        with self.assertRaises(AssertionError): extract_expected(self.path,'d'*40)
    def test_malformed_json_rejected(self):
        self.path.write_text('MAPGEN_RUNTIME {\nRUNTIME_MAP_M35_RUNTIME checks=69 failures=0\n')
        with self.assertRaises(json.JSONDecodeError): extract_expected(self.path,'d'*40)

if __name__=='__main__': unittest.main()
