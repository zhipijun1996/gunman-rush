#!/usr/bin/env python3
"""Exercise the real pinned exporter: deterministic art, passes, pivots and body rejection."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/vfx/reproducibility'

def run(*args):
    return subprocess.run([sys.executable,'tools/vfx/pixelfx.py',*args],cwd=ROOT,text=True,capture_output=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class ExportContracts(unittest.TestCase):
    def test_rebuild_matches_shipped_pixels_and_source(self):
        result=run('export','gunman','--out',str(OUT))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        directories=sorted((ROOT/'assets/vfx').glob('gunman-*'))
        self.assertEqual(len(directories),18)
        for directory in directories:
            name=directory.name
            for file in [name+'.png',name+'.json','source.json']:
                self.assertEqual(digest(directory/file),digest(OUT/name/file),f'rebuild differs: {name}/{file}')
            manifest=json.loads((directory/'source.json').read_text())
            self.assertTrue(any(key.startswith('src/fx/gunman/') for key in manifest['source_dependencies']))
            self.assertEqual(manifest['revision'],'5294518ce7c72e48b6100a744596e0acf57f2826')
            resource=(OUT/name/(name+'.tres')).read_text()
            x,y=manifest['pivot']
            self.assertIn(f'metadata/pivot = Vector2({x}, {y})',resource)

    def test_separate_passes_and_no_default_body(self):
        result=run('export','gunman/muzzle','--split','--out',str(OUT/'split'))
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        directory=OUT/'split/gunman-muzzle'
        manifest=json.loads((directory/'source.json').read_text())
        self.assertEqual(set(manifest['passes']),{'combined','back-color','back-light','front-color','front-light'})
        self.assertEqual(digest(directory/'gunman-muzzle.png'),digest(ROOT/'assets/vfx/gunman-muzzle/gunman-muzzle.png'))
        rejected=run('export','holy/heal','--out',str(OUT/'body'))
        self.assertNotEqual(rejected.returncode,0)
        self.assertIn('paints a stock body',rejected.stderr)
        self.assertFalse((OUT/'body/holy-heal').exists())

if __name__=='__main__':
    unittest.main()
