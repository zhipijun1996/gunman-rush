"""Exercise failure classification and scope selection without requiring Godot."""
import importlib.util
from pathlib import Path
import tempfile
import subprocess
import time
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("harness", Path(__file__).resolve().parents[1] / "tools/harness.py")
h = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(h)


class HarnessTests(unittest.TestCase):
    def execute(self, source, timeout=5):
        with tempfile.TemporaryDirectory() as folder:
            return h.run_check({"argv": ["python3", "-c", source],
                                "timeout_seconds": timeout, "success_pattern": r"^COMPLETE$"},
                               Path(folder) / "log.txt")

    def test_nonzero_with_success_text_fails(self):
        self.assertEqual(self.execute("print('COMPLETE'); raise SystemExit(3)")["status"], "failed")

    def test_zero_without_completion_fails(self):
        self.assertEqual(self.execute("print('unfinished')")["status"], "failed")

    def test_engine_error_with_zero_exit_and_success_text_fails(self):
        self.assertEqual(self.execute("print('SCRIPT ERROR: broken'); print('COMPLETE')")["status"], "failed")

    def test_completed_success(self):
        self.assertEqual(self.execute("print('COMPLETE')")["status"], "passed")

    def test_timeout_fails(self):
        self.assertEqual(self.execute("import time; time.sleep(10)", 0.1)["status"], "timeout")

    def test_missing_executable_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            result = h.run_check({"argv": ["/missing-harness-test-command"],
                                  "timeout_seconds": 1, "success_pattern": "COMPLETE"},
                                 Path(folder) / "log.txt")
            self.assertEqual(result["status"], "failed")

    def test_timeout_stops_child_process(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "survived"
            child = f"import time; from pathlib import Path; time.sleep(0.5); Path({str(marker)!r}).touch()"
            parent = f"import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', {child!r}]); time.sleep(10)"
            self.assertEqual(self.execute(parent, 0.1)["status"], "timeout")
            time.sleep(0.6)
            self.assertFalse(marker.exists(), "Timed-out descendants must not survive")

    def test_timeout_stops_engine_in_separate_session(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "escaped"
            child = f"import time; from pathlib import Path; time.sleep(0.5); Path({str(marker)!r}).touch()"
            parent = f"import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', {child!r}], start_new_session=True); time.sleep(10)"
            self.assertEqual(self.execute(parent, 0.1)["status"], "timeout")
            time.sleep(0.6)
            self.assertFalse(marker.exists(), "Engine sessions must not escape harness timeouts")

    def test_diff_includes_all_change_sources(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)
            git("init", "-q")
            git("config", "user.email", "harness-test@example.invalid")
            git("config", "user.name", "Harness test")
            for name in ("staged", "unstaged", "deleted"):
                (root / name).write_text("initial")
            git("add", ".")
            git("commit", "-qm", "baseline")
            baseline = git("rev-parse", "HEAD").stdout.decode().strip()
            (root / "committed").write_text("new")
            git("add", "committed")
            git("commit", "-qm", "next")
            (root / "staged").write_text("changed")
            git("add", "staged")
            (root / "unstaged").write_text("changed")
            (root / "deleted").unlink()
            (root / "untracked").write_text("new")
            with patch.object(h, "ROOT", root):
                self.assertEqual(h.changed_paths(baseline),
                                 ["committed", "deleted", "staged", "unstaged", "untracked"])

    def test_scope_keeps_runtime_and_unknown_conservative(self):
        self.assertEqual(h.select_profiles(["docs/handoff.md"]), ["docs"])
        self.assertEqual(h.select_profiles(["assets/new.png"]), ["art", "docs", "gameplay"])
        for path in ("config/player_tuning.json", "new/runtime.py", ".github/workflows/environment.yml"):
            self.assertEqual(h.select_profiles([path]), ["art", "docs", "gameplay", "web"])

    def test_profiles_deduplicate_without_dropping_checks(self):
        data = h.load_manifest()
        ids = h.resolve_checks(data, ["docs", "gameplay", "art", "web"])
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(set(ids), set(data["profiles"]["full"]))


    def test_dependency_digest_invalidates_runtime_and_rules(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "scripts").mkdir(); (root / "docs").mkdir()
            (root / "scripts/a.gd").write_text("original")
            (root / "docs/a.md").write_text("original")
            files = ["scripts/a.gd", "docs/a.md"]
            check = {"inputs": ["scripts"], "argv": ["run"], "success_pattern": "PASS"}
            with patch.object(h, "ROOT", root):
                first = h.input_digest(check, files, {"engine": "v1"})
                (root / "docs/a.md").write_text("documentation change")
                self.assertEqual(first, h.input_digest(check, files, {"engine": "v1"}))
                (root / "scripts/a.gd").write_text("runtime change")
                self.assertNotEqual(first, h.input_digest(check, files, {"engine": "v1"}))
                (root / "scripts/a.gd").write_text("original")
                self.assertNotEqual(first, h.input_digest(check, files, {"engine": "v2"}))
                self.assertNotEqual(first, h.input_digest({**check, "success_pattern": "NEW"}, files, {"engine": "v1"}))
                (root / "scripts/a.gd").unlink()
                self.assertNotEqual(first, h.input_digest(check, files, {"engine": "v1"}))

    def test_cache_revalidates_log_and_rejects_missing_artifacts(self):
        import json, hashlib
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            artifacts = root / "artifacts"; artifacts.mkdir()
            cache = root / "cache.json"; log = root / "log.txt"
            item = {"log": "COMPLETE\n", "log_sha256": hashlib.sha256(b"COMPLETE\n").hexdigest(),
                    "result": {"status": "passed", "exit_code": 0}, "commit": "a"*40,
                    "artifact_directory": str(artifacts)}
            check = {"success_pattern": "^COMPLETE$"}
            cache.write_text(json.dumps(item))
            self.assertTrue(h.cached_result(check, cache, log)["reused"])
            self.assertIsNone(h.cached_result({"success_pattern": "^OTHER$"}, cache, log))
            cache.write_text(json.dumps({**item, "log": "CORRUPT"}))
            self.assertIsNone(h.cached_result(check, cache, log))
            cache.write_text(json.dumps({**item, "result": {"status": "failed", "exit_code": 1}}))
            self.assertIsNone(h.cached_result(check, cache, log))
            cache.write_text(json.dumps(item)); artifacts.rmdir()
            self.assertIsNone(h.cached_result(check, cache, log))

    def test_parallel_workspaces_isolate_user_data_and_preserve_dirty_source(self):
        import os
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"; root.mkdir()
            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)
            git("init", "-q"); git("config", "user.email", "test@example.invalid"); git("config", "user.name", "Test")
            (root / "input.txt").write_text("before")
            (root / "deleted.txt").write_text("before")
            git("add", "."); git("commit", "-qm", "baseline")
            (root / "input.txt").write_text("after"); (root / "deleted.txt").unlink()
            (root / "new.txt").write_text("new")
            with patch.object(h, "ROOT", root):
                one = Path(temporary) / "one"; two = Path(temporary) / "two"
                env1 = h.isolated_workspace(one, h.source_files())
                env2 = h.isolated_workspace(two, h.source_files())
                self.assertEqual((one / "input.txt").read_text(), "after")
                self.assertFalse((two / "deleted.txt").exists())
                self.assertEqual((two / "new.txt").read_text(), "new")
                self.assertNotEqual(env1["GUNMAN_DATA_HOME"], env2["GUNMAN_DATA_HOME"])
                (one / "input.txt").write_text("mutated")
                self.assertEqual((two / "input.txt").read_text(), "after")
                self.assertEqual((root / "input.txt").read_text(), "after")


    def test_parallel_results_and_source_mutation_fail_closed(self):
        import json
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "source"; root.mkdir()
            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)
            git("init", "-q"); git("config", "user.email", "test@example.invalid"); git("config", "user.name", "Test")
            (root / ".gitignore").write_text("build/\n")
            (root / "input.txt").write_text("before")
            git("add", "."); git("commit", "-qm", "baseline")
            check = {"argv": ["python3", "-c", "print('COMPLETE')"], "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
            with patch.object(h, "ROOT", root), patch.object(h, "toolchain_identity", return_value={}):
                folder = root / "build/report"; folder.mkdir(parents=True)
                results = h.execute_checks({"checks": {"a": check, "b": check}}, ["a", "b"], folder, jobs=2)
                self.assertEqual([r['status'] for r in results], ['passed', 'passed'])
                bad = {**check, "argv": ["python3", "-c", "from pathlib import Path; Path('input.txt').write_text('mutated'); print('COMPLETE')"]}
                result = h.execute_checks({"checks": {"bad": bad}}, ["bad"], folder, jobs=2)
                self.assertEqual(result[0]['status'], 'failed')
                self.assertEqual((root / 'input.txt').read_text(), 'before')
                created = {**check, "argv": ["python3", "-c", "from pathlib import Path; Path('unexpected.gd').write_text('extends Node'); print('COMPLETE')"]}
                result = h.execute_checks({"checks": {"created": created}}, ['created'], folder, jobs=2)
                self.assertEqual(result[0]['status'], 'failed', 'New untracked source invalidates frozen proof')
                self.assertFalse((root / 'unexpected.gd').exists(), 'Failed lane must not alter original checkout')
                deleted = {**check, "argv": ["python3", "-c", "from pathlib import Path; Path('input.txt').unlink(); print('COMPLETE')"]}
                result = h.execute_checks({"checks": {"deleted": deleted}}, ['deleted'], folder, jobs=2)
                self.assertEqual(result[0]['status'], 'failed', 'Deleting tracked source invalidates frozen proof')
                self.assertEqual((root / 'input.txt').read_text(), 'before')
                # Nonzero exit cannot be concealed by a success marker in another lane.
                fail = {**check, "argv": ["python3", "-c", "print('COMPLETE'); raise SystemExit(4)"]}
                result = h.execute_checks({"checks": {"good": check, "bad": fail}}, ['good', 'bad'], folder, jobs=2)
                self.assertEqual(next(r['status'] for r in result if r['id']=='bad'), 'failed')


if __name__ == "__main__":
    unittest.main()
