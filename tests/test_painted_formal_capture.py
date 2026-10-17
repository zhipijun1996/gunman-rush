"""Allowlist and evidence binding tests; no native or visual acceptance claim."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import visual_director as vd

class PaintedFormalCaptureTests(unittest.TestCase):
    def test_formal_catalog_cannot_request_spatial_geometry(self):
        report={'request':dict(source_commit='a'*40,root_seed='SYNTHETIC',map_index=1,strategy='growth',phase_wait_ticks=0,max_ticks=60,encounter_policy='kill_from_bank_v1',capture_script='tools/painted_formal_capture.gd',visual_sample=vd.VISUAL_SAMPLE_CATALOGS[1],visual_layout='')}
        command=vd.native_command(report,vd.ROOT/'build/synthetic_capture.json',vd.ROOT/'build/synthetic_capture.avi')
        self.assertIn('--visual-sample='+vd.VISUAL_SAMPLE_CATALOGS[1],command)
        self.assertFalse(any(arg.startswith('--visual-layout=') for arg in command))
        for sample,layout in [(vd.VISUAL_SAMPLE_CATALOG,''),(vd.VISUAL_SAMPLE_CATALOGS[1],'open-meadow'),('res://arbitrary.json','')]:
            with self.subTest(sample=sample,layout=layout):
                report['request'].update(visual_sample=sample,visual_layout=layout)
                with self.assertRaises(ValueError):vd.native_command(report,vd.ROOT/'build/synthetic_capture.json',vd.ROOT/'build/synthetic_capture.avi')

    def test_formal_extension_binds_actual_driver_without_golden_entry(self):
        closure=vd.capture_extension_sources('tools/painted_formal_capture.gd')
        self.assertIn('tools/painted_formal_capture.gd',closure)
        self.assertIn('tools/level_formal_capture.gd',closure)
        self.assertNotIn('tools/spatial_golden_preview.gd',closure)
        self.assertNotIn('tests/spatial_golden_trace.gd',closure)
