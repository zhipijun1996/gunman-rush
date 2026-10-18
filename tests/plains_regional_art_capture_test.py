"""Synthetic negative admission checks; never art or live-game evidence."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1] / 'tools'))
import visual_director as vd


class RegionalEvidenceCounterexamples(unittest.TestCase):
    def setUp(self):
        self.data = {'manifest_hash':'actual-fixture-hash','manifest':{'sample':False,'areas':[
            {'id':'a','role':'junction','position':[0,0]},
            {'id':'b','role':'prep','position':[200,100]},
            {'id':'boss','role':'boss','position':[500,100]}]},
            'route_reached':True,'regional_cases':[{'id':'case','passed':True}],
            'regional_coverage':{'expected_area_ids':['a','b'],'missing_area_ids':[],
                                 'actual_grounded_visits':{'a':{'position':[0,0],'grounded':True},'b':{'position':[200,100],'grounded':True}}}}
        observed = {'ready':True,'production_pool':False,'manifest_hash':'actual-fixture-hash',
                    'art_plan':{'layout_source':'formal_full_region','plan_hash':'plan-fixture'},
                    'art':{'terrain':[{'id':'actual-fixture'}],'omitted':[],'plan_hash':'plan-fixture'},
                    'actual_boss':True,'actual_chests':2}
        self.data['regional_art_initial'] = copy.deepcopy(observed)
        self.data['regional_art_final'] = copy.deepcopy(observed)

    def test_denominator_and_grounded_visits_are_not_optional(self):
        self.assertEqual(vd.validate_regional_observations(self.data),[])
        for fault in ('denominator','missing_visit','wrong_position','airborne','nan','cases'):
            data = copy.deepcopy(self.data)
            if fault=='denominator': data['regional_coverage']['expected_area_ids']=['a']
            elif fault=='missing_visit': del data['regional_coverage']['actual_grounded_visits']['b']
            elif fault=='wrong_position': data['regional_coverage']['actual_grounded_visits']['b']['position'][0]+=20
            elif fault=='airborne': data['regional_coverage']['actual_grounded_visits']['b']['grounded']=False
            elif fault=='nan': data['regional_coverage']['actual_grounded_visits']['b']['position'][0]=float('nan')
            elif fault=='cases': data['regional_cases'][0]['passed']=False
            with self.subTest(fault=fault): self.assertTrue(vd.validate_regional_observations(data))

    def test_real_consumer_and_omissions_must_be_preserved(self):
        for fault in ('omitted','not_ready','formal_pool','hash','boss','cache','sample','terrain'):
            data = copy.deepcopy(self.data)
            final = data['regional_art_final']
            if fault=='omitted': final['art']['omitted']=[{'reason':'failed_actual_source'}]
            elif fault=='not_ready': final['ready']=False
            elif fault=='formal_pool': final['production_pool']=True
            elif fault=='hash': final['art']['plan_hash']='unrelated'
            elif fault=='boss': final['actual_boss']=False
            elif fault=='cache': final['actual_chests']=0
            elif fault=='sample': data['manifest']['sample']=True
            elif fault=='terrain': final['art']['terrain']=[]
            with self.subTest(fault=fault): self.assertTrue(vd.validate_regional_observations(data))


if __name__ == '__main__':
    unittest.main()
