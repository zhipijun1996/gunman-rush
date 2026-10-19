"""Reader/negative fixtures only: these do not claim a successful motor traversal."""
import copy
import importlib.util
import pathlib
import sys
import unittest
from unittest import mock

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import run_forest_depth_region as reader


class InterwovenAuthorityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.authority=reader._interwoven_authority()

    def fixture(self,phrase):
        a=copy.deepcopy(self.authority);spec=a['specs'][phrase];raw=a['factories'][phrase]
        instance={'id':spec['instance'],'factory':reader.INTERWOVEN_FACTORY,'geometry_version':a['version'],
                  'local_geometry':raw,'translation':[0.0,0.0],
                  'platform_id_map':spec['platform_id_map'],'anchor_id_map':spec['anchor_id_map'],'danger_indices':[]}
        leg={k:spec[k] for k in ('id','a','b')}
        if 'first_hook_delay' in spec:leg['first_hook_delay']=spec['first_hook_delay']
        leg.update(geometry_instance=spec['instance'],action_program=copy.deepcopy(raw['action_program']),
                   kind='hanging_chain' if phrase=='inner_HR' else 'airborne_chain')
        if phrase=='inner_HR':leg.update(rest_anchor_id=spec['anchor_id_map']['a'],hang_observation_frames=18)
        manifest={'layout_version':a['version'],'platforms':[dict(id=id,**row)for id,row in a['platforms'].items()],
                  'hook_anchors':[dict(id=id,**row)for id,row in a['anchors'].items()], 'dangers':a['ambient_dangers']}
        manifest['areas']=[{'id':'interwoven_root_landing','position':[400,802]}]
        manifest['merchant_position']=[360,802]
        manifest['connections']=[{'id':'interwoven_root_to_D','a':'interwoven_root_landing','b':'D','kind':'walk','path':[[400.0,802.0],[720.0,802.0]]},
                                 {'id':'interwoven_root_to_camp','a':'interwoven_root_landing','b':'camp','kind':'walk','path':[[400.0,802.0],[360.0,802.0]]}]
        return manifest,leg,instance

    def check(self,fixture):return reader._validate_interwoven_binding(*fixture,self.authority)

    def test_actual_five_source_phrases(self):
        expected={'lesson_H':['H'],'inner_HH':['H','H'],'upper_RH':['R','H'],'crown_H':['H'],'inner_HR':['R','HANG','R'],'deep_descent_RH':['R','H'],'deep_ascent_HRHHR':['H','R','H','H','R']}
        self.assertEqual(set(self.authority['factories']),set(expected))
        for phrase,program in expected.items():
            with self.subTest(phrase=phrase):
                self.assertEqual([p['action']for p in self.authority['factories'][phrase]['action_program']],program)
                self.assertEqual(self.check(self.fixture(phrase)),[])

    def test_only_actual_two_source_edges_have_five_tick_delay(self):
        for phrase,spec in self.authority['specs'].items():
            with self.subTest(phrase=phrase):
                if phrase in ('lesson_H','crown_H'):self.assertEqual(spec['first_hook_delay'],5)
                else:self.assertNotIn('first_hook_delay',spec)

    def test_explicit_delay_cannot_be_missing(self):
        for phrase in ('lesson_H','crown_H'):
            with self.subTest(phrase=phrase):
                f=self.fixture(phrase);del f[1]['first_hook_delay']
                self.assertIn('interwoven_first_hook_delay',self.check(f))

    def test_explicit_delay_tamper_refused(self):
        for value in (0,1,4,6,True,5.0,'5'):
            with self.subTest(value=value):
                f=self.fixture('lesson_H');f[1]['first_hook_delay']=value
                self.assertIn('interwoven_first_hook_delay',self.check(f))

    def test_default_delay_must_match_absent_source_key(self):
        for phrase in ('inner_HH','upper_RH','inner_HR'):
            with self.subTest(phrase=phrase):
                f=self.fixture(phrase);f[1]['first_hook_delay']=1
                self.assertIn('interwoven_first_hook_delay',self.check(f))

    def test_unknown_source_delay_refused(self):
        target=ROOT/'scripts/generation/forest_interwoven_expedition.gd';original=pathlib.Path.read_text
        for new in ('edge.first_hook_delay = 6','edge.first_hook_delay = int(5)','edge.first_hook_delay = 1','edge.delay = 5'):
            with self.subTest(new=new):
                def read(path,*args,**kwargs):
                    text=original(path,*args,**kwargs)
                    return text.replace('edge.first_hook_delay = 5',new,1)if path==target else text
                with mock.patch.object(pathlib.Path,'read_text',read):
                    with self.assertRaises(ValueError):reader._interwoven_authority()

    def test_deep_source_supports_and_bounds(self):
        self.assertEqual(self.authority['platforms']['interwoven_deep_basin'],{'rect':[95,1400,200,24],'one_way':False})
        self.assertEqual(self.authority['platforms']['hollow__inner_root'],{'rect':[290,820,500,40],'one_way':False})
        for phrase in ('deep_descent_RH','deep_ascent_HRHHR'):
            with self.subTest(phrase=phrase):
                factory=self.authority['factories'][phrase]
                self.assertNotEqual(factory['world_bounds'],self.authority['factories']['lesson_H']['world_bounds'])
                self.assertEqual(self.check(self.fixture(phrase)),[])

    def test_deep_coherent_support_tamper_refused(self):
        for phrase,target in [('deep_descent_RH','interwoven_deep_basin'),('deep_ascent_HRHHR','hollow__inner_root')]:
            with self.subTest(phrase=phrase):
                f=self.fixture(phrase)
                next(p for p in f[0]['platforms']if p['id']==target)['rect'][2]+=50
                f[2]['local_geometry']['platforms'][1]['rect'][2]+=50
                self.assertIn('interwoven_actual_platforms',self.check(f))
                self.assertIn('interwoven_current_source_geometry',self.check(f))

    def test_deep_bounds_tamper_refused(self):
        f=self.fixture('deep_ascent_HRHHR');f[2]['local_geometry']['world_bounds'][0]+=1
        self.assertIn('interwoven_current_source_geometry',self.check(f))

    def test_deep_action_cannot_be_removed_coherently(self):
        f=self.fixture('deep_ascent_HRHHR');f[2]['local_geometry']['action_program'].pop(2);f[1]['action_program'].pop(2)
        self.assertIn('interwoven_current_source_geometry',self.check(f))
        self.assertIn('interwoven_current_source_program',self.check(f))

    def test_deep_hook_cannot_be_moved_coherently(self):
        f=self.fixture('deep_ascent_HRHHR');f[2]['local_geometry']['hook_anchors'][0]['position'][0]+=30
        next(a for a in f[0]['hook_anchors']if a['id']=='interwoven_deep_a')['position'][0]+=30
        self.assertIn('interwoven_actual_hook_anchors',self.check(f))

    def test_deep_installer_must_be_called_and_data_only(self):
        target=ROOT/'scripts/generation/forest_interwoven_expedition.gd';original=pathlib.Path.read_text
        for old,new in [('_install_deep_root_golden(m)','_not_installed(m)'),('m.scene_structure_kinds["interwoven_deep_root"] = "root_hollow"','m.dangers = []'),('row.get("bounds",','row.get("unknown_bounds",')]:
            with self.subTest(new=new):
                def read(path,*args,**kwargs):
                    text=original(path,*args,**kwargs)
                    return text.replace(old,new,1)if path==target else text
                with mock.patch.object(pathlib.Path,'read_text',read):
                    with self.assertRaises((ValueError,IndexError)):reader._interwoven_authority()

    def test_hollow_offset_source_cannot_change_unreviewed(self):
        target=ROOT/'scripts/generation/thorn_forest_region_v2_v10.gd';original=pathlib.Path.read_text
        def read(path,*args,**kwargs):
            text=original(path,*args,**kwargs)
            return text.replace('var offset:=Vector2(600,600)','var offset:=Vector2(650,600)',1)if path==target else text
        with mock.patch.object(pathlib.Path,'read_text',read):
            with self.assertRaisesRegex(ValueError,'hollow region offset'):reader._interwoven_authority()

    def test_hollow_inherited_root_mutation_source_refused(self):
        target=ROOT/'scripts/generation/forest_hollow_trunk_geometry.gd';original=pathlib.Path.read_text
        def read(path,*args,**kwargs):
            text=original(path,*args,**kwargs)
            return text.replace('else:bodies.append(row)','elif row.id=="inner_root":row.rect[2] += 20; bodies.append(row)\n\t\telse:bodies.append(row)',1)if path==target else text
        with mock.patch.object(pathlib.Path,'read_text',read):
            with self.assertRaisesRegex(ValueError,'inner root derivation'):reader._interwoven_authority()

    def test_actual_root_landing_and_conditional_walks(self):
        self.assertEqual(self.authority['specs']['deep_ascent_HRHHR']['b'],'interwoven_root_landing')
        f=self.fixture('deep_ascent_HRHHR');self.assertEqual(self.check(f),[])
        f[0]['merchant_position']=[1160,1032];f[0]['connections'].pop()
        self.assertEqual(self.check(f),[])

    def test_root_node_tamper_refused(self):
        for mutate in ('missing','position','duplicate'):
            with self.subTest(mutate=mutate):
                f=self.fixture('deep_ascent_HRHHR')
                if mutate=='missing':f[0]['areas']=[]
                elif mutate=='position':f[0]['areas'][0]['position'][0]+=1
                else:f[0]['areas'].append(copy.deepcopy(f[0]['areas'][0]))
                self.assertIn('interwoven_root_landing_node',self.check(f))

    def test_root_walk_path_or_condition_tamper_refused(self):
        for mutate in ('wrong_path','wrong_target','missing_walk','extra_camp','missing_camp'):
            with self.subTest(mutate=mutate):
                f=self.fixture('deep_ascent_HRHHR')
                if mutate=='wrong_path':f[0]['connections'][0]['path'][1][0]+=1
                elif mutate=='wrong_target':f[0]['connections'][0]['b']='camp'
                elif mutate=='missing_walk':f[0]['connections'].pop(0)
                elif mutate=='extra_camp':f[0]['merchant_position']=[1160,1032]
                else:f[0]['connections'].pop()
                self.assertIn('interwoven_root_literal_walk',self.check(f))

    def test_unknown_deep_walk_source_refused(self):
        target=ROOT/'scripts/generation/forest_interwoven_expedition.gd';original=pathlib.Path.read_text
        changes=[('if API._point(m.merchant_position) == Vector2(360,802):','if API._point(m.merchant_position) == Vector2(350,802):'),
                 ('[[400.0,802.0],[720.0,802.0]]','[[400.0,802.0],[740.0,802.0]]'),
                 ('"interwoven_deep_ascent","interwoven_deep_basin","interwoven_root_landing"','"interwoven_deep_ascent","interwoven_deep_basin","D"')]
        for old,new in changes:
            with self.subTest(new=new):
                def read(path,*args,**kwargs):
                    text=original(path,*args,**kwargs)
                    return text.replace(old,new)if path==target else text
                with mock.patch.object(pathlib.Path,'read_text',read):
                    with self.assertRaises(ValueError):reader._interwoven_authority()

    def test_actual_inherited_support_and_hang_source(self):
        self.assertEqual(self.authority['platforms']['thorn_mouth__entry']['rect'],[-1800,1298,185,60])
        self.assertEqual(self.authority['platforms']['thorn_mouth__recovery']['rect'],[-2005,2000,1190,40])
        self.assertTrue(self.authority['anchors']['thorn_retry_exit_ring']['hang_enabled'])
        self.assertTrue(self.authority['ambient_dangers'])

    def test_unknown_factory(self):
        f=self.fixture('lesson_H');f[2]['factory']='res://self_reported.gd'
        self.assertIn('interwoven_factory_identity',self.check(f))

    def test_unknown_phrase(self):
        f=self.fixture('lesson_H');f[2]['local_geometry']['id']='invented'
        self.assertEqual(self.check(f),['interwoven_unknown_phrase'])

    def test_coherent_program_tamper(self):
        f=self.fixture('inner_HH');f[2]['local_geometry']['action_program'].reverse();f[1]['action_program'].reverse()
        self.assertIn('interwoven_current_source_geometry',self.check(f))
        self.assertIn('interwoven_current_source_program',self.check(f))

    def test_coherent_anchor_geometry_tamper(self):
        f=self.fixture('lesson_H');f[2]['local_geometry']['hook_anchors'][0]['position'][0]+=10
        next(a for a in f[0]['hook_anchors']if a['id']=='interwoven_lesson_ring')['position'][0]+=10
        self.assertIn('interwoven_actual_hook_anchors',self.check(f))
        self.assertIn('interwoven_current_source_geometry',self.check(f))

    def test_coherent_support_tamper(self):
        f=self.fixture('lesson_H');f[2]['local_geometry']['platforms'][1]['rect'][2]+=10
        next(p for p in f[0]['platforms']if p['id']=='interwoven_lesson_bough')['rect'][2]+=10
        self.assertIn('interwoven_actual_platforms',self.check(f))
        self.assertIn('interwoven_current_source_geometry',self.check(f))

    def test_support_one_way_tamper(self):
        f=self.fixture('lesson_H');next(p for p in f[0]['platforms']if p['id']=='interwoven_lesson_bough')['one_way']=False
        self.assertIn('interwoven_actual_platforms',self.check(f))

    def test_coherent_anchor_id_tamper(self):
        f=self.fixture('inner_HH');f[2]['anchor_id_map']['a']='interwoven_lesson_ring';f[2]['local_geometry']['anchor_bindings']['a']='interwoven_lesson_ring'
        self.assertIn('interwoven_anchor_binding',self.check(f))

    def test_support_id_tamper(self):
        f=self.fixture('lesson_H');f[2]['platform_id_map']['entry']='interwoven_root_bridge'
        self.assertIn('interwoven_support_binding',self.check(f))

    def test_translation_tamper(self):
        f=self.fixture('lesson_H');f[2]['translation']=[10,0]
        self.assertIn('interwoven_translation',self.check(f))

    def test_hang_ring_flag_tamper(self):
        f=self.fixture('inner_HR');next(a for a in f[0]['hook_anchors']if a['id']=='thorn_retry_exit_ring')['hang_enabled']=False
        self.assertIn('interwoven_actual_hook_anchors',self.check(f))

    def test_hang_identity_not_old_spiral(self):
        f=self.fixture('inner_HR');f[1]['id']='root_spiral_rest_flight';f[2]['id']='root_spiral'
        self.assertIn('interwoven_instance_identity',self.check(f))
        self.assertIn('interwoven_edge_identity',self.check(f))

    def test_hang_contract_tamper(self):
        for key,value in [('rest_anchor_id','root_spiral__rest_ring'),('hang_observation_frames',17),('kind','airborne_chain')]:
            with self.subTest(key=key):
                f=self.fixture('inner_HR');f[1][key]=value;self.assertTrue(self.check(f))

    def test_inherited_thorns_cannot_be_dropped(self):
        f=self.fixture('lesson_H');f[0]['dangers']=[]
        self.assertIn('interwoven_inherited_dangers',self.check(f))

    def test_duplicate_actual_support_rejected(self):
        f=self.fixture('lesson_H');f[0]['platforms'].append(copy.deepcopy(next(p for p in f[0]['platforms']if p['id']=='interwoven_lesson_bough')))
        self.assertIn('interwoven_actual_platforms',self.check(f))

    def test_not_admitted_as_old_v12(self):
        f=self.fixture('lesson_H');f[0]['layout_version']='forest-woven-trunk-v12'
        self.assertIn('interwoven_layout_identity',self.check(f))

    def test_unknown_source_statements_rejected(self):
        target=ROOT/'scripts/generation/forest_interwoven_expedition.gd';original=pathlib.Path.read_text
        for old,new in [('var rows: Dictionary = {','var rows: Dictionary = build_elsewhere({'),('raw.dangers = []','raw.dangers = []\n\traw.action_program = []'),('return {"id":phrase','return {"unknown":true,"id":phrase')]:
            with self.subTest(new=new):
                def read(path,*args,**kwargs):
                    text=original(path,*args,**kwargs)
                    return text.replace(old,new,1)if path==target else text
                with mock.patch.object(pathlib.Path,'read_text',read):
                    with self.assertRaises((ValueError,KeyError,IndexError)):
                        reader._interwoven_authority()

    def test_metadata_success_is_not_playability_success(self):
        manifest,leg,instance=self.fixture('lesson_H');manifest['geometry_instances']=[instance]
        # Complete source metadata with no real trajectory must fail the common
        # validator; this positive reader fixture cannot replace native evidence.
        errors=reader.validate_airborne_chain_leg({'manifest':manifest},leg,{'start_tick':0,'tick':10,'leg':0},[],[],[],{},lambda *args:False)
        self.assertIn('air_chain_actual_frames_missing',errors)

    def test_original_factories_and_corpus_preserved(self):
        for layout in ('thorn_mouth','hollow_spiral','bridge_five','arch_four','hook_hook','recoil_hook','recoil_hook_recoil'):
            with self.subTest(layout=layout):
                self.assertEqual(reader._air_chain_authoritative_factory(layout,regional=True)['id'],layout)
        self.assertEqual(len(reader.corpus_cases()),80)


if __name__=='__main__':unittest.main()
