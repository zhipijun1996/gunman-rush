#!/usr/bin/env python3
"""Pure installed-file checks: no network, Godot, or candidate-release ZIP."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/install_mapgen_candidate.py"
LOCK = "config/mapgen_candidate.json"


class InstallMapgenCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads((ROOT / LOCK).read_text())
        cls.members = list(lock["addon_files"]) + [
            lock["module_package"]["path"].removeprefix("res://"),
            lock["conformance"]["request"]["path"].removeprefix("res://"),
            lock["conformance"]["config"]["path"].removeprefix("res://"), LOCK]
        cls.payload = {name:(ROOT / name).read_bytes() for name in cls.members}

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mapgen-install-test-")
        self.addCleanup(self.temporary.cleanup)
        self.target = Path(self.temporary.name) / "target"
        for name,data in self.payload.items():
            path = self.target / name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)

    def cli(self, *args):
        return subprocess.run([sys.executable,"-B",str(TOOL),*map(str,args)],
            cwd=self.temporary.name,capture_output=True,text=True,timeout=30,
            env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"})

    def installed(self):
        return self.cli("verify-installed","--target",self.target)

    def rejected(self, result, message):
        self.assertEqual(result.returncode,2,result.stdout+result.stderr)
        self.assertIn(message,result.stderr)

    def archive_boundary_fixture_cli(self, command, target=None):
        # Exercise the real default CLI/main and shared destination preflight.
        # Only the archive-reading boundary is supplied already-authenticated
        # installed fixture bytes: CI neither downloads nor needs the full ZIP.
        code = '''import sys,json
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import install_mapgen_candidate as installer
source=Path(sys.argv[2]);names=json.loads(sys.argv[3]);target=sys.argv[4];command=sys.argv[5]
installer.read_payload=lambda archive:{name:(source/name).read_bytes() for name in names}
sys.argv=[str(source/'tools/install_mapgen_candidate.py'),command,'--archive','unused-test-fixture.zip','--target',target]
raise SystemExit(installer.main())
'''
        return subprocess.run([sys.executable,"-B","-c",code,str(ROOT/"tools"),str(ROOT),
            json.dumps(self.members),str(target or self.target),command],cwd=self.temporary.name,
            capture_output=True,text=True,timeout=30,env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"})

    def test_default_cli_verifies_actual_checkout_without_archive(self):
        result = self.cli("verify-installed")
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        receipt = json.loads(result.stdout)
        self.assertEqual(receipt["target"],str(ROOT))
        self.assertEqual(receipt["command"],"verify-installed")
        self.assertEqual(receipt["installed"],[])
        self.assertEqual(len(receipt["files"]),19)
        self.assertFalse(receipt["candidate_archive_checked"])
        self.assertFalse(receipt["godot_run"])

    def test_valid_copy_and_known_engine_uid_are_read_only(self):
        uid = self.target / "addons/mapgen/geometry.gd.uid"
        uid.write_text("uid://test-generated-companion\n")
        before = {name:(self.target/name).stat().st_mtime_ns for name in self.members}
        result = self.installed()
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(len(json.loads(result.stdout)["unchanged"]),19)
        self.assertEqual(before,{name:(self.target/name).stat().st_mtime_ns for name in self.members})

    def test_missing_required_files_reject(self):
        for name in ["addons/mapgen/solver.gd","resources/mapgen/module-pack-1.1.0.zip",
                     "resources/mapgen/conformance_request.json","resources/mapgen/generator_config.json",LOCK]:
            with self.subTest(name=name):
                path = self.target/name
                path.unlink()
                self.rejected(self.installed(),"installed file missing:"+name)
                self.assertFalse(path.exists())
                path.write_bytes(self.payload[name])

    def test_changed_code_and_each_runtime_data_kind_reject(self):
        for name in ["addons/mapgen/geometry.gd","resources/mapgen/module-pack-1.1.0.zip",
                     "resources/mapgen/conformance_request.json","resources/mapgen/generator_config.json"]:
            with self.subTest(name=name):
                path = self.target/name
                if name.endswith(".json"):
                    value = json.loads(path.read_text())
                    if "seed" in value:
                        value["seed"] += 1
                    else:
                        value["goals"]["reward_target"] -= 1
                    changed = json.dumps(value).encode()
                else:
                    changed = path.read_bytes()+b"changed"
                path.write_bytes(changed)
                self.rejected(self.installed(),"installed file differs; refusing overwrite:"+name)
                self.assertEqual(path.read_bytes(),changed)
                path.write_bytes(self.payload[name])

    def test_changed_lock_cannot_approve_resigned_code(self):
        import hashlib
        code = self.target/"addons/mapgen/geometry.gd"
        code.write_bytes(code.read_bytes()+b"\n# changed\n")
        lock = json.loads((self.target/LOCK).read_text())
        lock["addon_files"]["addons/mapgen/geometry.gd"] = hashlib.sha256(code.read_bytes()).hexdigest()
        (self.target/LOCK).write_text(json.dumps(lock))
        self.rejected(self.installed(),"installed file differs")

    def test_source_identity_metadata_change_rejects(self):
        lock = json.loads((self.target/LOCK).read_text())
        lock["source_commit"] = lock["release_head"]
        (self.target/LOCK).write_text(json.dumps(lock))
        self.rejected(self.installed(),"installed file differs; refusing overwrite:"+LOCK)

    def test_extra_solver_rejects(self):
        extra = self.target/"addons/mapgen/another_solver.gd"
        extra.write_text("extends RefCounted\n")
        self.rejected(self.installed(),"unexpected addon file:addons/mapgen/another_solver.gd")

    def test_editor_plugin_rejects(self):
        (self.target/"addons/mapgen/plugin.cfg").write_text("[plugin]\n")
        self.rejected(self.installed(),"unexpected addon file:addons/mapgen/plugin.cfg")

    def test_orphan_uid_rejects(self):
        (self.target/"addons/mapgen/not-installed.gd.uid").write_text("uid://orphan\n")
        self.rejected(self.installed(),"unexpected addon file:addons/mapgen/not-installed.gd.uid")

    def test_symlink_source_rejects(self):
        code = self.target/"addons/mapgen/geometry.gd"
        code.unlink()
        code.symlink_to(ROOT/"addons/mapgen/geometry.gd")
        self.rejected(self.installed(),"unsafe install destination:addons/mapgen/geometry.gd")

    def test_install_conflict_checks_all_targets_before_writing(self):
        first = self.target/self.members[0]
        first.unlink()
        conflict = self.target/LOCK
        conflict.write_bytes(b"keep this conflicting file\n")
        before = {p.relative_to(self.target).as_posix():p.read_bytes()
                  for p in self.target.rglob("*") if p.is_file()}
        result = self.archive_boundary_fixture_cli("install")
        self.rejected(result,"installed file differs; refusing overwrite:"+LOCK)
        self.assertFalse(first.exists(),"an early missing file was written before a later conflict")
        self.assertEqual(before,{p.relative_to(self.target).as_posix():p.read_bytes()
                                for p in self.target.rglob("*") if p.is_file()})

    def test_original_install_repeat_and_archive_verify_share_the_checks(self):
        empty = Path(self.temporary.name)/"new-install"
        first = self.archive_boundary_fixture_cli("install",empty)
        self.assertEqual(first.returncode,0,first.stdout+first.stderr)
        self.assertEqual(len(json.loads(first.stdout)["installed"]),19)
        before = {name:(empty/name).stat().st_mtime_ns for name in self.members}
        for command in ["install","verify"]:
            result = self.archive_boundary_fixture_cli(command,empty)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["installed"],[])
            self.assertEqual(len(receipt["unchanged"]),19)
            self.assertTrue(receipt["candidate_archive_checked"])
        self.assertEqual(before,{name:(empty/name).stat().st_mtime_ns for name in self.members})

    def test_archive_commands_still_require_explicit_archive(self):
        for command in ["install","verify"]:
            with self.subTest(command=command):
                self.rejected(self.cli(command,"--target",self.target),"install/verify require --archive")

    def test_offline_command_does_not_accept_archive(self):
        self.rejected(self.cli("verify-installed","--archive","not-needed.zip","--target",self.target),
                      "verify-installed does not use --archive")


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(InstallMapgenCandidateTests))
    failures = len(result.failures)+len(result.errors)
    print("MAPGEN CANDIDATE INSTALL: %d tests, %d failures" % (result.testsRun,failures))
    sys.exit(0 if result.wasSuccessful() else 1)
