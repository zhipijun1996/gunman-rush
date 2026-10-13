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


if __name__ == "__main__":
    unittest.main()
