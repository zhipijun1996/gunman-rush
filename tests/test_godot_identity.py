"""Synthetic executable/package fixtures; never a native Godot pass."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import godot_identity as identity
spec=importlib.util.spec_from_file_location('engine_package',ROOT/'tools/engine/package.py')
pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
sys.path.insert(0,str(ROOT/'tools/engine'))
from test_build_contract import synthetic_payload, synthetic_commands, TEST_COMMIT, TEST_RUN
import build as engine_build


class GodotIdentityTests(unittest.TestCase):
    def fixture(self,root,version=None):
        recipe=pack.RECIPE;inputs=root/'inputs';inputs.mkdir()
        for lane,job in recipe['jobs'].items():
            folder=inputs/('engine-built-'+lane);folder.mkdir()
            outputs={}
            for name in job['outputs']:
                file=folder/name
                synthetic_payload(file,version,shell=True)
                outputs[name]={'sha256':pack.sha(file),'bytes':file.stat().st_size}
            pack.write(folder/'provenance.json',{'recipe_id':recipe['id'],'recipe_sha256':pack.sha(pack.RECIPE_PATH),
                'lane':lane,'build_image':job['image'],'source':recipe['source'],'patches':recipe['patches'],
                'patched_source_sha256':recipe['patched_source_sha256'],'build_name':recipe['build_name'],
                'common_options':recipe['common_options'],'status':'built','outputs':outputs,
                'version':recipe['expected_version'],'recipe_commit':TEST_COMMIT,'workflow_run':TEST_RUN,
                'platform_options':engine_build.platform_options(job,Path(recipe['work_directory'])),
                'commands':synthetic_commands(folder,job)})
        output=root/'out';godot=pack.package(inputs,output,'https://example.invalid/',TEST_COMMIT,TEST_RUN)
        config={'godot':godot}
        install=identity.engine_directory(config);install.mkdir(parents=True)
        with zipfile.ZipFile(output/(recipe['id']+'-linux-x86_64.zip')) as archive:archive.extractall(install)
        binary=identity.engine_path(config);binary.chmod(0o755)
        shutil.copy2(output/'build-provenance.json',install/'build-provenance.json')
        data=identity.data_root(config)/'godot/export_templates';data.mkdir(parents=True)
        temp=root/'unpack';temp.mkdir()
        with zipfile.ZipFile(output/(recipe['id']+'-export-templates.tpz')) as archive:archive.extractall(temp)
        shutil.move(str(temp/'templates'),data/recipe['template_version'])
        return config

    def isolated(self):
        folder=tempfile.TemporaryDirectory();self.addCleanup(folder.cleanup)
        root=Path(folder.name)
        env=patch.dict(os.environ,{'GUNMAN_TOOLCHAIN_ROOT':str(root/'toolchains'),'GUNMAN_DATA_HOME':str(root/'data')},clear=False)
        env.start();self.addCleanup(env.stop)
        override=patch.dict(os.environ);override.start();self.addCleanup(override.stop)
        os.environ.pop('GODOT_BIN',None)
        return root

    def test_exact_fixed_binary_and_matching_templates(self):
        config=self.fixture(self.isolated())
        result=identity.verified_engine(config)
        self.assertEqual(result['version'],pack.RECIPE['expected_version'])
        self.assertEqual(result['binary_sha256'],config['godot']['linux_x86_64']['binary_sha256'])
        self.assertTrue(identity.verify_templates(config).is_dir())

    def test_byte_tamper_is_rejected_before_execution(self):
        root=self.isolated();config=self.fixture(root);binary=identity.engine_path(config)
        marker=root/'executed';binary.write_text('#!/bin/sh\ntouch '+str(marker)+'\n')
        with self.assertRaisesRegex(RuntimeError,'SHA256'):identity.verified_engine(config)
        self.assertFalse(marker.exists())

    def test_version_string_alone_cannot_admit_official_or_other_custom(self):
        for version in ['4.7.2.stable.official.ed1daf0bf','4.7.2.stable.custom_build.anything.ed1daf0bf']:
            with self.subTest(version=version):
                root=self.isolated();config=self.fixture(root,version)
                with self.assertRaisesRegex(RuntimeError,'exact patched'):identity.verified_engine(config)

    def test_missing_provenance_and_mixed_source_are_rejected(self):
        root=self.isolated();config=self.fixture(root)
        proof=identity.engine_directory(config)/'build-provenance.json'
        original=proof.read_bytes();proof.unlink()
        with self.assertRaisesRegex(RuntimeError,'missing'):identity.verified_engine(config)
        proof.write_bytes(original)
        data=json.loads(original);data['lanes']['windows-debug']['build_image']='other@sha256:'+'0'*64
        proof.write_text(json.dumps(data));config['godot']['provenance']['sha256']=identity.sha256(proof)
        with self.assertRaisesRegex(RuntimeError,'mixed/unbuilt'):identity.verified_engine(config)

    def test_same_version_template_tamper_and_extra_official_files_are_rejected(self):
        root=self.isolated();config=self.fixture(root);templates=identity.templates_directory(config)
        file=templates/'web_debug.zip';original=file.read_bytes();file.write_bytes(b'official bytes, same version.txt')
        with self.assertRaisesRegex(RuntimeError,'SHA256'):identity.verify_templates(config)
        file.write_bytes(original);(templates/'macos.zip').write_bytes(b'unselected official template')
        with self.assertRaisesRegex(RuntimeError,'mixed'):identity.verify_templates(config)

    def test_explicit_binary_override_still_requires_exact_sha(self):
        root=self.isolated();config=self.fixture(root);external=root/'external-engine'
        shutil.copy2(identity.engine_path(config),external)
        with patch.dict(os.environ,{'GODOT_BIN':str(external)}):
            self.assertEqual(identity.verified_engine(config)['binary'],str(external))
            external.write_bytes(b'unrelated custom')
            with self.assertRaisesRegex(RuntimeError,'SHA256'):identity.verified_engine(config)

    def test_inactive_or_incomplete_lock_is_rejected(self):
        root=self.isolated();config=self.fixture(root)
        bad=copy.deepcopy(config);bad['godot']['distribution']='official'
        with self.assertRaisesRegex(RuntimeError,'not been activated'):identity.validate_lock(bad)
        bad=copy.deepcopy(config);del bad['godot']['templates']['files']['web_debug.zip']
        with self.assertRaisesRegex(RuntimeError,'complete selected'):identity.validate_lock(bad)
        for value in (None,'user-data','../official-control'):
            bad=copy.deepcopy(config)
            if value is None:del bad['godot']['data_subdirectory']
            else:bad['godot']['data_subdirectory']=value
            with self.assertRaisesRegex(RuntimeError,'data_subdirectory'):identity.validate_lock(bad)
        bad=copy.deepcopy(config);bad['godot']['linux_x86_64']['binary']='../other-engine'
        with self.assertRaisesRegex(RuntimeError,'binary installation path'):identity.validate_lock(bad)

    def test_actual_cli_export_rejects_bad_templates_before_exec(self):
        for flag in ('--export-debug','--export-release','--export-pack','--export-patch'):
            with self.subTest(flag=flag),patch.object(sys,'argv',['godot_identity.py','--','--headless',flag,'Web','out']), \
                    patch.object(identity,'verified_engine',return_value={'binary':'/fixed/engine'}), \
                    patch.object(identity,'verify_templates',side_effect=RuntimeError('template hash mismatch')) as checked, \
                    patch.object(identity.os,'execve') as execute:
                with self.assertRaisesRegex(RuntimeError,'template hash'):identity.main()
                checked.assert_called_once();execute.assert_not_called()

    def test_actual_cli_native_does_not_hash_templates_or_parse_user_export_args(self):
        args=['--headless','--script','fixture.gd','--','--export-debug']
        with patch.object(sys,'argv',['godot_identity.py','--',*args]), \
                patch.object(identity,'verified_engine',return_value={'binary':'/fixed/engine'}), \
                patch.object(identity,'verify_templates') as checked, \
                patch.object(identity,'environment',return_value={'MARKER':'simulated'}), \
                patch.object(identity.os,'execve') as execute:
            identity.main()
            checked.assert_not_called()
            execute.assert_called_once_with('/fixed/engine',['/fixed/engine',*args],{'MARKER':'simulated'})

    def test_real_web_stamping_keeps_explicit_verified_build_identity(self):
        spec=importlib.util.spec_from_file_location('game_export_build',ROOT/'tools/build.py')
        exporter=importlib.util.module_from_spec(spec);spec.loader.exec_module(exporter)
        root=self.isolated();config=self.fixture(root)
        verified={key:value for key,value in identity.verified_engine(config).items() if key!='binary'}
        html=root/'index.html'
        html.write_text('<head></head><body><script src="index.js"></script>\n'
                        'const GODOT_CONFIG = {"fileSizes":{"index.pck":4,"index.wasm":4}};\n'
                        'const GODOT_THREADS_ENABLED = true;\n'
                        '(function () {\n\tconst missing = Engine.getMissingFeatures({\n'
                        "engine.startGame({\n}).then(() => {\n\t\t\tsetStatusMode('hidden');\n</body>")
        for suffix in ('.pck','.js','.wasm'):
            html.with_suffix(suffix).write_bytes(b'synthetic web '+suffix.encode())
        files=exporter.prepare_web_playtest(html,verified)
        metadata=json.loads((root/'build-info.json').read_text())
        self.assertEqual(metadata['godot_toolchain'],verified)
        self.assertTrue(metadata['threads_enabled'])
        self.assertIn(root/metadata['pack'],files)
        self.assertNotIn('binary',metadata['godot_toolchain'])

    def test_real_installer_repairs_owned_bytes_and_reuses_verified_install(self):
        import setup_environment as setup
        root=self.isolated();config=self.fixture(root)
        binary=identity.engine_path(config);binary.write_bytes(b'corrupt installed binary')
        templates=identity.templates_directory(config)
        (templates/'web_debug.zip').write_bytes(b'official same-version template')
        official=root/'toolchains/godot/4.7.2/official-control'
        official.parent.mkdir(parents=True);official.write_bytes(b'preserved historical control')
        artifacts={identity.sha256(path):path for path in (root/'out').iterdir() if path.is_file()}
        with patch.object(setup,'CONFIG',config),patch.object(setup,'ROOT',root/'toolchains'), \
                patch.object(sys,'argv',['setup_environment.py','--godot-only']), \
                patch.object(setup,'download',side_effect=lambda spec,name:artifacts[spec['sha256']]) as downloads, \
                patch.object(setup,'run') as check:
            self.assertEqual(setup.main(),0)
            self.assertEqual(downloads.call_count,3)
            self.assertTrue(list(binary.parent.parent.glob(binary.parent.name+'.rejected-*')))
            self.assertTrue(list(templates.parent.glob(templates.name+'.rejected-*')))
            self.assertEqual(official.read_bytes(),b'preserved historical control')
            self.assertEqual(identity.verified_engine(config)['version'],pack.RECIPE['expected_version'])
            identity.verify_templates(config)
            downloads.reset_mock();check.reset_mock()
            self.assertEqual(setup.main(),0)
            self.assertEqual(downloads.call_count,1) # Provenance only; no engine/template reinstall.
            check.assert_called_once_with(['python3',str(ROOT/'tools/check_environment.py'),'--godot-only'])

    def test_installer_environment_cannot_replace_official_foreign_or_symlinked_templates(self):
        import setup_environment as setup
        for mode in ('official','foreign','symlinked-official'):
            with self.subTest(mode=mode):
                root=self.isolated();config=self.fixture(root)
                official=root/'toolchains/user-data/godot/export_templates'/pack.RECIPE['template_version']
                official.mkdir(parents=True);control=official/'version.txt';control.write_text('official control')
                selected=root/'toolchains/user-data' if mode=='official' else root/mode
                if mode=='foreign':
                    folder=selected/'godot/export_templates'/pack.RECIPE['template_version']
                    folder.mkdir(parents=True);(folder/'version.txt').write_text('foreign control')
                elif mode=='symlinked-official':
                    (selected/'godot').mkdir(parents=True)
                    (selected/'godot/export_templates').symlink_to(official.parent,target_is_directory=True)
                with patch.dict(os.environ,{'GUNMAN_DATA_HOME':str(selected)}), \
                        patch.object(setup,'CONFIG',config),patch.object(setup,'ROOT',root/'toolchains'), \
                        patch.object(sys,'argv',['setup_environment.py','--godot-only']), \
                        patch.object(setup,'download') as download,patch.object(setup,'run') as execute:
                    with self.assertRaisesRegex(RuntimeError,'Refusing to'):
                        setup.main()
                    download.assert_not_called();execute.assert_not_called()
                self.assertEqual(control.read_text(),'official control')
                self.assertFalse(list(official.parent.glob('*.rejected-*')))
                if mode=='foreign':self.assertEqual((folder/'version.txt').read_text(),'foreign control')

    def test_installer_accepts_empty_isolated_data_and_reuses_same_build_symlink(self):
        import setup_environment as setup
        root=self.isolated();config=self.fixture(root)
        artifacts={identity.sha256(path):path for path in (root/'out').iterdir() if path.is_file()}
        selected=root/'empty-isolated-data'
        with patch.dict(os.environ,{'GUNMAN_DATA_HOME':str(selected)}), \
                patch.object(setup,'CONFIG',config),patch.object(setup,'ROOT',root/'toolchains'), \
                patch.object(sys,'argv',['setup_environment.py','--godot-only']), \
                patch.object(setup,'download',side_effect=lambda spec,name:artifacts[spec['sha256']]) as downloads, \
                patch.object(setup,'run'):
            self.assertEqual(setup.main(),0)
            self.assertEqual(downloads.call_count,2) # Proof plus templates in the new empty data directory.
            installed=identity.verify_templates(config)
            alias=root/'lane-data';(alias/'godot').mkdir(parents=True)
            (alias/'godot/export_templates').symlink_to(installed.parent,target_is_directory=True)
            with patch.dict(os.environ,{'GUNMAN_DATA_HOME':str(alias)}):
                downloads.reset_mock()
                self.assertEqual(setup.main(),0)
                self.assertEqual(downloads.call_count,1)
                self.assertEqual(identity.verify_templates(config).resolve(),installed)


if __name__=='__main__':unittest.main()
