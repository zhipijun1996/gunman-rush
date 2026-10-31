#!/usr/bin/env python3
"""Non-engine tests for immutable build input and mixed-artifact rejection."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
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

TEST_COMMIT='a'*40
TEST_RUN='12345'


def synthetic_payload(file,version=None,shell=False):
    marker=(R['expected_version'].rsplit('.',1)[0]+'\n'+R['source']['source_commit']).encode()
    if file.name.startswith('web_'):
        with zipfile.ZipFile(file,'w') as archive:archive.writestr('godot.wasm',b'\0asm SYNTHETIC '+marker)
    elif file.suffix=='.apk':
        with zipfile.ZipFile(file,'w') as archive:archive.writestr('lib/arm64-v8a/libgodot_android.so',b'SYNTHETIC '+marker)
    elif shell and file.name=='godot-linux-x86_64':
        file.write_text("#!/bin/sh\n# "+R['expected_version']+" "+R['source']['source_commit']+"\nprintf '%s\\n' '"+(version or R['expected_version'])+"'\n")
    else:file.write_bytes(b'SYNTHETIC PACKAGE FIXTURE ONLY '+marker)


def synthetic_commands(folder,job):
    rows=copy.deepcopy(build.command_contract(job,Path(R['work_directory'])))
    for index,row in enumerate(rows):
        log=folder/f'step-{index}.log';log.write_text('SIMULATED compiler log; no native compilation')
        row.update(exit_code=0,log=log.name,log_sha256=pack.sha(log))
    return rows


def package_fixture(*args):
    return pack.package(*args,expected_commit=TEST_COMMIT,expected_run=TEST_RUN)



class EngineBuildContract(unittest.TestCase):
    def test_android_scons_cli_uses_locked_python_wheel_and_literal_arguments(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);wheel=root/"locked wheel's path";module=wheel/'SCons'
            module.mkdir(parents=True);(module/'__init__.py').write_text('')
            (module/'__main__.py').write_text(
                'import json,sys\nprint(json.dumps({"args":sys.argv[1:],"python":sys.executable,"module":__file__}))\n'
                'raise SystemExit(17 if "--fail" in sys.argv else 0)\n')
            python=root/"locked python's path";python.symlink_to(sys.executable)
            hostile=root/'hostile';hostile.mkdir()
            (hostile/'scons').write_text('#!/bin/sh\nexit 99\n');(hostile/'scons').chmod(0o755)
            env={**os.environ,'PATH':str(hostile),'PYTHONPATH':str(hostile)}
            executable=build.install_scons_cli(python,wheel,root/'controlled-bin',env)
            self.assertEqual(shutil.which('scons',path=env['PATH']),str(executable))
            marker=root/'must-not-exist'
            arguments=['argument with spaces',"quote'\"",'$(touch '+str(marker)+')','semi;colon','--']
            result=subprocess.run(['scons',*arguments],env=env,cwd=root,capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            recorded=json.loads(result.stdout)
            self.assertEqual(recorded['args'],arguments)
            self.assertEqual(Path(recorded['python']).resolve(),Path(sys.executable).resolve())
            self.assertEqual(Path(recorded['module']),module/'__main__.py')
            self.assertFalse(marker.exists())
            failed=subprocess.run(['scons','--fail'],env=env,cwd=root,capture_output=True,text=True,timeout=10)
            self.assertEqual(failed.returncode,17)
            self.assertEqual(json.loads(failed.stdout)['args'],['--fail'])
        commands=build.command_contract(R['jobs']['android-arm64'],Path(R['work_directory']))
        self.assertEqual(len(commands),3)
        self.assertEqual(commands[-1]['argv'][-1],'generateGodotTemplates')
        self.assertNotIn('-PgenerateNativeLibs',commands[-1]['argv'])

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
            with zipfile.ZipFile(file,'w') as archive:
                for name,target in [('alias','dir/link/../outside'),('dir/link','..')]:
                    link=zipfile.ZipInfo(name);link.create_system=3;link.external_attr=0o120777<<16
                    archive.writestr(link,target)
            with self.assertRaisesRegex(RuntimeError,'Unsafe ZIP symlink chain'):
                build.extract(file,root/'invalid-chain')

    def fixture(self,root):
        for lane,job in R['jobs'].items():
            folder=root/('engine-built-'+lane);folder.mkdir()
            outputs={}
            for name in job['outputs']:
                file=folder/name;synthetic_payload(file)
                outputs[name]={'sha256':pack.sha(file),'bytes':file.stat().st_size}
            receipt={'recipe_id':R['id'],'recipe_sha256':pack.sha(pack.RECIPE_PATH),'lane':lane,
                     'build_image':job['image'],'source':R['source'],'patches':R['patches'],
                     'patched_source_sha256':R['patched_source_sha256'],'build_name':R['build_name'],
                     'common_options':R['common_options'],'status':'built','outputs':outputs,
                     'version':R['expected_version'],'recipe_commit':TEST_COMMIT,'workflow_run':TEST_RUN,
                     'platform_options':build.platform_options(job,Path(R['work_directory'])),
                     'commands':synthetic_commands(folder,job)}
            pack.write(folder/'provenance.json',receipt)

    def test_matching_complete_package_is_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            a=package_fixture(root,root/'a','https://example.invalid/')
            b=package_fixture(root,root/'b','https://example.invalid/')
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
                package_fixture(root,root/'out','https://example.invalid/')

    def test_mixed_recipe_image_patch_or_official_engine_is_rejected(self):
        for key,bad in [('recipe_sha256','0'*64),('build_image','unpinned:latest'),
                        ('patches',[]),('build_name','official'),('version','4.7.2.stable.official.ed1daf0bf'),
                        ('recipe_commit','b'*40),('workflow_run','54321'),('platform_options',[])]:
            with self.subTest(key=key),tempfile.TemporaryDirectory() as temp:
                root=Path(temp);self.fixture(root)
                path=root/'engine-built-linux-editor/provenance.json'
                receipt=json.loads(path.read_text());receipt[key]=bad;pack.write(path,receipt)
                with self.assertRaises(ValueError):package_fixture(root,root/'out','https://example.invalid/')

    def test_actual_command_and_rehashed_official_payload_are_rejected(self):
        for mutation in ('command','payload','log'):
            with self.subTest(mutation=mutation),tempfile.TemporaryDirectory() as temp:
                root=Path(temp);self.fixture(root)
                folder=root/'engine-built-linux-editor';path=folder/'provenance.json'
                receipt=json.loads(path.read_text())
                if mutation=='command':receipt['commands'][0]['argv'].append('optimize=none')
                elif mutation=='log':(folder/receipt['commands'][0]['log']).write_text('changed')
                else:
                    file=folder/'godot-linux-x86_64';file.write_bytes(b'Godot Engine v4.7.2.stable.official.ed1daf0bf')
                    receipt['outputs'][file.name]={'sha256':pack.sha(file),'bytes':file.stat().st_size}
                pack.write(path,receipt)
                with self.assertRaises((ValueError,RuntimeError)):
                    package_fixture(root,root/'out','https://example.invalid/')

    def test_missing_lane_and_missing_template_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'engine-built-android-arm64/android_source.zip').unlink()
            with self.assertRaises(FileNotFoundError):package_fixture(root,root/'out','https://example.invalid/')
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.fixture(root)
            (root/'engine-built-web-threaded-debug/provenance.json').unlink()
            with self.assertRaises(FileNotFoundError):package_fixture(root,root/'out','https://example.invalid/')


if __name__=='__main__':
    unittest.main()
