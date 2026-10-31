#!/usr/bin/env python3
"""Non-engine tests for immutable build input and mixed-artifact rejection."""
import copy
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
import zipfile
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('engine_package',ROOT/'tools/engine/package.py')
pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
R=pack.RECIPE
sys.path.insert(0,str(ROOT/'tools/engine'))
import build


class EngineBuildContract(unittest.TestCase):
    def test_inputs_are_content_locked(self):
        self.assertEqual(len(R['patches']),2)
        self.assertEqual(len(R['patched_source_sha256']),4)
        self.assertNotIn('official',R['expected_version'])
        self.assertIn('custom_build.gunman_sd1',R['expected_version'])
        for item in [R['source'],*R['patches'],*R['dependencies'].values()]:
            self.assertRegex(item['sha256'],r'^[a-f0-9]{64}$')
        for patch in R['patches']:
            self.assertEqual(pack.sha(ROOT/patch['file']),patch['sha256'])
        for job in R['jobs'].values():
            self.assertRegex(job['image'],r'@sha256:[a-f0-9]{64}$')
        self.assertNotIn('optimize=none',R['common_options'])
        self.assertEqual(R['edition'],'Standard')

    def test_sdk_zip_keeps_internal_symlinks_and_rejects_escape(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);file=root/'sdk.zip'
            with zipfile.ZipFile(file,'w') as archive:
                archive.writestr('sdk/bin/real','compiler')
                link=zipfile.ZipInfo('sdk/bin/alias');link.create_system=3;link.external_attr=0o120777<<16
                archive.writestr(link,'real')
            build.extract(file,root/'valid')
            self.assertTrue((root/'valid/sdk/bin/alias').is_symlink())
            self.assertEqual((root/'valid/sdk/bin/alias').read_text(),'compiler')
            with zipfile.ZipFile(file,'w') as archive:archive.writestr(link,'../../../../outside')
            with self.assertRaisesRegex(RuntimeError,'Unsafe ZIP symlink'):
                build.extract(file,root/'invalid')

    def fixture(self,root):
        for lane,job in R['jobs'].items():
            folder=root/('engine-built-'+lane);folder.mkdir()
            outputs={}
            for name in job['outputs']:
                file=folder/name;file.write_text('SYNTHETIC PACKAGE TEST ONLY: '+name)
                outputs[name]={'sha256':pack.sha(file),'bytes':file.stat().st_size}
            receipt={'recipe_id':R['id'],'recipe_sha256':pack.sha(pack.RECIPE_PATH),'lane':lane,
                     'build_image':job['image'],'source':R['source'],'patches':R['patches'],
                     'patched_source_sha256':R['patched_source_sha256'],'build_name':R['build_name'],
                     'common_options':R['common_options'],'status':'built','outputs':outputs,
                     'version':R['expected_version']}
            pack.write(folder/'provenance.json',receipt)

    def test_matching_complete_package_is_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            a=pack.package(root,root/'a','https://example.invalid/')
            b=pack.package(root,root/'b','https://example.invalid/')
            self.assertEqual(a,b)
            self.assertIn('web_debug.zip',a['templates']['files'])
            self.assertIn('web_nothreads_debug.zip',a['templates']['files'])
            self.assertIn('android_source.zip',a['templates']['files'])
            self.assertIn('linux_release.x86_64',a['templates']['files'])
            self.assertIn('windows_debug_x86_64.exe',a['templates']['files'])

    def test_mutated_binary_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'engine-built-linux-editor/godot-linux-x86_64').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'integrity'):
                pack.package(root,root/'out','https://example.invalid/')

    def test_mixed_recipe_image_patch_or_official_engine_is_rejected(self):
        for key,bad in [('recipe_sha256','0'*64),('build_image','unpinned:latest'),
                        ('patches',[]),('build_name','official'),('version','4.7.2.stable.official.ed1daf0bf')]:
            with self.subTest(key=key),tempfile.TemporaryDirectory() as temp:
                root=Path(temp);self.fixture(root)
                path=root/'engine-built-linux-editor/provenance.json'
                receipt=json.loads(path.read_text());receipt[key]=bad;pack.write(path,receipt)
                with self.assertRaises(ValueError):pack.package(root,root/'out','https://example.invalid/')

    def test_missing_lane_and_missing_template_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'engine-built-android-arm64/android_source.zip').unlink()
            with self.assertRaises(FileNotFoundError):pack.package(root,root/'out','https://example.invalid/')
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'engine-built-web-threaded-debug/provenance.json').unlink()
            with self.assertRaises(FileNotFoundError):pack.package(root,root/'out','https://example.invalid/')


if __name__=='__main__':
    unittest.main()
