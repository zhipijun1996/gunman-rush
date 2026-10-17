"""Exercise failure classification and scope selection without requiring Godot."""
import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
