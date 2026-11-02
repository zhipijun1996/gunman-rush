"""Real small Git/ZIP fixtures for source/tool custody; no browser or engine."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_ci_artifact_browser as verifier


class ToolRootTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.game = self.base / 'game'
        self.tool = self.base / 'tool'
        self.game.mkdir()
        self.git(self.game, 'init', '-q')
        self.write(self.game, '.gitignore', 'build/\n__pycache__/\n')
        names = [f'tools/{name}.py' for name in verifier.CONSUMERS]
        names += ['tools/harness.py', 'tools/publish_playtest.py', 'tools/verify_ci_artifact_browser.py', 'game/player.gd']
        consumers = {f'tools/{name}.py' for name in verifier.CONSUMERS}
        for name in names:
            self.write(self.game, name, '# original ' + name + '\nassert True # business assertion\n')
        self.write(self.game, 'resources/player/traversal.tres', 'hook_vertical_kick_deadzone = 4.0\n')
        for name in verifier.REVIEWED_TOOL_FILES:
            if name.endswith('.py') and name not in consumers:
                self.write(self.game, name, '# old helper\n')
        visual = {}
        for name in ('game/visual.gd', 'assets/ui/font.ttf'):
            self.write(self.game, name, 'original visual ' + name + '\n')
            visual[name] = verifier.sha(self.game / name)
        references = {name: verifier.sha(self.game / name) for name in consumers}
        self.game_commit = self.commit(self.game)
        self.git(self.base, 'clone', '-q', '--no-hardlinks', str(self.game), str(self.tool))
        approved, migrations = {}, {}
        for name in verifier.REVIEWED_TOOL_FILES:
            if name in consumers:
                old, new = '# original ' + name, '# locator ' + name
                self.write(self.tool, name, (self.game / name).read_text().replace(old, new))
                migrations[name] = [[old, new, 1]]
            else:
                self.write(self.tool, name, 'reviewed ' + name + '\n')
            approved[name] = verifier.sha(self.tool / name)
        self.write(self.tool, 'tools/verify_ci_artifact_browser.py', '# reviewed coordinator\n')
        self.write(self.tool, 'tools/test_verify_ci_artifact_browser.py', '# reviewed tests\n')
        self.tool_commit = self.commit(self.tool)
        self.addCleanup(patch.stopall)
        patch.object(verifier, 'REVIEWED_TOOL_FILES', approved).start()
        patch.object(verifier, 'CONSUMER_REFERENCE_COMMIT', self.game_commit).start()
        patch.object(verifier, 'REFERENCE_CONSUMER_SHA256', references).start()
        patch.object(verifier, 'CONSUMER_MIGRATIONS', migrations).start()
        patch.object(verifier, 'REVIEWED_VISUAL_INPUTS', visual).start()

    @staticmethod
    def git(root, *args):
        return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE).decode().strip()

    @staticmethod
    def write(root, name, text):
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def commit(self, root):
        self.git(root, 'add', '.')
        self.git(root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture')
        return self.git(root, 'rev-parse', 'HEAD')

    def pair(self):
        return verifier.validate_tool_pair(verifier.SourceRoot(self.game, self.game_commit).snapshot(),
                                           verifier.SourceRoot(self.tool, self.tool_commit).snapshot(),
                                           self.tool / 'tools/verify_ci_artifact_browser.py')

    def test_clean_exact_pair(self):
        self.assertEqual(set(self.pair()), set(verifier.REVIEWED_TOOL_FILES) | verifier.COORDINATOR_FILES)

    def test_both_dirty_roots_rejected(self):
        for root in (self.game, self.tool):
            with self.subTest(root=root):
                path = root / 'game/player.gd'
                original = path.read_bytes()
                path.write_bytes(original + b'# edit\n')
                with self.assertRaisesRegex(ValueError, 'worktree changed'):
                    self.pair()
                path.write_bytes(original)

    def test_wrong_head_rejected(self):
        with self.assertRaisesRegex(ValueError, 'HEAD'):
            verifier.SourceRoot(self.tool, self.game_commit).snapshot()

    def test_top_level_business_script_change_rejected(self):
        self.write(self.tool, 'tools/verify_action_budget_browser.py', '# altered checks\n')
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'Unreviewed tool bytes'):
            self.pair()

    def test_runtime_and_unknown_tool_changes_rejected(self):
        for name in ('game/player.gd', 'tools/new_unknown_helper.py'):
            with self.subTest(path=name):
                prior = self.tool_commit
                self.write(self.tool, name, '# unapproved\n')
                self.tool_commit = self.commit(self.tool)
                with self.assertRaisesRegex(ValueError, 'Unreviewed tool-root changes'):
                    self.pair()
                self.git(self.tool, 'reset', '--hard', prior)
                self.tool_commit = prior

    def test_known_helper_wrong_bytes_rejected(self):
        self.write(self.tool, 'tools/studio_gui_pointer.py', '# different helper\n')
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'Unreviewed tool bytes'):
            self.pair()

    def test_skip_worktree_actual_runtime_drift_rejected(self):
        self.git(self.tool, 'update-index', '--skip-worktree', 'game/player.gd')
        self.write(self.tool, 'game/player.gd', '# hidden edit\n')
        self.assertEqual(self.git(self.tool, 'status', '--porcelain'), '')
        with self.assertRaisesRegex(ValueError, 'Git blob'):
            self.pair()

    def test_missing_real_resource_rejected_but_unused_sparse_media_allowed(self):
        self.git(self.tool, 'update-index', '--skip-worktree', 'game/player.gd')
        (self.tool / 'game/player.gd').unlink()
        self.pair()  # No game source is loaded by these browser scripts; PCK is separately verified.
        self.git(self.tool, 'update-index', '--skip-worktree', 'resources/player/traversal.tres')
        (self.tool / 'resources/player/traversal.tres').unlink()
        with self.assertRaisesRegex(ValueError, 'traversal Resource'):
            self.pair()

    def test_real_root_replacement_rejected(self):
        guard = verifier.SourceRoot(self.tool, self.tool_commit)
        guard.snapshot()
        moved = self.base / 'old-tool'
        self.tool.rename(moved)
        shutil.copytree(moved, self.tool)
        with self.assertRaisesRegex(ValueError, 'root replaced'):
            guard.snapshot()

    def test_wrong_executing_coordinator_rejected(self):
        with self.assertRaisesRegex(ValueError, 'execute from'):
            verifier.validate_tool_pair(verifier.SourceRoot(self.game, self.game_commit).snapshot(),
                                         verifier.SourceRoot(self.tool, self.tool_commit).snapshot(),
                                         self.game / 'tools/verify_ci_artifact_browser.py')

    def test_actual_file_replaced_by_symlink_rejected(self):
        path = self.tool / 'game/player.gd'
        original = path.read_bytes()
        other = self.base / 'identical.gd'
        other.write_bytes(original)
        self.git(self.tool, 'update-index', '--skip-worktree', 'game/player.gd')
        path.unlink()
        path.symlink_to(other)
        with self.assertRaisesRegex(ValueError, 'Symlink source'):
            self.pair()

    def run_main(self, *, dual=False, mutation=None, extra=()):
        root = self.tool if dual else self.game
        output = self.game / 'build/test-receipt'
        run = self.base / 'run.json'
        api = self.base / 'artifact.json'
        archive = self.base / 'web.zip'
        pack = b'actual fixture pack bytes'
        pack_sha = hashlib.sha256(pack).hexdigest()
        info = {'source_commit': self.game_commit, 'build_id': pack_sha[:12], 'pack': 'game.pck', 'pack_bytes': len(pack)}
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('web/build-info.json', json.dumps(info))
            z.writestr('web/game.pck', pack)
        run.write_text(json.dumps({'id': 123, 'head_sha': self.game_commit, 'run_attempt': 1}))
        api.write_text(json.dumps({'id': 456, 'workflow_run': {'id': 123, 'head_sha': self.game_commit},
                                   'digest': 'sha256:' + verifier.sha(archive), 'size_in_bytes': archive.stat().st_size}))
        argv = ['verify_ci_artifact_browser.py', '--run-api', str(run), '--artifact-api', str(api),
                '--artifact-zip', str(archive), '--commit', self.game_commit, '--run-id', '123', '--output', str(output)]
        if dual:
            argv += ['--production-source-root', str(self.game), '--consumer-tool-root', str(self.tool),
                     '--consumer-tool-commit', self.tool_commit]
        argv += list(extra)
        tess = self.base / 'tessdata'
        tess.mkdir(exist_ok=True)
        for name in ('eng', 'chi_sim', 'osd'):
            (tess / (name + '.traineddata')).write_bytes(b'fixture model')
        (tess / 'configs').mkdir(exist_ok=True)
        (tess / 'configs/tsv').write_text('tessedit_create_tsv 1\n')
        calls = []

        def fake_check(check, log, root=None):
            calls.append(check)
            log.write_text('fixture process result; no browser executed\n')
            if mutation:
                mutation(output, archive, len(calls))
            return {'status': 'passed', 'exit_code': 0}

        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(verifier, 'ROOT', root))
            stack.enter_context(patch.object(verifier, '__file__', str(root / 'tools/verify_ci_artifact_browser.py')))
            stack.enter_context(patch.object(verifier.harness, '__file__', str(root / 'tools/harness.py')))
            stack.enter_context(patch.object(verifier.publish_playtest, '__file__', str(root / 'tools/publish_playtest.py')))
            stack.enter_context(patch.object(verifier.harness, 'run_check', side_effect=fake_check))
            stack.enter_context(patch.object(verifier, 'ThreadingHTTPServer'))
            stack.enter_context(patch.object(verifier, 'Thread'))
            stack.enter_context(patch.object(sys, 'argv', argv))
            stack.enter_context(patch.dict(os.environ, {'TESSDATA_PREFIX': str(tess), 'PYTHONPATH': ''}))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            result = verifier.main()
        return result, json.loads((output / 'receipt.json').read_text()), calls

    def test_default_mode_retains_original_source_and_three_checks(self):
        result, receipt, calls = self.run_main()
        self.assertEqual(result, 0)
        self.assertFalse(receipt['dual_root_mode'])
        self.assertEqual(receipt['consumer_tool_commit'], self.game_commit)
        self.assertEqual(len(calls), 3)
        self.assertEqual([c['timeout_seconds'] for c in calls], [300] * 3)
        self.assertEqual([c['success_pattern'] for c in calls], ['"failed": \\[\\]', '"failed": 0', '"failed": 0'])

    def test_dual_mode_real_zip_and_two_separate_identities(self):
        result, receipt, calls = self.run_main(dual=True)
        self.assertEqual(result, 0)
        self.assertEqual(receipt['source_commit'], self.game_commit)
        self.assertEqual(receipt['consumer_tool_commit'], self.tool_commit)
        self.assertNotEqual(receipt['source_commit'], receipt['consumer_tool_commit'])
        self.assertEqual(receipt['build_info']['source_commit'], self.game_commit)
        self.assertEqual([c['argv'][1] for c in calls], [str(self.tool / 'tools' / (name + '.py')) for name in verifier.CONSUMERS])
        self.assertEqual(len(receipt['ocr_environment']['input_sha256']), 4)

    def test_pack_drift_rejected(self):
        def change(output, archive, count):
            if count == 3:
                (output / 'web/web/game.pck').write_bytes(b'drift')
        with self.assertRaisesRegex(ValueError, 'served artifact changed'):
            self.run_main(dual=True, mutation=change)

    def test_zip_drift_rejected_even_after_successful_consumers(self):
        def change(output, archive, count):
            if count == 3:
                archive.write_bytes(archive.read_bytes() + b'drift')
        with self.assertRaisesRegex(ValueError, 'Artifact/API bytes changed'):
            self.run_main(dual=True, mutation=change)
        report = json.loads((self.game / 'build/test-receipt/receipt.json').read_text())
        self.assertEqual(report['status'], 'failed')
        self.assertTrue(report['guard_errors'])

    def test_source_drift_after_consumers_rejected(self):
        def change(output, archive, count):
            if count == 3:
                self.write(self.tool, 'game/player.gd', '# changed during execution\n')
        with self.assertRaisesRegex(ValueError, 'worktree changed'):
            self.run_main(dual=True, mutation=change)

    def test_same_length_ocr_model_drift_rejected(self):
        def change(output, archive, count):
            if count == 3:
                path = self.base / 'tessdata/eng.traineddata'
                path.write_bytes(b'X' * path.stat().st_size)
        with self.assertRaisesRegex(ValueError, 'Artifact/API bytes changed'):
            self.run_main(dual=True, mutation=change)

    def test_default_mode_does_not_accept_an_unrelated_head(self):
        self.game_commit = self.tool_commit
        with self.assertRaisesRegex(ValueError, 'HEAD'):
            self.run_main()

    def test_explicit_mode_cannot_attribute_game_package_to_tool_commit(self):
        self.game_commit = self.tool_commit
        with self.assertRaisesRegex(ValueError, 'HEAD'):
            self.run_main(dual=True)

    def test_approved_new_consumer_inverse_is_exact(self):
        self.pair()
        for name, rows in verifier.CONSUMER_MIGRATIONS.items():
            restored = (self.tool / name).read_text()
            for old, new, count in reversed(rows):
                self.assertEqual(restored.count(new), count)
                restored = restored.replace(new, old)
            self.assertEqual(restored.encode(), (self.game / name).read_bytes())

    def test_resigned_business_assertion_change_rejected(self):
        name = 'tools/verify_action_budget_browser.py'
        path = self.tool / name
        path.write_text(path.read_text().replace('assert True', 'assert False'))
        verifier.REVIEWED_TOOL_FILES[name] = verifier.sha(path)
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'inverse differs'):
            self.pair()

    def test_resigned_extra_operation_rejected(self):
        name = 'tools/verify_studio_click_browser.py'
        path = self.tool / name
        path.write_text(path.read_text() + "send_input('extra')\n")
        verifier.REVIEWED_TOOL_FILES[name] = verifier.sha(path)
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'inverse differs'):
            self.pair()

    def test_resigned_duplicate_locator_rejected(self):
        name = 'tools/verify_all_weapon_browser.py'
        path = self.tool / name
        new = verifier.CONSUMER_MIGRATIONS[name][0][1]
        path.write_text(path.read_text() + new + '\n')
        verifier.REVIEWED_TOOL_FILES[name] = verifier.sha(path)
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'occurrence mismatch'):
            self.pair()

    def test_changed_visual_bytes_in_both_clean_roots_rejected(self):
        for root in (self.game, self.tool):
            self.write(root, 'game/visual.gd', '# changed visual but same in both roots\n')
        self.game_commit = self.commit(self.game)
        self.tool_commit = self.commit(self.tool)
        with self.assertRaisesRegex(ValueError, 'Incompatible actual visual input'):
            self.pair()

    def test_production_script_must_remain_reference_bytes(self):
        name = 'tools/verify_action_budget_browser.py'
        path = self.game / name
        path.write_text(path.read_text() + '# extra production change\n')
        self.game_commit = self.commit(self.game)
        with self.assertRaisesRegex(ValueError, 'Production consumer differs'):
            self.pair()

    def test_missing_visual_input_rejected(self):
        name = 'assets/ui/font.ttf'
        self.git(self.tool, 'update-index', '--skip-worktree', name)
        (self.tool / name).unlink()
        with self.assertRaisesRegex(ValueError, 'Incompatible actual visual input'):
            self.pair()

    def test_new_game_commit_does_not_relabel_reference_as_game_identity(self):
        reference = verifier.CONSUMER_REFERENCE_COMMIT
        for root in (self.game, self.tool):
            self.write(root, 'game/player.gd', '# same independent runtime repair\n')
        self.game_commit = self.commit(self.game)
        self.tool_commit = self.commit(self.tool)
        result, receipt, _ = self.run_main(dual=True)
        self.assertEqual(result, 0)
        self.assertNotEqual(self.game_commit, reference)
        self.assertEqual(receipt['source_commit'], self.game_commit)
        self.assertEqual(receipt['build_info']['source_commit'], self.game_commit)
        self.assertEqual(receipt['consumer_reference_commit'], reference)
        self.assertTrue(receipt['consumer_migrations_verified'])

    def test_partial_explicit_mode_rejected(self):
        with self.assertRaisesRegex(ValueError, 'all three'):
            self.run_main(extra=['--consumer-tool-root', str(self.tool)])


if __name__ == '__main__':
    unittest.main()
