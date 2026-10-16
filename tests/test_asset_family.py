"""Calibration counterexamples for production failures, not aesthetic acceptance."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from PIL import Image

MODULE=Path(__file__).resolve().parents[1]/'tools/asset_family.py'
loader=importlib.util.spec_from_file_location('asset_family',MODULE)
family=importlib.util.module_from_spec(loader)
loader.loader.exec_module(family)


class AssetFamilyCalibrationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        self.spec={'schema_version':1,'artifact_kind':'frozen_asset_family_spec','family_id':'test_cliff','grid':[1,1],
                   'interface_strip_px':4,'interface_min_coverage':.98,
                   'cells':[{'id':'fill','continuous_material':['left','right','top','bottom'],'min_opaque_fraction':.995}]}

    def tearDown(self): self.temp.cleanup()

    def run_image(self,image,spec=None):
        source=self.root/'source.png';image.save(source)
        contract=self.root/'spec.json';contract.write_text(json.dumps(spec or self.spec))
        before=source.read_bytes()
        result=family.calibrate(source,contract,self.root/'out')
        self.assertEqual(before,source.read_bytes(),'original carrier must remain unchanged')
        return result

    def test_exact_pixel_extraction_preserves_known_good_interface(self):
        image=Image.new('RGBA',(32,32),(173,157,118,254))
        result=self.run_image(image)
        self.assertEqual('passed',result['numeric_status'])
        extracted=Image.open(result['cells'][0]['extracted']['path'])
        self.assertEqual(image.tobytes(),extracted.tobytes())
        self.assertEqual('unverified',result['artistic_acceptance'])

    def test_isolated_exhibit_gutter_is_not_a_connected_tile(self):
        image=Image.new('RGBA',(32,32),(99,71,53,0))
        image.paste((173,157,118,254),(4,4,28,28))
        result=self.run_image(image)
        self.assertIn('fill:disconnected_material_interface_left',result['issues'])
        self.assertIn('fill:insufficient_opaque_fill',result['issues'])

    def test_alpha_one_hidden_rgb_is_measured_without_inventing_gpu_halo(self):
        image=Image.new('RGBA',(32,32),(120,100,50,1))
        result=self.run_image(image)
        self.assertEqual([0,0,32,32],result['cells'][0]['alpha_bounds']['1'])
        self.assertIsNone(result['cells'][0]['alpha_bounds']['128'])
        self.assertNotIn('halo',' '.join(result['issues']))

    def test_uneven_carrier_is_not_silently_resized(self):
        self.spec['grid']=[2,1]
        self.spec['cells']*=2
        self.spec['cells'][1]=dict(self.spec['cells'][0],id='fill2')
        result=self.run_image(Image.new('RGBA',(33,32),(100,100,100,254)))
        self.assertEqual(['carrier_not_exactly_divisible_by_frozen_grid'],result['issues'])
        self.assertEqual([],result['cells'])

    def test_small_plant_enlargement_and_cropped_root_are_rejected(self):
        spec=dict(self.spec,subject_min_padding_px=3,cells=[{'id':'tree','complete_rooted_subject':True,'world_height':200,'max_uniform_scale':1}])
        image=Image.new('RGBA',(32,32),(0,0,0,0));image.paste((90,120,60,254),(10,22,20,32))
        result=self.run_image(image,spec)
        self.assertIn('tree:subject_touches_cell_boundary',result['issues'])
        self.assertIn('tree:would_enlarge_small_subject_beyond_frozen_limit',result['issues'])


class ContinuousSourceTests(unittest.TestCase):
    """Synthetic contract fixtures, never evidence of painted/GPU quality."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
        self.source=self.root/'source.png'; Image.new('RGBA',(32,32),(173,157,118,254)).save(self.source)
        self.spec=self.root/'spec.json'; self.sampling=self.root/'sampling.json'
        self.contract={'family_id':'fixture','normalized_solid_core':[.125,.125,.875,.875],
                       'core_alpha_min':128,'core_coverage_min':.995}
        self.use={'uniform_scale':.25,'edge_source_band_px':4}

    def tearDown(self): self.temp.cleanup()

    def run_case(self):
        self.spec.write_text(json.dumps(self.contract)); self.sampling.write_text(json.dumps(self.use))
        before=(self.source.read_bytes(),self.spec.read_bytes(),self.sampling.read_bytes())
        result=family.calibrate_continuous(self.source,self.spec,self.root/'out',self.sampling)
        self.assertEqual(before,(self.source.read_bytes(),self.spec.read_bytes(),self.sampling.read_bytes()))
        return result

    def test_opaque_core_numeric_pass_does_not_approve_game_art(self):
        result=self.run_case()
        self.assertEqual('passed',result['numeric_status'])
        self.assertEqual([4,4,28,28],result['frozen_core']['measured_source_xyxy'])
        self.assertEqual('unverified',result['artistic_acceptance'])
        self.assertEqual('unverified',result['full_family_acceptance'])
        self.assertEqual(4,len(result['declared_sampling_use']['interfaces']))

    def test_interior_hole_remains_failed_even_when_perimeter_is_opaque(self):
        with Image.open(self.source) as image:
            image.putpixel((16,16),(120,80,40,0)); image.save(self.source)
        self.contract['core_coverage_min']=1
        result=self.run_case()
        self.assertEqual('failed',result['numeric_status'])
        self.assertEqual(1,result['declared_sampling_use']['interfaces']['left']['inward_interface_4px_alpha_128_coverage'])
        self.assertEqual('failed',result['frozen_core']['status'])

    def test_out_of_range_reversed_empty_and_nonfinite_core_are_refused(self):
        for core in [[-.1,0,1,1],[0,0,1.1,1],[.8,0,.2,1],[0,.2,1,.2],[0,0,float('nan'),1]]:
            self.contract['normalized_solid_core']=core
            with self.subTest(core=core), self.assertRaises(ValueError): self.run_case()

    def test_nonuniform_excessive_and_nonfinite_scale_are_refused(self):
        for scale in [[.25,.3],.5,0,float('nan'),True]:
            self.use['uniform_scale']=scale
            with self.subTest(scale=scale), self.assertRaises(ValueError): self.run_case()

    def test_wrong_source_hash_and_out_of_range_band_are_refused(self):
        self.contract['source_sha256']='0'*64
        with self.assertRaises(ValueError): self.run_case()
        self.contract.pop('source_sha256');self.use['edge_source_band_px']=17
        with self.assertRaises(ValueError): self.run_case()

    def test_existing_failed_evidence_is_not_overwritten(self):
        self.run_case(); report=self.root/'out/calibration.json'; before=report.read_bytes()
        with self.assertRaises(ValueError): self.run_case()
        self.assertEqual(before,report.read_bytes())


if __name__=='__main__':unittest.main()
