"""Real portable frozen-asset restore and shallow-checkout failure boundaries."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from run_plains_action_golden_tests import restore_frozen_assets
from run_tests import REPO


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


class FrozenAssetsTests(unittest.TestCase):
    def test_actual_v9_assets_restore_without_current_asset_mutation(self):
        basis = REPO / 'docs/evidence/plains_redesign/frozen_v9'
        manifest = json.loads((basis / 'manifest.json').read_text())
        before = {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in manifest['asset_blobs']}
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            receipt = restore_frozen_assets(REPO, project, basis, manifest)
            for name, expected in manifest['asset_blobs'].items():
                self.assertEqual(blob((project / name).read_bytes()), expected, name)
            self.assertEqual(receipt['asset_count'], 484)
            self.assertEqual((project/'assets/manifest.json').read_bytes(), (basis/'asset_blobs'/manifest['asset_blobs']['assets/manifest.json']).read_bytes())
        self.assertEqual(before, {name: hashlib.sha256((REPO/name).read_bytes()).hexdigest() for name in before})

    def test_shallow_checkout_reuses_and_restores_changed_and_missing_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); origin = root/'origin'; origin.mkdir()
            def git(*args, cwd=origin):
                return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.DEVNULL).strip()
            git('init','-q');git('config','user.email','fixture@example.invalid');git('config','user.name','Frozen fixture')
            old=b'original frozen manifest\n'; same=b'identical asset\n'; removed=b'old removed asset\n'
            (origin/'assets').mkdir()
            for name,data in [('manifest',old),('same',same),('removed',removed)]: (origin/'assets'/name).write_bytes(data)
            git('add','.');git('commit','-qm','baseline');old_commit=git('rev-parse','HEAD').decode()
            self.assertEqual(git('cat-file','blob',blob(old)),old.strip())
            basis=origin/'basis';(basis/'asset_blobs').mkdir(parents=True)
            for data in [old,removed]: (basis/'asset_blobs'/blob(data)).write_bytes(data)
            (origin/'assets/manifest').write_bytes(b'current changed manifest\n');(origin/'assets/removed').unlink()
            git('add','-A');git('commit','-qm','current and portable baseline')
            clone=root/'shallow';git('clone','-q','--depth=1',origin.as_uri(),str(clone))
            self.assertEqual(git('rev-parse','--is-shallow-repository',cwd=clone),b'true')
            self.assertNotEqual(subprocess.run(['git','cat-file','-e',old_commit],cwd=clone,capture_output=True).returncode,0)
            output=root/'project';manifest={'asset_blobs':{'assets/manifest':blob(old),'assets/same':blob(same),'assets/removed':blob(removed)}}
            receipt=restore_frozen_assets(clone,output,clone/'basis',manifest)
            self.assertEqual(receipt['reused_count'],1);self.assertEqual(len(receipt['restored']),2)
            self.assertEqual((output/'assets/manifest').read_bytes(),old);self.assertEqual((output/'assets/removed').read_bytes(),removed)
            self.assertEqual((clone/'assets/manifest').read_bytes(),b'current changed manifest\n')

    def test_missing_portable_blob_rejects_changed_current_asset(self):
        self.refusal('missing')

    def test_corrupt_portable_blob_rejects_instead_of_current_fallback(self):
        self.refusal('corrupt')

    def test_wrong_frozen_identity_rejects(self):
        self.refusal('wrong_identity')

    def refusal(self, mode):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);repo=root/'repo';repo.mkdir();(repo/'asset').write_bytes(b'new')
            basis=root/'basis';(basis/'asset_blobs').mkdir(parents=True);expected=blob(b'old')
            if mode=='wrong_identity': expected=blob(b'other')
            if mode!='missing':(basis/'asset_blobs'/expected).write_bytes(b'corrupt' if mode=='corrupt' else b'old')
            with self.assertRaisesRegex(RuntimeError,'Frozen v9 asset'):
                restore_frozen_assets(repo,root/'project',basis,{'asset_blobs':{'asset':expected}})
            self.assertEqual((repo/'asset').read_bytes(),b'new')


if __name__=='__main__':unittest.main()
