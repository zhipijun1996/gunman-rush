"""Exercise failure classification and scope selection without requiring Godot."""
import importlib.util
import hashlib
import json
import os
import sys
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

    def test_check_token_gives_two_real_fresh_outputs_without_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = ("import os,sys; from pathlib import Path; "
                      "p=Path(sys.argv[1]); p.mkdir(parents=True,exist_ok=False); "
                      "(p/'receipt.txt').write_text(os.environ['GUNMAN_CHECK_TOKEN']); "
                      "print('COMPLETE')")
            argv = ["python3", "-c", source, "build/proof/harness-{check_token}"]
            check = {"argv": argv.copy(), "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
            digest = h.input_digest(check, [], {})
            first = h.run_check(check, root / "first.log", root=root)
            self.assertEqual(first["status"], "passed")
            first_file = root / first["expanded_argv"][-1] / "receipt.txt"
            original = first_file.read_bytes()
            second = h.run_check(check, root / "second.log", root=root)
            self.assertEqual(second["status"], "passed")
            second_file = root / second["expanded_argv"][-1] / "receipt.txt"
            self.assertNotEqual(first_file, second_file)
            self.assertEqual(first_file.read_bytes(), original)
            self.assertEqual(original.decode(), first["check_token"])
            self.assertEqual(second_file.read_text(), second["check_token"])
            self.assertEqual(check["argv"], argv, "Expansion must not mutate the check/cache template")
            self.assertEqual(h.input_digest(check, [], {}), digest)

    def test_argv_without_placeholder_keeps_other_braces_literal(self):
        with tempfile.TemporaryDirectory() as folder:
            source = "import json,sys; print(json.dumps(sys.argv[1:])); print('COMPLETE')"
            argv = ["python3", "-c", source, "{literal}", "nested {other:{braces}}"]
            check = {"argv": argv.copy(), "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
            log = Path(folder) / "literal.log"
            result = h.run_check(check, log)
            self.assertEqual(result["status"], "passed")
            self.assertEqual(result["expanded_argv"], [sys.executable, *argv[1:]])
            self.assertEqual(json.loads(log.read_text().splitlines()[0]), argv[3:])
            self.assertEqual(check["argv"], argv)

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

    def test_normal_completion_stops_reparented_engine_session(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / "escaped_after_success"
            child = f"import time; from pathlib import Path; time.sleep(0.5); Path({str(marker)!r}).touch()"
            parent = f"import subprocess, sys; subprocess.Popen([sys.executable, '-c', {child!r}], start_new_session=True); print('COMPLETE')"
            self.assertEqual(self.execute(parent)['status'], 'passed')
            time.sleep(0.6)
            self.assertFalse(marker.exists(), "Normal completion must reclaim separate engine sessions")

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
                    "artifact_directory": str(artifacts), "artifact_fingerprint": {}}
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

    def test_cache_rejects_changed_added_deleted_and_linked_artifacts(self):
        import json, hashlib
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); artifacts = root / "artifacts"; artifacts.mkdir()
            output = artifacts / "receipt.json"; output.write_text("original")
            item = {"log": "COMPLETE\n", "log_sha256": hashlib.sha256(b"COMPLETE\n").hexdigest(),
                    "result": {"status": "passed", "exit_code": 0}, "commit": "a" * 40,
                    "artifact_directory": str(artifacts), "artifact_fingerprint": h.artifact_fingerprint(artifacts)}
            cache = root / "cache.json"; cache.write_text(json.dumps(item)); log = root / "check.log"
            check = {"success_pattern": "^COMPLETE$"}
            self.assertTrue(h.cached_result(check, cache, log)["reused"])
            self.assertIsNone(h.cached_result(check, cache, log, expected_digest="different-inputs"))
            item["input_digest"]="original-inputs"; cache.write_text(json.dumps(item))
            self.assertTrue(h.cached_result(check, cache, log, expected_digest="original-inputs")["reused"])
            self.assertIsNone(h.cached_result(check, cache, log, expected_digest="different-inputs"))
            output.write_text("changed"); self.assertIsNone(h.cached_result(check, cache, log))
            output.write_text("original"); extra = artifacts / "extra"; extra.touch()
            self.assertIsNone(h.cached_result(check, cache, log)); extra.unlink()
            output.unlink(); self.assertIsNone(h.cached_result(check, cache, log))
            output.symlink_to(cache); self.assertIsNone(h.cached_result(check, cache, log))
            output.unlink(); output.write_text("original")
            del item["artifact_fingerprint"]; cache.write_text(json.dumps(item))
            self.assertIsNone(h.cached_result(check, cache, log), "Legacy directory-only cache must miss")

    def test_default_execution_archives_and_binds_real_generated_outputs(self):
        # Real subprocess/files exercise the default lane; no model or art claim.
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            def git(*args):
                return subprocess.run(["git",*args],cwd=root,check=True,capture_output=True)
            git("init","-q");git("config","user.email","proof@example.invalid");git("config","user.name","Proof")
            (root/".gitignore").write_text("build/\n");(root/"input").write_text("original")
            git("add",".");git("commit","-qm","test proof source")
            check={"argv":["python3","-c","from pathlib import Path; p=Path('build/verification/native/receipt.json'); p.parent.mkdir(parents=True,exist_ok=True); p.write_text('real subprocess output'); print('COMPLETE')"],
                   "timeout_seconds":5,"success_pattern":"^COMPLETE$","cacheable":True,"inputs":["input"]}
            with patch.object(h,"ROOT",root),patch.object(h,"toolchain_identity",return_value={}):
                def execute(label):
                    folder=root/"build/verification/harness"/label;folder.mkdir(parents=True)
                    return h.execute_checks({"checks":{"proof":check}},["proof"],folder,reuse=True)[0]
                first=execute("first");self.assertFalse(first["reused"])
                artifacts=Path(first["artifact_directory"])
                self.assertEqual((artifacts/"build/verification/native/receipt.json").read_text(),"real subprocess output")
                self.assertTrue((artifacts/"check.log").is_file())
                self.assertFalse((artifacts/"build/verification/harness").exists())
                self.assertTrue(execute("same")["reused"])
                product=root/"build/verification/native/receipt.json"
                product.write_text("corrupt");self.assertFalse(execute("corrupt")["reused"])
                self.assertTrue(execute("repaired")["reused"])
                product.unlink();self.assertFalse(execute("deleted")["reused"])
                (root/"input").write_text("new dependency")
                self.assertFalse(execute("changed-input")["reused"])
                product.write_text("corrupt after unchanged-output rebuild")
                self.assertFalse(execute("changed-input-corrupt-output")["reused"])

    def test_artifact_paths_reject_ancestor_symlink_and_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/"repo";root.mkdir();(root/"build").mkdir()
            outside=Path(temporary)/"external";outside.mkdir()
            (outside/"ecology").mkdir();(outside/"ecology/private.json").write_text("must not collect external bytes")
            (root/"build/link").symlink_to(outside,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,"Linked verification directory"):
                h.verification_outputs(root,root/"build/control",["build/link/ecology"])
            for path in (str(outside),"build/../external","assets"):
                with self.subTest(path=path),self.assertRaises(ValueError):
                    h.verification_outputs(root,root/"build/control",[path])

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


    def test_isolation_capacity_fails_before_clone_and_clone_errors_are_preserved(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'repo'; root.mkdir()
            subprocess.run(['git', 'init', '-q'], cwd=root, check=True)
            (root/'.gitignore').write_text('build/\n')
            (root/'source.txt').write_text('actual source bytes')
            folder=root/'build/report';folder.mkdir(parents=True)
            check={'argv':['python3','-c',"print('COMPLETE')"], 'timeout_seconds':5, 'success_pattern':'COMPLETE'}
            with patch.object(h,'ROOT',root), patch.object(h,'toolchain_identity',return_value={}), patch.object(h.shutil,'disk_usage',return_value=SimpleNamespace(free=0)), patch.object(h,'isolated_workspace') as clone:
                with self.assertRaisesRegex(RuntimeError,'no lane launched'):
                    h.execute_checks({'checks':{'a':check}}, ['a'], folder, jobs=2)
                clone.assert_not_called()
            diagnostic=folder/'clone.log'
            failure=subprocess.CalledProcessError(128,['git','clone'],stderr=b'actual clone diagnostic retained')
            with patch.object(h,'ROOT',root), patch.object(h.subprocess,'run',side_effect=failure):
                with self.assertRaisesRegex(RuntimeError,'actual clone diagnostic retained'):
                    h.isolated_workspace(root/'lane',[],setup_log=diagnostic)
            self.assertEqual(diagnostic.read_bytes(),b'actual clone diagnostic retained')

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
                custom = {**check, "artifact_paths": ["build/production_repair/ecology"],
                          "argv": ["python3", "-c", "from pathlib import Path; p=Path('build/production_repair/ecology/actual/report.json'); p.parent.mkdir(parents=True,exist_ok=True); p.write_text('original native-like bytes'); print('COMPLETE')"]}
                result = h.execute_checks({"checks":{"custom":custom}}, ['custom'], folder, jobs=2)
                preserved=Path(result[0]['artifact_directory'])/'build/production_repair/ecology/actual/report.json'
                self.assertEqual(preserved.read_text(),'original native-like bytes','Isolated production outputs must survive lane cleanup')
                self.assertFalse((root/'build/production_repair/ecology/actual/report.json').exists())
                # Nonzero exit cannot be concealed by a success marker in another lane.
                fail = {**check, "argv": ["python3", "-c", "print('COMPLETE'); raise SystemExit(4)"]}
                result = h.execute_checks({"checks": {"good": check, "bad": fail}}, ['good', 'bad'], folder, jobs=2)
                self.assertEqual(next(r['status'] for r in result if r['id']=='bad'), 'failed')


class SparseIsolationTests(unittest.TestCase):
    """Real sparse Git sources: cold blobs must never be checked out per lane."""
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "source"
        self.root.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "sparse-isolation@example.invalid")
        self.git("config", "user.name", "Sparse isolation test")
        (self.root / "src").mkdir()
        (self.root / "tools").mkdir()
        (self.root / "docs/evidence").mkdir(parents=True)
        (self.root / ".gitignore").write_text("build/\n.godot/\n")
        (self.root / ".gitattributes").write_text("docs/evidence/cold.bin filter=isolation-tripwire\n")
        for name in ("input.txt", "deleted.txt", "staged_deleted.txt"):
            (self.root / "src" / name).write_text("baseline")
        self.cold = self.root / "docs/evidence/cold.bin"
        self.cold.write_bytes(os.urandom(4 * 1024 * 1024))
        self.git("add", ".")
        self.git("commit", "-qm", "Real source and unrelated cold evidence")
        self.cold_blob = self.git("rev-parse", "HEAD:docs/evidence/cold.bin").strip()
        self.toolchain = self.base / "toolchain"
        (self.toolchain / "user-data/godot/export_templates").mkdir(parents=True)

    def git(self, *args, root=None, data=None):
        return subprocess.check_output(["git", "-C", str(root or self.root), *args], input=data, text=True)

    def sparse(self, cone=False):
        if cone:
            self.git("sparse-checkout", "init", "--cone", "--sparse-index")
            self.git("sparse-checkout", "set", "src", "tools")
        else:
            self.git("sparse-checkout", "init", "--no-cone")
            self.git("sparse-checkout", "set", "--no-cone", "--stdin", data="/*\n!/docs/evidence/\n")
        self.assertFalse(self.cold.exists())

    def dirty_source(self):
        (self.root / "src/input.txt").write_text("staged bytes")
        self.git("add", "src/input.txt")
        (self.root / "src/input.txt").write_text("working bytes")
        (self.root / "src/deleted.txt").unlink()
        self.git("rm", "-q", "src/staged_deleted.txt")
        (self.root / "src/staged_new.txt").write_text("new staged bytes")
        self.git("add", "src/staged_new.txt")
        (self.root / "src/untracked.txt").write_text("new untracked bytes")
        (self.root / "src/intent.txt").write_text("intent to add bytes")
        self.git("add", "-N", "src/intent.txt")
        (self.root / ".git/info/exclude").write_text("local-cache/\n")
        external = self.base / "external-excludes"
        external.write_text("external-cache/\n")
        self.git("config", "core.excludesFile", str(external))
        for name in ("local-cache", "external-cache"):
            (self.root / name).mkdir()
            (self.root / name / "ignored.txt").write_text("must not enter source")
        (self.root / ".godot/imported").mkdir(parents=True)
        (self.root / ".godot/imported/cache.txt").write_text("independent import seed")

    def test_sparse_index_stage_flags_ignores_and_import_data_stay_independent(self):
        self.sparse()
        self.dirty_source()
        original_index = self.git("ls-files", "--stage", "-z")
        original_flags = self.git("ls-files", "-v", "-z")
        with patch.object(h, "ROOT", self.root), patch.dict(os.environ, GUNMAN_TOOLCHAIN_ROOT=str(self.toolchain)):
            files = h.source_files()
            before = h.input_digest({"argv": []}, files, {})
            one, two = self.base / "one", self.base / "two"
            env1 = h.isolated_workspace(one, files)
            env2 = h.isolated_workspace(two, files)
            for lane in (one, two):
                self.assertEqual(self.git("ls-files", "--stage", "-z", root=lane), original_index)
                self.assertEqual(self.git("ls-files", "-v", "-z", root=lane), original_flags)
                self.assertEqual(self.git("show", ":src/input.txt", root=lane), "staged bytes")
                self.assertEqual((lane / "src/input.txt").read_text(), "working bytes")
                self.assertFalse((lane / "src/deleted.txt").exists())
                self.assertFalse((lane / "src/staged_deleted.txt").exists())
                self.assertFalse((lane / "docs/evidence/cold.bin").exists())
                self.assertFalse((lane / "local-cache/ignored.txt").exists())
                self.assertFalse((lane / "external-cache/ignored.txt").exists())
                self.assertEqual(self.git("check-ignore", "local-cache/new.txt", root=lane).strip(), "local-cache/new.txt")
                self.assertEqual(self.git("check-ignore", "external-cache/new.txt", root=lane).strip(), "external-cache/new.txt")
                self.assertEqual(self.git("config", "--get", "core.sparseCheckout", root=lane).strip(), "true")
                self.assertEqual((lane / ".git/info/sparse-checkout").read_bytes(), (self.root / ".git/info/sparse-checkout").read_bytes())
                self.assertEqual(h.input_digest({"argv": []}, h.source_files(lane), {}, root=lane), before)
                self.assertEqual(self.git("status", "--porcelain=v1", "--untracked-files=all", "-z", root=lane),
                                 self.git("status", "--porcelain=v1", "--untracked-files=all", "-z"))
            self.assertNotEqual(env1["GUNMAN_DATA_HOME"], env2["GUNMAN_DATA_HOME"])
            self.assertNotEqual(env1["XDG_CONFIG_HOME"], env2["XDG_CONFIG_HOME"])
            self.assertNotEqual(env1["XDG_CACHE_HOME"], env2["XDG_CACHE_HOME"])
            self.assertTrue((Path(env1["GUNMAN_DATA_HOME"]) / "godot/export_templates").is_symlink())
            (one / ".godot/imported/cache.txt").write_text("lane one import")
            (Path(env1["GUNMAN_DATA_HOME"]) / "session.txt").write_text("lane one save")
            self.assertEqual((two / ".godot/imported/cache.txt").read_text(), "independent import seed")
            self.assertEqual((self.root / ".godot/imported/cache.txt").read_text(), "independent import seed")
            self.assertFalse((Path(env2["GUNMAN_DATA_HOME"]) / "session.txt").exists())
            lane_excludes = Path(self.git("config", "--path", "--get", "core.excludesFile", root=one).strip())
            lane_excludes.write_text("lane-one-only/\n")
            self.assertEqual(self.git("check-ignore", "external-cache/new.txt", root=two).strip(), "external-cache/new.txt")
            self.assertEqual((self.base / "external-excludes").read_text(), "external-cache/\n")
            self.assertEqual(h.input_digest({"argv": []}, h.source_files(), {}), before)

    def test_two_real_lanes_do_not_read_cold_evidence_and_keep_output_proof(self):
        import shlex
        self.sparse()
        marker = self.base / "cold-smudge-was-run"
        smudge = shlex.join([sys.executable, "-c", "import sys; from pathlib import Path; data=sys.stdin.buffer.read(); Path(" + repr(str(marker)) + ").write_text('cold checkout'); sys.stdout.buffer.write(data)"])
        git_environment = {"GUNMAN_TOOLCHAIN_ROOT": str(self.toolchain), "GIT_CONFIG_COUNT": "2",
                           "GIT_CONFIG_KEY_0": "filter.isolation-tripwire.smudge", "GIT_CONFIG_VALUE_0": smudge,
                           "GIT_CONFIG_KEY_1": "filter.isolation-tripwire.required", "GIT_CONFIG_VALUE_1": "true"}
        source = ("import os,json; from pathlib import Path; root=Path.cwd(); "
                  "assert not (root/'docs/evidence/cold.bin').exists(); "
                  "data=Path(os.environ['GUNMAN_DATA_HOME']); (data/'session.txt').write_text('actual lane data'); "
                  "proof=root/'build/verification/lane.json'; proof.parent.mkdir(parents=True,exist_ok=True); "
                  "proof.write_text(json.dumps({'root':str(root),'data':str(data),'cold_materialized':False})); print('COMPLETE')")
        check = {"argv": ["python3", "-c", source], "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
        folder = self.root / "build/report"
        folder.mkdir(parents=True)
        started = time.monotonic()
        with patch.object(h, "ROOT", self.root), patch.object(h, "toolchain_identity", return_value={}), patch.dict(os.environ, git_environment):
            results = h.execute_checks({"checks": {"a": check, "b": check}}, ["a", "b"], folder, jobs=2)
            lane_seconds = time.monotonic() - started
            self.assertEqual([item["status"] for item in results], ["passed", "passed"])
            self.assertFalse(marker.exists(), "Even a transient cold checkout would invoke the real smudge tripwire")
            proofs = [json.loads((Path(item["artifact_directory"]) / "build/verification/lane.json").read_text()) for item in results]
            self.assertNotEqual(proofs[0]["root"], proofs[1]["root"])
            self.assertNotEqual(proofs[0]["data"], proofs[1]["data"])
            self.assertTrue(all(not proof["cold_materialized"] for proof in proofs))
            self.assertFalse((self.root / "build/verification/lane.json").exists())
            # Positive control: the previous eager clone really reads this cold
            # object and trips the detector. No implementation-argument mock.
            control = self.base / "eager-control"
            control_started = time.monotonic()
            subprocess.run(["git", "clone", "--quiet", "--shared", "--no-hardlinks", str(self.root), str(control)], check=True, capture_output=True)
            control_seconds = time.monotonic() - control_started
            self.assertTrue(marker.exists())
            self.assertEqual((control / "docs/evidence/cold.bin").stat().st_size, 4 * 1024 * 1024)
        print(f"SPARSE ISOLATION: actual two-lane checks {lane_seconds:.3f}s; cold evidence 0 bytes/lane; eager checkout control {control_seconds:.3f}s, 4194304 bytes")

    def test_cone_sparse_index_works_with_an_unavailable_cold_blob(self):
        self.sparse(cone=True)
        # A normal checkout fails here; cloning the source must not ask for an
        # unrelated absent object, as a partial clone would need a network fetch.
        object_path = self.root / ".git/objects" / self.cold_blob[:2] / self.cold_blob[2:]
        self.assertTrue(object_path.is_file())
        object_path.unlink()
        before_flags = self.git("ls-files", "--sparse", "-v", "-z")
        with patch.object(h, "ROOT", self.root), patch.dict(os.environ, GUNMAN_TOOLCHAIN_ROOT=str(self.toolchain)):
            files = h.source_files()
            before = h.input_digest({"argv": []}, files, {})
            lane = self.base / "missing-cold-object"
            h.isolated_workspace(lane, files)
            self.assertEqual(self.git("ls-files", "--sparse", "-v", "-z", root=lane), before_flags)
            self.assertEqual(self.git("config", "--get", "index.sparse", root=lane).strip(), "true")
            self.assertFalse((lane / "docs/evidence/cold.bin").exists())
            self.assertEqual(h.input_digest({"argv": []}, h.source_files(lane), {}, root=lane), before)

    def test_required_file_materialized_outside_sparse_patterns_is_copied(self):
        self.sparse()
        # Input hydration may read a selected evidence file directly without
        # widening the parent sparse pattern or clearing its skip-worktree bit.
        payload = subprocess.check_output(["git", "-C", str(self.root), "cat-file", "blob", self.cold_blob])
        self.cold.parent.mkdir(parents=True, exist_ok=True)
        self.cold.write_bytes(payload)
        self.git("update-index", "--skip-worktree", "docs/evidence/cold.bin")
        # Git normally clears skip-worktree in memory when it discovers a
        # materialized out-of-pattern file. Inspect the retained index flag
        # without that automatic sparse adjustment; do not change its rules.
        self.assertTrue(self.git("-c", "core.sparseCheckout=false", "ls-files", "-v", "docs/evidence/cold.bin").startswith("S "))
        with patch.object(h, "ROOT", self.root), patch.dict(os.environ, GUNMAN_TOOLCHAIN_ROOT=str(self.toolchain)):
            files = h.source_files()
            before = h.input_digest({"argv": []}, files, {})
            lane = self.base / "hydrated-lane"
            h.isolated_workspace(lane, files)
            self.assertEqual((lane / "docs/evidence/cold.bin").read_bytes(), payload)
            self.assertTrue(self.git("-c", "core.sparseCheckout=false", "ls-files", "-v", "docs/evidence/cold.bin", root=lane).startswith("S "))
            self.assertEqual(h.input_digest({"argv": []}, h.source_files(lane), {}, root=lane), before)

    def test_linked_worktree_split_index_preserves_its_own_stage(self):
        worktree = self.base / "linked-workline"
        self.git("worktree", "add", "-q", "-b", "workline", str(worktree))
        (worktree / "src/input.txt").write_text("linked staged")
        self.git("add", "src/input.txt", root=worktree)
        (worktree / "src/input.txt").write_text("linked working")
        self.git("update-index", "--split-index", root=worktree)
        with patch.object(h, "ROOT", worktree), patch.dict(os.environ, GUNMAN_TOOLCHAIN_ROOT=str(self.toolchain)):
            lane = self.base / "linked-lane"
            h.isolated_workspace(lane, h.source_files())
        self.assertEqual(self.git("show", ":src/input.txt", root=lane), "linked staged")
        self.assertEqual((lane / "src/input.txt").read_text(), "linked working")
        self.assertEqual(self.git("ls-files", "--stage", "-z", root=lane), self.git("ls-files", "--stage", "-z", root=worktree))
        self.assertEqual((self.root / "src/input.txt").read_text(), "baseline")

    def test_real_partial_promisor_with_unavailable_origin_never_runs_pack_transport(self):
        server = self.root
        self.git("config", "uploadpack.allowFilter", "true")
        partial = self.base / "partial-source"
        fixture_env = {**os.environ, "GIT_NO_LAZY_FETCH": "0"}
        subprocess.run(["git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", server.as_uri(), str(partial)],
                       check=True, capture_output=True, env=fixture_env)
        self.assertEqual(self.git("config", "--get", "remote.origin.promisor", root=partial).strip(), "true")
        self.assertTrue(list((partial / ".git/objects/pack").glob("*.promisor")))
        subprocess.run(["git", "-C", str(partial), "sparse-checkout", "init", "--no-cone"], check=True, capture_output=True, env=fixture_env)
        subprocess.run(["git", "-C", str(partial), "sparse-checkout", "set", "--no-cone", "--stdin"],
                       input="/*\n!/docs/evidence/\n", text=True, check=True, capture_output=True, env=fixture_env)
        subprocess.run(["git", "-C", str(partial), "reset", "--hard", "HEAD"], check=True, capture_output=True, env=fixture_env)
        self.assertFalse((partial / "docs/evidence/cold.bin").exists())
        self.git("remote", "set-url", "origin", (self.base / "unavailable-origin").as_uri(), root=partial)
        unavailable_env = {**os.environ, "GIT_NO_LAZY_FETCH": "1"}
        probe = subprocess.run(["git", "-C", str(partial), "cat-file", "--batch-check"],
                               input=self.cold_blob + "\n", text=True, check=True, capture_output=True, env=unavailable_env)
        self.assertEqual(probe.stdout.strip(), self.cold_blob + " missing", "This must be a genuinely unfetched promised blob")
        # Exercise the actual transport fallback: --no-checkout does not prevent
        # upload-pack. Some Git versions allow local optimization for file://
        # promisors, so explicitly choose the fallback observed in the real
        # HTTPS-backed root rather than assuming every promisor disables local.
        control = subprocess.run(["git", "clone", "--quiet", "--shared", "--no-hardlinks", "--no-checkout", "--no-local", str(partial), str(self.base / "old-partial-control")],
                                 capture_output=True, env=unavailable_env)
        self.assertNotEqual(control.returncode, 0)
        self.assertIn(b"upload-pack", control.stderr)
        self.assertIn(self.cold_blob.encode(), control.stderr)
        (partial / "src/input.txt").write_text("partial staged bytes")
        self.git("add", "src/input.txt", root=partial)
        (partial / "src/input.txt").write_text("partial working bytes")
        (partial / "src/deleted.txt").unlink()
        original_stage = self.git("ls-files", "--stage", "-z", root=partial)
        original_flags = self.git("ls-files", "-v", "-z", root=partial)
        packs_before = {path.name: path.stat().st_size for path in (partial / ".git/objects/pack").iterdir()}
        trace = self.base / "partial-setup.trace"
        source = ("import json,os; from pathlib import Path; "
                  "assert not Path('docs/evidence/cold.bin').exists(); "
                  "assert Path('src/input.txt').read_text()=='partial working bytes'; "
                  "assert not Path('src/deleted.txt').exists(); "
                  "p=Path('build/verification/partial.json'); p.parent.mkdir(parents=True,exist_ok=True); "
                  "p.write_text(json.dumps({'cwd':str(Path.cwd()),'data':os.environ['GUNMAN_DATA_HOME']})); print('COMPLETE')")
        check = {"argv": ["python3", "-c", source], "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
        folder = partial / "build/report"
        folder.mkdir(parents=True)
        with patch.object(h, "ROOT", partial), patch.object(h, "toolchain_identity", return_value={}), \
                patch.dict(os.environ, {"GUNMAN_TOOLCHAIN_ROOT": str(self.toolchain), "GIT_NO_LAZY_FETCH": "1", "GIT_TRACE": str(trace)}):
            files = h.source_files()
            fingerprint = h.input_digest({"argv": []}, files, {})
            lane = self.base / "partial-setup-lane"
            h.isolated_workspace(lane, files)
            self.assertEqual(self.git("rev-parse", "HEAD", root=lane), self.git("rev-parse", "HEAD", root=partial))
            self.assertEqual(self.git("ls-files", "--stage", "-z", root=lane), original_stage)
            self.assertEqual(self.git("ls-files", "-v", "-z", root=lane), original_flags)
            self.assertEqual(self.git("show", ":src/input.txt", root=lane), "partial staged bytes")
            self.assertEqual(self.git("config", "--get", "remote.origin.promisor", root=lane).strip(), "true")
            self.assertEqual(h.input_digest({"argv": []}, h.source_files(lane), {}, root=lane), fingerprint)
            results = h.execute_checks({"checks": {"a": check, "b": check}}, ["a", "b"], folder, jobs=2)
            self.assertEqual([item["status"] for item in results], ["passed", "passed"])
            self.assertEqual(h.input_digest({"argv": []}, h.source_files(), {}), fingerprint)
        self.assertEqual({path.name: path.stat().st_size for path in (partial / ".git/objects/pack").iterdir()}, packs_before)
        self.assertFalse(list((lane / ".git/objects/pack").iterdir()))
        self.assertFalse((lane / "docs/evidence/cold.bin").exists())
        events = trace.read_text()
        for forbidden in ("upload-pack", "pack-objects", "index-pack", "built-in: git fetch", "built-in: git clone"):
            self.assertNotIn(forbidden, events, "Isolation metadata setup must not perform object transport")
        print("PROMISOR ISOLATION: genuine filtered source, origin unavailable, transport fallback fails, metadata setup and two real lanes pass without pack transport")


class SourceHashCacheTests(unittest.TestCase):
    """Real file mutations must invalidate the execution-local source optimization."""
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / "input"
        self.path.write_bytes(b"original")

    def repository(self):
        for args in (("init", "-q"), ("config", "user.email", "hash@example.invalid"),
                     ("config", "user.name", "Hash test")):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)
        (self.root / ".gitignore").write_text("build/\n")
        subprocess.run(["git", "add", "."], cwd=self.root, check=True, capture_output=True)
        subprocess.run(["git", "commit", "-qm", "hash fixture"], cwd=self.root, check=True, capture_output=True)

    def test_unchanged_bytes_are_read_once_with_identical_persistent_digest(self):
        cache = h.SourceHashCache()
        check = {"argv": ["run"], "inputs": ["input", "missing"]}
        files = ["input", "missing"]
        identity = {"engine": "same"}
        # This is the original persisted payload, without stat/cache metadata.
        payload = {"inputs": [("input", hashlib.sha256(b"original").hexdigest()),
                              ("missing", "deleted")], "check": check, "toolchain": identity}
        expected = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
        with patch.object(h.hashlib, "file_digest", wraps=hashlib.file_digest) as read:
            for unused in range(3):
                self.assertEqual(h.input_digest(check, files, identity, root=self.root, hash_cache=cache), expected)
            self.assertEqual(read.call_count, 1 if sys.platform.startswith("linux") else 3)
        self.assertEqual(h.input_digest(check, files, identity, root=self.root), expected)

    def test_non_linux_platforms_always_read_full_source_bytes(self):
        for platform in ("win32", "darwin"):
            with self.subTest(platform=platform), patch.object(h.sys, "platform", platform):
                cache = h.SourceHashCache()
                with patch.object(h.hashlib, "file_digest", wraps=hashlib.file_digest) as read:
                    first = cache.digest(self.path)
                    self.assertEqual(cache.digest(self.path), first)
                    self.assertEqual(read.call_count, 2, "Creation-time metadata cannot authorize cached bytes")

    def test_equal_length_edit_with_restored_mtime_is_rehashed(self):
        cache = h.SourceHashCache()
        before = self.path.stat()
        first = cache.digest(self.path)
        self.path.write_bytes(b"mutated!")
        os.utime(self.path, ns=(before.st_atime_ns, before.st_mtime_ns))
        after = self.path.stat()
        self.assertEqual((before.st_ino, before.st_size, before.st_mtime_ns),
                         (after.st_ino, after.st_size, after.st_mtime_ns))
        if sys.platform.startswith("linux"):
            self.assertNotEqual(before.st_ctime_ns, after.st_ctime_ns)
        self.assertNotEqual(cache.digest(self.path), first)
        self.assertEqual(cache.digest(self.path), hashlib.sha256(b"mutated!").hexdigest())

    def test_atomic_replacement_with_restored_size_and_mtime_is_rehashed(self):
        cache = h.SourceHashCache()
        first = cache.digest(self.path)
        before = self.path.stat()
        replacement = self.root / "replacement"
        replacement.write_bytes(b"mutated!")
        os.utime(replacement, ns=(before.st_atime_ns, before.st_mtime_ns))
        replacement.replace(self.path)
        self.assertEqual(self.path.stat().st_mtime_ns, before.st_mtime_ns)
        self.assertNotEqual(self.path.stat().st_ino, before.st_ino)
        self.assertNotEqual(cache.digest(self.path), first)

    def test_full_enumeration_detects_new_deleted_and_recreated_sources(self):
        self.repository()
        cache = h.SourceHashCache()
        with patch.object(h, "ROOT", self.root):
            before = h.source_inventory(hash_cache=cache)
            extra = self.root / "new.gd"
            extra.write_text("extends Node")
            added = h.source_inventory(hash_cache=cache)
            self.assertEqual(set(added) - set(before), {"new.gd"})
            self.path.unlink()
            removed = h.source_inventory(hash_cache=cache)
            self.assertEqual(removed["input"], "deleted")
            extra.unlink()
            self.assertNotIn("new.gd", h.source_inventory(hash_cache=cache))
            self.path.write_bytes(b"mutated!")
            self.assertNotEqual(h.source_inventory(hash_cache=cache)["input"], before["input"])

    def test_distinct_roots_and_retargeted_links_do_not_share_stale_bytes(self):
        cache = h.SourceHashCache()
        first = cache.digest(self.path)
        other = self.root / "other"
        other.mkdir()
        second = other / "input"
        second.write_bytes(b"mutated!")
        before = self.path.stat()
        os.utime(second, ns=(before.st_atime_ns, before.st_mtime_ns))
        self.assertNotEqual(cache.digest(second), first)
        link = self.root / "linked"
        link.symlink_to(self.path)
        self.assertEqual(cache.digest(link), first)
        link.unlink(); link.symlink_to(second)
        self.assertEqual(cache.digest(link), hashlib.sha256(b"mutated!").hexdigest())

    def test_real_mutation_during_read_is_rejected_and_not_cached(self):
        cache = h.SourceHashCache()
        before = self.path.stat()
        original = hashlib.file_digest
        def mutate(source, algorithm):
            result = original(source, algorithm)
            self.path.write_bytes(b"mutated!")
            os.utime(self.path, ns=(before.st_atime_ns, before.st_mtime_ns))
            return result
        with patch.object(h.hashlib, "file_digest", side_effect=mutate):
            with self.assertRaisesRegex(RuntimeError, "Source changed while hashing"):
                cache.digest(self.path)
        self.assertEqual(cache.digest(self.path), hashlib.sha256(b"mutated!").hexdigest())

    def test_real_path_swap_between_stat_and_open_is_rejected(self):
        cache = h.SourceHashCache()
        replacement = self.root / "replacement"
        replacement.write_bytes(b"mutated!")
        original = Path.open
        def swap(path, *args, **kwargs):
            if path == self.path:
                replacement.replace(self.path)
            return original(path, *args, **kwargs)
        with patch.object(Path, "open", new=swap):
            with self.assertRaisesRegex(RuntimeError, "Source changed while hashing"):
                cache.digest(self.path)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Stat reuse requires Linux change-time")
    def test_cache_hit_still_rechecks_metadata_after_lookup(self):
        cache = h.SourceHashCache()
        cache.digest(self.path)
        original = Path.stat
        calls = []
        def mutate(path, *args, **kwargs):
            if path == self.path:
                calls.append(path)
                if len(calls) == 2:
                    self.path.write_bytes(b"mutated!")
            return original(path, *args, **kwargs)
        with patch.object(Path, "stat", new=mutate), patch.object(h.hashlib, "file_digest") as read:
            with self.assertRaisesRegex(RuntimeError, "Source changed while hashing"):
                cache.digest(self.path)
            read.assert_not_called()

    def test_guards_enumerate_and_reuse_bytes_until_fresh_final_guard(self):
        self.repository()
        check = {"argv": ["python3", "-c", "print('COMPLETE')"],
                 "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
        data = {"checks": {"a": check, "b": check, "c": {**check, "serial": True}}}
        original = hashlib.file_digest
        reads = []
        def counted(source, algorithm):
            reads.append(Path(source.name))
            return original(source, algorithm)
        with patch.object(h, "ROOT", self.root), patch.object(h, "toolchain_identity", return_value={}), \
                patch.object(h.hashlib, "file_digest", side_effect=counted), \
                patch.object(h, "source_files", wraps=h.source_files) as enumerate_files:
            for run in ("first", "second"):
                folder = self.root / "build" / run
                folder.mkdir(parents=True)
                results = h.execute_checks(data, ["a", "b", "c"], folder)
                self.assertEqual([r["status"] for r in results], ["passed"] * 3)
            self.assertEqual(reads.count(self.path), 4 if sys.platform.startswith("linux") else 16,
                             "Separate executions read fresh source bytes at both start and final approval")
            self.assertEqual(enumerate_files.call_count, 16, "Initial, before/after every check and final guards all enumerate")

    def test_real_check_cannot_hide_equal_size_mtime_edit_or_atomic_replacement(self):
        self.repository()
        prefix = "import os; from pathlib import Path; p=Path('input'); old=p.stat(); "
        mutations = ["p.write_bytes(b'mutated!'); os.utime(p,ns=(old.st_atime_ns,old.st_mtime_ns)); ",
                     "q=Path('build/replacement'); q.write_bytes(b'mutated!'); os.utime(q,ns=(old.st_atime_ns,old.st_mtime_ns)); q.replace(p); "]
        for index, mutation in enumerate(mutations):
            with self.subTest(mutation=index):
                self.path.write_bytes(b"original")
                folder = self.root / "build" / str(index)
                folder.mkdir(parents=True)
                bad = {"argv": ["python3", "-c", prefix + mutation + "print('COMPLETE')"],
                       "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
                later = {**bad, "argv": ["python3", "-c", "from pathlib import Path; Path('build/should-not-run').touch(); print('COMPLETE')"]}
                with patch.object(h, "ROOT", self.root), patch.object(h, "toolchain_identity", return_value={}):
                    with self.assertRaisesRegex(RuntimeError, "Source changed during validation"):
                        h.execute_checks({"checks": {"bad": bad, "later": later}}, ["bad", "later"], folder)
                self.assertFalse((self.root / "build/should-not-run").exists())

    def test_fresh_final_guard_catches_real_write_hidden_from_stat_cache(self):
        self.repository()
        folder = self.root / "build" / "final-guard"
        folder.mkdir(parents=True)
        source = ("import os; from pathlib import Path; p=Path('input'); old=p.stat(); "
                  "p.write_bytes(b'mutated!'); os.utime(p,ns=(old.st_atime_ns,old.st_mtime_ns)); print('COMPLETE')")
        check = {"argv": ["python3", "-c", source], "timeout_seconds": 5, "success_pattern": "^COMPLETE$"}
        with patch.object(h, "ROOT", self.root), patch.object(h, "toolchain_identity", return_value={}), \
                patch.object(h.SourceHashCache, "_key", return_value=(0, 0, 0, 0, 0)):
            with self.assertRaisesRegex(RuntimeError, "Source changed during validation"):
                h.execute_checks({"checks": {"changed": check}}, ["changed"], folder)
        self.assertEqual(self.path.read_bytes(), b"mutated!", "Mutation is real; only metadata observation is mocked")


class CIWorkflowCoverageTests(unittest.TestCase):
    """Guard actual workflow/profile ownership, without a second check registry."""
    def test_one_main_execution_retains_complete_union_and_web_ownership(self):
        import re
        root = Path(__file__).resolve().parents[1]
        data = json.loads((root / "tools/harness/profiles.json").read_text())
        required = set().union(*(set(data["profiles"][name]) for name in ("gameplay", "art", "web", "docs")))
        self.assertEqual(set(data["profiles"]["full"]), required)
        source = (root / ".github/workflows/environment.yml").read_text()
        commands = re.findall(r"python3 tools/harness\.py ([^\n]+)", source)
        executions = [command for command in commands if "--verify-lanes" not in command]
        self.assertEqual(len(executions), 1, "Main must not rerun overlapping profiles in another job")
        self.assertRegex(executions[0], r"--profile full\b")
        self.assertIn("--release", executions[0]); self.assertIn("--lane", executions[0])
        self.assertIn("lane: [parallel, serial]", source)
        for name in ("web-build", "web-bundle"):
            self.assertTrue(data["checks"][name]["serial"])
        self.assertFalse(data["checks"]["web-cache"].get("serial", False))
        self.assertLess(data["profiles"]["full"].index("web-build"), data["profiles"]["full"].index("web-bundle"))
        self.assertIn("output_args+=(--bind-output web-bundle:build/web)", source)
        verifiers = [command for command in commands if "--verify-lanes" in command]
        self.assertEqual(len(verifiers), 2)
        for command in verifiers:
            self.assertIn("--profile full", command)
            self.assertIn("--bind-output web-bundle:build/web", command)
        web = source.split("  web:\n", 1)[1].split("  deploy_web:\n", 1)[0]
        self.assertIn("needs: [prepare, core]", web)
        self.assertIn("verify_delivery_metadata('build/web', commit)", web)
        self.assertIn("needs: [core, windows, web]", source)
        self.assertIn("needs: [deploy_web, web]", source)
        self.assertIn("workflow_dispatch:", source)
        self.assertIn("inputs.build_android", source)

    def test_docs_manual_entry_and_original_registered_prechecks_are_preserved(self):
        import re
        root = Path(__file__).resolve().parents[1]
        data = json.loads((root / "tools/harness/profiles.json").read_text())
        docs = (root / ".github/workflows/docs.yml").read_text()
        self.assertIn("  workflow_dispatch:", docs)
        self.assertNotRegex(docs, r"(?m)^  push:")
        self.assertIn("python3 tools/harness.py --profile docs", docs)
        self.assertLessEqual(set(data["profiles"]["docs"]), set(data["profiles"]["full"]))
        for filename in ("environment.yml", "production.yml"):
            source = (root / ".github/workflows" / filename).read_text()
            self.assertNotIn("python3 tools/test_frozen_assets.py", source)
            self.assertNotIn("python3 tests/test_cloud_delivery.py", source)
        for name in ("portable-frozen-assets", "cloud-delivery-tests"):
            self.assertIn(name, data["profiles"]["docs"])
        production = (root / ".github/workflows/production.yml").read_text()
        self.assertIn("--precheck-only", production)
        self.assertIn("--profile full --release --jobs 1 --lane", production)
        policy = json.loads((root / "config/production_impact.json").read_text())
        self.assertIn("plains-encounter-policy", [check["parent_check"] for check in policy["early_python_checks"]])


class HarnessLaneTests(unittest.TestCase):
    """Real tiny Python checks and Git sources; no native/profile approval."""
    def setUp(self):
        import copy
        self.copy = copy.deepcopy
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        def git(*args):
            return subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)
        self.git = git
        git("init", "-q"); git("config", "user.email", "proof@example.invalid"); git("config", "user.name", "Proof")
        (self.root / ".gitignore").write_text("build/\n")
        (self.root / "tests").mkdir(); (self.root / "tools/harness").mkdir(parents=True)
        (self.root / "assets/foundry").mkdir(parents=True)
        (self.root / "assets/foundry/prepared.json").write_text('{"basis":"original"}\n')
        for name in ("a", "b"):
            (self.root / f"tests/{name}.py").write_text(f"print('COMPLETE {name}')\n")
        self.data = {"schema_version": 1, "checks": {
            name: {"argv": ["python3", f"tests/{name}.py"], "timeout_seconds": 5,
                   "success_pattern": f"^COMPLETE {name}$", **({"serial": True} if name == "b" else {})}
            for name in ("a", "b")}, "profiles": {"gameplay": ["a", "b"], "art": ["a"]}}
        self.manifest = self.root / "tools/harness/profiles.json"
        self.manifest.write_text(json.dumps(self.data))
        git("add", "."); git("commit", "-qm", "SIMULATED harness source")
        # Real dirty prepared data must be present identically in both phases
        # and in the verifier, rather than being ignored as generated content.
        (self.root / "assets/foundry/prepared.json").write_text('{"basis":"prepared"}\n')
        self.identity = {"python": sys.version, "platform": sys.platform,
                         "godot": {"exit_code": 0, "version": "SIMULATED 4.7.2 identity; no engine"},
                         "node": {"exit_code": 0, "version": "SIMULATED node identity"}}
        self.addCleanup(patch.stopall)
        patch.object(h, "ROOT", self.root).start()
        patch.object(h, "MANIFEST", self.manifest).start()
        self.toolchain = patch.object(h, "toolchain_identity", return_value=self.identity).start()

    def cli(self, *args):
        with patch.object(sys, "argv", ["harness.py", *args]):
            return h.main()

    def phases(self):
        paths = []
        for lane in ("parallel", "serial"):
            self.assertEqual(self.cli("--profile", "gameplay", "--profile", "art", "--release", "--lane", lane), 0)
            paths.append(max((self.root / "build/verification/harness").glob("*/report.json"), key=lambda p: p.parent.name))
        return paths

    def verify(self, paths):
        return h.verify_lane_reports(self.data, ["gameplay", "art"], paths, h.git_metadata(), h.source_inventory())

    def output_phases(self):
        # Tiny real output producer; no Godot/export/runtime approval claim.
        (self.root / "tests/b.py").write_text(
            "from pathlib import Path\n"
            "p=Path('build/web');p.mkdir(parents=True)\n"
            "(p/'pack.pck').write_bytes(b'SIMULATED export bytes')\n"
            "(p/'build-info.json').write_text('{}')\n"
            "print('COMPLETE b')\n")
        paths = []
        for lane in ("parallel", "serial"):
            args = ["--profile", "gameplay", "--profile", "art", "--release", "--lane", lane]
            if lane == "serial": args += ["--bind-output", "b:build/web"]
            self.assertEqual(self.cli(*args), 0)
            paths.append(max((self.root / "build/verification/harness").glob("*/report.json"), key=lambda p: p.parent.name))
        return paths

    def verify_outputs(self, paths):
        return h.verify_lane_reports(self.data, ["gameplay", "art"], paths,
                                     h.git_metadata(), h.source_inventory(), {"build/web": "b"})

    def test_real_output_transfer_binds_complete_tree_without_reexecuting_checks(self):
        paths = self.output_phases()
        # Transfer actual bytes to a fresh directory rather than accepting a name.
        source = self.root / "build/web"
        held = self.root / "build/held-output"
        source.rename(held)
        import shutil
        shutil.copytree(held, source)
        with patch.object(h, "execute_checks", side_effect=AssertionError("No rerun on transfer")):
            self.assertEqual(self.cli("--verify-lanes", *map(str, paths), "--profile", "gameplay",
                                      "--profile", "art", "--bind-output", "b:build/web"), 0)
        output = self.verify_outputs(paths)["bound_outputs"]["build/web"]
        self.assertEqual(output["check"], "b")
        self.assertEqual(set(output["files"]), {"pack.pck", "build-info.json"})
        self.assertEqual(output["files"]["pack.pck"]["sha256"], hashlib.sha256(b"SIMULATED export bytes").hexdigest())

    def test_transfer_rejects_changed_missing_extra_and_linked_payloads(self):
        paths = self.output_phases()
        pack = self.root / "build/web/pack.pck"; original = pack.read_bytes()
        for change in ("changed", "missing", "extra", "linked", "empty", "special"):
            with self.subTest(change=change):
                extra = self.root / "build/web/unexpected"
                if change == "changed": pack.write_bytes(b"another export")
                elif change == "missing": pack.unlink()
                elif change == "extra": extra.write_bytes(b"unverified file")
                elif change == "linked":
                    pack.unlink(); pack.symlink_to(self.root / "tests/b.py")
                elif change == "empty":
                    pack.unlink(); (self.root / "build/web/build-info.json").unlink()
                elif change == "special": os.mkfifo(extra)
                try:
                    with self.assertRaises(ValueError): self.verify_outputs(paths)
                finally:
                    pack.unlink(missing_ok=True); pack.write_bytes(original)
                    extra.unlink(missing_ok=True)
                    (self.root / "build/web/build-info.json").write_text('{}')
        source = self.root / "build/web"; held = self.root / "build/held"
        source.rename(held); source.symlink_to(held, target_is_directory=True)
        with self.assertRaises(ValueError): self.verify_outputs(paths)

    def test_transfer_requires_explicit_exact_producer_and_fresh_complete_proof(self):
        paths = self.output_phases(); original = json.loads(paths[1].read_text())
        changes = [lambda r:r.pop("bound_outputs"),
                   lambda r:r["bound_outputs"]["build/web"].update(check="a"),
                   lambda r:r["bound_outputs"]["build/web"].update(files={}),
                   lambda r:r["bound_outputs"].update({"build/elsewhere": {}}),
                   lambda r:r.update(status="failed"),
                   lambda r:r["checks"][0].update(reused=True)]
        for mutation in changes:
            changed = self.copy(original); mutation(changed); paths[1].write_text(json.dumps(changed))
            with self.assertRaises(ValueError): self.verify_outputs(paths)
        paths[1].write_text(json.dumps(original))
        with self.assertRaises(ValueError): self.verify(paths)  # Cannot silently discard output custody.
        for values, lane in [(["missing:build/web"], "serial"), (["a:build/web"], "serial"),
                             (["b:/tmp/web"], "serial"), (["b:build/../web"], "serial"),
                             (["b:build"], "serial"), (["b:build/web", "b:build/web"], "serial"),
                             (["b:build/web", "b:build/web/nested"], "serial")]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                h.output_bindings(values, self.data, ["a", "b"], lane)
        with self.assertRaises(SystemExit): self.cli("--profile", "gameplay", "--bind-output", "b:build/web")

    def test_later_checks_cannot_rebind_changed_bytes_as_validated_output(self):
        (self.root / "tests/b.py").write_text(
            "from pathlib import Path\np=Path('build/web');p.mkdir(parents=True)\n"
            "(p/'pack.pck').write_bytes(b'checked bytes')\nprint('COMPLETE b')\n")
        (self.root / "tests/c.py").write_text(
            "from pathlib import Path\nPath('build/web/pack.pck').write_bytes(b'unchecked later bytes')\n"
            "print('COMPLETE c')\n")
        self.data["checks"]["c"] = {"argv": ["python3", "tests/c.py"], "timeout_seconds": 5,
                                    "success_pattern": "^COMPLETE c$", "serial": True}
        self.data["profiles"]["gameplay"].append("c")
        self.manifest.write_text(json.dumps(self.data))
        with self.assertRaisesRegex(RuntimeError, "changed after their validating check"):
            self.cli("--profile", "gameplay", "--release", "--lane", "serial", "--bind-output", "b:build/web")

    def test_output_change_during_full_proof_verification_fails(self):
        paths = self.output_phases()
        original = h.verify_lane_reports
        def mutate(*args, **kwargs):
            result = original(*args, **kwargs)
            (self.root / "build/web/pack.pck").write_bytes(b"changed during proof copying")
            return result
        with patch.object(h, "verify_lane_reports", side_effect=mutate):
            with self.assertRaisesRegex(RuntimeError, "outputs changed"):
                self.cli("--verify-lanes", *map(str, paths), "--profile", "gameplay", "--profile", "art",
                         "--bind-output", "b:build/web")

    def test_real_phases_and_merge_cover_complete_dirty_prepared_source(self):
        paths = self.phases()
        self.assertEqual([json.loads(p.read_text())["checks"][0]["id"] for p in paths], ["a", "b"])
        before_calls = self.toolchain.call_count
        with patch.object(h, "execute_checks", side_effect=AssertionError("Merge must not execute checks")):
            self.assertEqual(self.cli("--verify-lanes", *map(str, paths), "--profile", "gameplay", "--profile", "art"), 0)
        self.assertEqual(self.toolchain.call_count, before_calls, "Merge must not launch toolchain version probes")
        merged = json.loads(max((self.root / "build/verification/harness").glob("*/report.json"), key=lambda p:p.parent.name).read_text())
        self.assertFalse(merged["partial"]); self.assertEqual(merged["status"], "passed")
        self.assertEqual([x["id"] for x in merged["checks"]], ["a", "b"])
        self.assertEqual(merged["approval_scope"], "selected_profiles_technical")
        self.assertEqual(merged["device_acceptance"], "unverified")
        self.assertEqual(merged["fun_acceptance"], "unverified")
        self.assertIn("assets/foundry/prepared.json", merged["source_files"])
        self.assertIn("assets/foundry/prepared.json", merged["working_files"])
        merged_path = max((self.root / "build/verification/harness").glob("*/report.json"), key=lambda p:p.parent.name)
        self.assertEqual((merged_path.parent / "a.log").read_text(), "COMPLETE a\n")
        self.assertEqual((merged_path.parent / "b.log").read_text(), "COMPLETE b\n")

    def test_phase_option_combinations_fail_before_execution(self):
        for args in [("--lane", "parallel"), ("--profile", "auto", "--release", "--lane", "parallel"),
                     ("--profile", "gameplay", "--lane", "parallel"),
                     ("--profile", "gameplay", "--release", "--lane", "parallel", "--reuse"),
                     ("--profile", "gameplay", "--release", "--lane", "parallel", "--jobs", "2"),
                     ("--profile", "gameplay", "--release", "--lane", "parallel", "--check", "a"),
                     ("--verify-lanes", "one", "two"),
                     ("--profile", "gameplay", "--verify-lanes", "one", "two", "--plan")]:
            with self.subTest(args=args), patch.object(h, "execute_checks") as execute:
                with self.assertRaises(SystemExit): self.cli(*args)
                execute.assert_not_called()

    def test_failed_phase_stays_partial_and_cannot_merge(self):
        (self.root / "tests/a.py").write_text("print('COMPLETE a'); raise SystemExit(3)\n")
        self.assertEqual(self.cli("--profile", "gameplay", "--release", "--lane", "parallel"), 1)
        report = json.loads(next((self.root / "build/verification/harness").glob("*/report.json")).read_text())
        self.assertTrue(report["partial"]); self.assertEqual(report["status"], "failed")
        self.assertEqual(report["checks"][0]["exit_code"], 3)

    def test_phase_rejects_source_change_even_outside_check_input_filter(self):
        original = h.execute_checks
        def mutate(*args, **kwargs):
            result = original(*args, **kwargs)
            (self.root / "assets/foundry/prepared.json").write_text("changed after last check")
            return result
        with patch.object(h, "execute_checks", side_effect=mutate):
            with self.assertRaisesRegex(RuntimeError, "changed during phase"):
                self.cli("--profile", "gameplay", "--release", "--lane", "parallel")

    def test_merge_rejects_mixed_commit_dirty_metadata_and_current_source_changes(self):
        paths = self.phases(); original = json.loads(paths[0].read_text())
        for key, value in [("commit", "f" * 40), ("git_status", ""), ("diff", ""), ("working_files", {}),
                           ("source_files_after", {}), ("source_files", {})]:
            with self.subTest(key=key):
                changed = self.copy(original); changed[key] = value; paths[0].write_text(json.dumps(changed))
                with self.assertRaises(ValueError): self.verify(paths)
        paths[0].write_text(json.dumps(original))
        for change in ("modify", "add", "delete"):
            with self.subTest(change=change):
                p = self.root / "assets/foundry/prepared.json"; old = p.read_bytes()
                if change == "modify": p.write_text("wrong prepared basis")
                elif change == "add": (self.root / "unexpected.gd").write_text("extends Node")
                else: p.unlink()
                with self.assertRaises(ValueError): self.verify(paths)
                p.write_bytes(old)
                (self.root / "unexpected.gd").unlink(missing_ok=True)

    def test_merge_rejects_scope_set_order_reuse_unknowns_and_budget_mutations(self):
        paths = self.phases(); original = json.loads(paths[0].read_text())
        mutations = [lambda r:r.update(profiles=["gameplay"]), lambda r:r.update(requested_checks=["a"]),
                     lambda r:r.update(manifest_sha256="0" * 64), lambda r:r.update(release=False),
                     lambda r:r.update(jobs=2), lambda r:r.update(targeted_checks=True),
                     lambda r:r.update(status="failed"), lambda r:r.update(status="unknown"),
                     lambda r:r.update(partial=False), lambda r:r.update(lane="serial"),
                     lambda r:r.update(checks=[]), lambda r:r["checks"].append(self.copy(r["checks"][0])),
                     lambda r:r["checks"][0].update(id="unknown"),
                     lambda r:r["checks"][0].update(timeout_seconds=999),
                     lambda r:r["checks"][0].update(argv=["python3", "tests/b.py"]),
                     lambda r:r["checks"][0].update(success_pattern=".*"),
                     lambda r:r["checks"][0].update(input_digest="0" * 64),
                     lambda r:r["checks"][0].update(reused=True),
                     lambda r:r["checks"][0].update(exit_code=1),
                     lambda r:r["checks"][0].update(exit_code=False),
                     lambda r:r["checks"][0].update(status="timeout"),
                     lambda r:r["checks"][0].update(expanded_argv=["/bin/true"]),
                     lambda r:r["checks"][0].update(duration_seconds=float("nan")),
                     lambda r:r["checks"][0].update(ended_at_unix=r["checks"][0]["started_at_unix"]+100)]
        for i, mutation in enumerate(mutations):
            with self.subTest(mutation=i):
                changed=self.copy(original);mutation(changed);paths[0].write_text(json.dumps(changed))
                with self.assertRaises(ValueError): self.verify(paths)
        paths[0].write_text(json.dumps(original))
        with self.assertRaises(ValueError): self.verify([paths[0], paths[0]])

    def test_merge_rejects_toolchain_change_failed_probe_and_postphase_change(self):
        paths = self.phases(); original = json.loads(paths[0].read_text())
        for key in ("toolchain", "toolchain_after"):
            changed=self.copy(original);changed[key]["godot"]["version"]="other";paths[0].write_text(json.dumps(changed))
            with self.assertRaises(ValueError): self.verify(paths)
        changed=self.copy(original)
        for key in ("toolchain", "toolchain_after"):changed[key]["godot"]["exit_code"]=1
        paths[0].write_text(json.dumps(changed))
        with self.assertRaises(ValueError): self.verify(paths)

    def test_merge_rechecks_original_completion_errors_missing_changed_and_linked_logs(self):
        import hashlib
        paths=self.phases();original=json.loads(paths[0].read_text());log=paths[0].parent/"a.log";old=log.read_bytes()
        for text in ("wrong marker\n", "COMPLETE a\nSCRIPT ERROR: original guard\n", "COMPLETE a\nObjectDB instances leaked\n"):
            changed=self.copy(original);log.write_text(text);changed["checks"][0]["log_sha256"]=hashlib.sha256(log.read_bytes()).hexdigest();paths[0].write_text(json.dumps(changed))
            with self.assertRaises(ValueError):self.verify(paths)
        paths[0].write_text(json.dumps(original));log.write_text("tampered")
        with self.assertRaises(ValueError):self.verify(paths)
        log.unlink()
        with self.assertRaises(ValueError):self.verify(paths)
        outside=self.root/"original-log.txt";outside.write_bytes(old);log.symlink_to(outside)
        with self.assertRaises(ValueError):self.verify(paths)

    def test_merge_rejects_real_report_and_ancestor_symlink_swaps(self):
        paths = self.phases()
        # Same real report/log bytes and unchanged ignored-build source metadata:
        # swapping the directory itself must not bypass the leaf-file checks.
        for directory in (paths[0].parent, paths[0].parent.parent, self.root / "build"):
            with self.subTest(directory=directory):
                saved = self.root / ".git/proof-directory-held"
                directory.rename(saved)
                directory.symlink_to(saved, target_is_directory=True)
                try:
                    with self.assertRaisesRegex(ValueError, "Linked phase proof"):
                        self.verify(paths)
                finally:
                    directory.unlink(); saved.rename(directory)
        report = paths[0]; saved = report.with_suffix(".held")
        report.rename(saved); report.symlink_to(saved)
        try:
            with self.assertRaisesRegex(ValueError, "Linked phase proof"):
                self.verify(paths)
        finally:
            report.unlink(); saved.rename(report)

    def test_proof_paths_reject_nonregular_external_and_parent_traversal(self):
        paths = self.phases(); report = paths[0]; saved = report.with_suffix(".held")
        report.rename(saved); report.mkdir()
        try:
            with self.assertRaisesRegex(ValueError, "non-regular"):
                self.verify(paths)
        finally:
            report.rmdir(); saved.rename(report)
        for path in (self.root / "elsewhere.json", self.root / "build/../elsewhere.json", Path("/outside/proof.json")):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "ROOT/build|traverse parents"):
                h.proof_file(path)

    def test_proof_root_system_alias_is_allowed_without_resolving_evidence_links(self):
        paths = self.phases()
        alias = self.root.parent / (self.root.name + "-workspace-alias")
        alias.symlink_to(self.root, target_is_directory=True)
        try:
            with patch.object(h, "ROOT", alias):
                aliased = [alias / p.relative_to(self.root) for p in paths]
                result = self.verify(aliased)
                self.assertEqual([item["id"] for item in result["checks"]], ["a", "b"])
                self.assertEqual(h.proof_file(paths[0].relative_to(self.root)), paths[0])
        finally:
            alias.unlink()


SPEC = importlib.util.spec_from_file_location("production_timing", Path(__file__).resolve().parents[1] / "tools/production_timing.py")
timing = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(timing)


class ProductionTimingTests(unittest.TestCase):
    def event(self, identifier, stage, start, end):
        return {"id": identifier, "stage": stage, "started_at_unix": start,
                "ended_at_unix": end, "duration_seconds": end-start, "evidence": "SIMULATED fixture"}

    def test_overlapping_work_does_not_become_elapsed_time(self):
        report = timing.summarize([self.event("1", "game_integration", 0, 10),
                                   self.event("2", "verification", 3, 8),
                                   self.event("3", "release", 12, 14)])
        self.assertEqual(report["observed_interval_union_seconds"], 12)
        self.assertEqual(report["overlap_seconds"], 5)
        self.assertEqual(report["unobserved_gap_seconds"], 2)
        self.assertIsNone(report["stages"]["image_generation"]["summed_command_seconds"])
        self.assertEqual(report["usage"], {"tokens": "not_exposed", "price": "not_exposed"})

    def test_historical_missing_intervals_stay_unknown_and_reused_work_is_not_current_cost(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); old=root/"TASK/1/implement";old.mkdir(parents=True)
            (old/"invocation.json").write_text(json.dumps({"seconds": 15}))
            (root/"TASK/1/review").mkdir()
            report=root/"report.json"
            report.write_text(json.dumps({"checks":[{"id":"old", "duration_seconds":10},
                                                     {"id":"reused", "reused":True, "duration_seconds":0}]}))
            data=timing.collect(production_dirs=[root], harness_reports=[report])
            self.assertEqual(data["events"],[]);self.assertEqual(len(data["unknown_records"]),3)
            self.assertEqual(data["unknown_records"][0]["reported_seconds"],15)
            self.assertEqual(data["stages"]["model_implementation"]["status"],"unknown")
            duration=root/"duration-only.json";duration.write_text(json.dumps({"seconds":7,"exit_code":1}))
            observed=timing.collect(reported=["network_wait="+str(duration)])
            self.assertEqual(observed["stages"]["network_wait"]["status"],"unknown")
            self.assertEqual(observed["stages"]["network_wait"]["reported_seconds_without_interval_sum"],7)
            self.assertEqual(observed["observed_interval_union_seconds"],0)
            self.assertEqual(observed["unknown_records"][0]["exit_code"],1)

    def test_invalid_or_conflicting_intervals_are_rejected(self):
        for start,end in ((5,4),(float("nan"),5),(True,5)):
            with self.assertRaises(ValueError):timing.summarize([self.event("bad","rework",start,end)])
        first=self.event("same","verification",0,3)
        self.assertEqual(len(timing.summarize([first,first])["events"]),1)
        with self.assertRaises(ValueError):timing.summarize([first,self.event("same","verification",0,4)])

    def test_actual_command_failure_and_output_hash_are_recorded(self):
        # Real subprocess exercises measurement, not model/game production.
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);ledger=root/"events.jsonl";output=root/"real-output.txt";native_log=root/"native.log";missing=root/"not-generated.log"
            command=[sys.executable,str(Path(timing.__file__)),"run","--ledger",str(ledger),"--stage","verification",
                     "--label","real recorder failure probe","--output",str(output),"--output",str(missing),"--log-file",str(native_log),"--",sys.executable,"-c",
                     f"import sys; from pathlib import Path; print('real stdout'); print('real stderr',file=sys.stderr); Path({str(output)!r}).write_text('measured'); raise SystemExit(7)"]
            completed=subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(completed.returncode,7,completed.stderr)
            data=timing.collect([ledger]);event=data["events"][0]
            self.assertEqual(event["exit_code"],7);self.assertEqual(event["outputs"][0]["status"],"present")
            self.assertEqual(len(event["outputs"][0]["sha256"]),64)
            self.assertEqual(event["outputs"][1]["status"],"missing");self.assertFalse(missing.exists())
            self.assertEqual(event["captured_log"]["status"],"present")
            self.assertIn("real stdout",native_log.read_text());self.assertIn("real stderr",native_log.read_text())
            self.assertEqual(len(event["captured_log"]["sha256"]),64)
            # A real second run cannot overwrite the first failure log.
            first_bytes=native_log.read_bytes();again=subprocess.run(command,capture_output=True,text=True)
            self.assertNotEqual(again.returncode,0);self.assertEqual(native_log.read_bytes(),first_bytes)
            self.assertEqual(timing.collect([ledger])["events"][-1]["captured_log"]["status"],"not_created")


def load_tests(loader, standard_tests, pattern):
    # Keep the original suite and run new completion/forgery guards through
    # the same CI entry point and existing 60-second budget.
    for module_name in ("test_grapple_feel_wrapper", "test_forest_vertical_shortcut"):
        standard_tests.addTests(loader.loadTestsFromName(module_name))
    return standard_tests


if __name__ == "__main__":
    unittest.main()
