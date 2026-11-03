#!/usr/bin/env python3
"""Pure installed-file checks: no network, Godot, or candidate-release ZIP."""
import json
import hashlib
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
            lock["conformance"]["config"]["path"].removeprefix("res://"), LOCK,
            lock["gears_conformance"]["request"]["path"].removeprefix("res://")]
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

    def archive_boundary_fixture_cli(self, command, target=None, legacy_hashes=None, additional_source=None):
        # Exercise the real default CLI/main and shared destination preflight.
        # Only the archive-reading boundary is supplied already-authenticated
        # installed fixture bytes: CI neither downloads nor needs the full ZIP.
        code = '''import sys,json
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import install_mapgen_candidate as installer
source=Path(sys.argv[2]);names=json.loads(sys.argv[3]);target=sys.argv[4];command=sys.argv[5]
if sys.argv[7] != "null":
    installer.ROOT=Path(json.loads(sys.argv[7]))
def payload_fixture(archive):
    extra=installer.additional_payload()
    return {**{name:(source/name).read_bytes() for name in names},**extra}
installer.read_payload=payload_fixture
if sys.argv[6] != "null":
    legacy=json.loads(sys.argv[6])
    installer.legacy_hashes=lambda:legacy
sys.argv=[str(source/'tools/install_mapgen_candidate.py'),command,'--archive','unused-test-fixture.zip','--target',target]
raise SystemExit(installer.main())
'''
        return subprocess.run([sys.executable,"-B","-c",code,str(ROOT/"tools"),str(ROOT),
            json.dumps(self.members),str(target or self.target),command,json.dumps(legacy_hashes),json.dumps(str(additional_source) if additional_source else None)],cwd=self.temporary.name,
            capture_output=True,text=True,timeout=30,env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"})

    def test_default_cli_verifies_actual_checkout_without_archive(self):
        result = self.cli("verify-installed")
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        receipt = json.loads(result.stdout)
        self.assertEqual(receipt["target"],str(ROOT))
        self.assertEqual(receipt["command"],"verify-installed")
        self.assertEqual(receipt["installed"],[])
        self.assertEqual(len(receipt["files"]),23)
        self.assertFalse(receipt["candidate_archive_checked"])
        self.assertFalse(receipt["godot_run"])

    def test_valid_copy_and_known_engine_uid_are_read_only(self):
        uid = self.target / "addons/mapgen/geometry.gd.uid"
        uid.write_text("uid://test-generated-companion\n")
        before = {name:(self.target/name).stat().st_mtime_ns for name in self.members}
        result = self.installed()
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(len(json.loads(result.stdout)["unchanged"]),23)
        self.assertEqual(before,{name:(self.target/name).stat().st_mtime_ns for name in self.members})

    def test_missing_required_files_reject(self):
        for name in ["addons/mapgen/solver.gd","resources/mapgen/module-pack-1.1.0.zip",
                     "resources/mapgen/conformance_request.json","resources/mapgen/generator_config.json","resources/mapgen/gears_request_930007.json",LOCK]:
            with self.subTest(name=name):
                path = self.target/name
                path.unlink()
                self.rejected(self.installed(),"installed file missing:"+name)
                self.assertFalse(path.exists())
                path.write_bytes(self.payload[name])

    def test_changed_code_and_each_runtime_data_kind_reject(self):
        for name in ["addons/mapgen/geometry.gd","resources/mapgen/module-pack-1.1.0.zip",
                     "resources/mapgen/conformance_request.json","resources/mapgen/generator_config.json",
                     "resources/mapgen/gears_request_930007.json"]:
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
        self.assertEqual(len(json.loads(first.stdout)["installed"]),23)
        before = {name:(empty/name).stat().st_mtime_ns for name in self.members}
        for command in ["install","verify"]:
            result = self.archive_boundary_fixture_cli(command,empty)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["installed"],[])
            self.assertEqual(len(receipt["unchanged"]),23)
            self.assertTrue(receipt["candidate_archive_checked"])
        self.assertEqual(before,{name:(empty/name).stat().st_mtime_ns for name in self.members})

    def test_archive_commands_still_require_explicit_archive(self):
        for command in ["install","verify","upgrade"]:
            with self.subTest(command=command):
                self.rejected(self.cli(command,"--target",self.target),"install/verify/upgrade require --archive")

    def test_offline_command_does_not_accept_archive(self):
        self.rejected(self.cli("verify-installed","--archive","not-needed.zip","--target",self.target),
                      "verify-installed does not use --archive")


    def legacy_fixture(self):
        # No archived solver is copied into CI. Supply authenticated fixture
        # bytes only at the old-installation hash boundary; upgrade/preflight,
        # path inventory, CLI and all actual writes remain the real functions.
        # Real exact 0.3 bytes + original 0.4 ZIP are checked in external evidence.
        new_names = {"preload_job.gd", "work_gate.gd", "reward_clearance.gd",
                     "gears_request_930007.json"}
        for name in self.members:
            path = self.target/name
            if path.name in new_names:
                path.unlink()
            elif name.startswith("addons/mapgen/") or name in {
                    LOCK,"resources/mapgen/generator_config.json"}:
                path.write_bytes(b"authenticated old fixture:"+name.encode())
        return {name:hashlib.sha256((self.target/name).read_bytes()).hexdigest()
                for name in self.members if (self.target/name).exists()}

    def snapshot(self):
        return {p.relative_to(self.target).as_posix():p.read_bytes()
                for p in self.target.rglob("*") if p.is_file()}

    def rejected_upgrade(self, hashes, message):
        before = self.snapshot()
        result = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes)
        self.rejected(result,message)
        self.assertEqual(before,self.snapshot(),"rejected upgrade changed target bytes")

    def test_upgrade_exact_previous_pin_is_fixed_not_in_target_metadata(self):
        code = """import sys,json
sys.path.insert(0,sys.argv[1])
import install_mapgen_candidate as i
print(json.dumps(i.legacy_hashes()))
"""
        result = subprocess.run([sys.executable,"-B","-c",code,str(ROOT/"tools")],
            capture_output=True,text=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stderr)
        hashes = json.loads(result.stdout)
        self.assertEqual(len(hashes),19)
        self.assertEqual(hashes[LOCK],"d8271d473686fd1e7b0bcfab280aa2940777eb1eaa02478b80909cb8eecae92f")
        self.assertEqual(hashes["resources/mapgen/generator_config.json"],
                         "aafd76336c23ff144b94368f3290114cd3ae7be812dedbcd8a50ca610102f89a")
        self.assertEqual(hashes["addons/mapgen/solver.gd"],
                         "dc9ab9eb10761cdd251e6267ac7330f831ace168df467c873511e6e8d096131a")
        self.assertNotIn("addons/mapgen/reward_clearance.gd",hashes)

    def test_explicit_upgrade_replaces_only_authenticated_previous_bytes(self):
        hashes = self.legacy_fixture()
        uid = self.target/"addons/mapgen/geometry.gd.uid"
        uid.write_text("uid://preserved-upgrade-companion\n")
        result = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        receipt = json.loads(result.stdout)
        self.assertEqual(receipt["command"],"upgrade")
        self.assertEqual(receipt["upgraded_from"]["version"],"0.3.0")
        self.assertEqual(len(receipt["installed"]),4)
        self.assertEqual(len(receipt["files"]),23)
        self.assertIn(LOCK,receipt["replaced"])
        self.assertEqual(uid.read_text(),"uid://preserved-upgrade-companion\n")
        self.assertEqual({n:(self.target/n).read_bytes() for n in self.members},self.payload)
        self.assertEqual(self.installed().returncode,0)
        repeat = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes)
        self.assertEqual(repeat.returncode,0,repeat.stdout+repeat.stderr)
        self.assertTrue(json.loads(repeat.stdout)["already_current"])
        self.assertEqual(json.loads(repeat.stdout)["replaced"],[])

    def test_default_install_still_refuses_old_version_before_writing(self):
        self.legacy_fixture()
        before = self.snapshot()
        self.rejected(self.archive_boundary_fixture_cli("install"),"installed file differs; refusing overwrite:")
        self.assertEqual(before,self.snapshot())

    def test_upgrade_missing_old_file_rejects(self):
        hashes = self.legacy_fixture()
        (self.target/"resources/mapgen/conformance_request.json").unlink()
        self.rejected_upgrade(hashes,"installed file missing:resources/mapgen/conformance_request.json")

    def test_upgrade_modified_old_code_rejects(self):
        hashes = self.legacy_fixture()
        path = self.target/"addons/mapgen/solver.gd"
        path.write_bytes(path.read_bytes()+b"changed")
        self.rejected_upgrade(hashes,"installed file differs; refusing overwrite:addons/mapgen/solver.gd")

    def test_upgrade_late_old_lock_conflict_precedes_all_writes(self):
        hashes = self.legacy_fixture()
        (self.target/LOCK).write_bytes(b"edited old lock claiming approval")
        self.rejected_upgrade(hashes,"installed file differs; refusing overwrite:"+LOCK)
        for name in ["preload_job.gd","work_gate.gd","reward_clearance.gd"]:
            self.assertFalse((self.target/"addons/mapgen"/name).exists())

    def test_upgrade_new_script_collision_rejects(self):
        hashes = self.legacy_fixture()
        (self.target/"addons/mapgen/preload_job.gd").write_text("keep preexisting script")
        self.rejected_upgrade(hashes,"unexpected addon file:addons/mapgen/preload_job.gd")

    def test_upgrade_symlink_old_file_rejects(self):
        hashes = self.legacy_fixture()
        path = self.target/"addons/mapgen/solver.gd"
        path.unlink()
        path.symlink_to(ROOT/"addons/mapgen/solver.gd")
        self.rejected_upgrade(hashes,"unsafe install destination:addons/mapgen/solver.gd")

    def test_upgrade_current_version_is_no_change_without_claiming_old_verification(self):
        # Current exact version may repeat, but cannot claim an old-version upgrade.
        before = self.snapshot()
        result = self.archive_boundary_fixture_cli("upgrade")
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        receipt = json.loads(result.stdout)
        self.assertTrue(receipt["already_current"])
        self.assertIsNone(receipt["upgraded_from"])
        self.assertEqual(receipt["installed"],[])
        self.assertEqual(before,self.snapshot())

    def test_additional_original_input_missing_or_tampered_precedes_upgrade_writes(self):
        hashes = self.legacy_fixture()
        source = Path(self.temporary.name)/"additional-source"
        leaf = source/"resources/mapgen/gears_request_930007.json"
        for data,message in [(None,"No such file"),(b"changed original request","additional upstream input SHA mismatch")]:
            with self.subTest(missing=data is None):
                if data is not None:
                    leaf.parent.mkdir(parents=True,exist_ok=True)
                    leaf.write_bytes(data)
                before = self.snapshot()
                result = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes,additional_source=source)
                self.rejected(result,message)
                self.assertEqual(before,self.snapshot())

    def test_unsupported_old_version_metadata_rejects_without_writes(self):
        hashes = self.legacy_fixture()
        (self.target/LOCK).write_text(json.dumps({"version":"0.3.1"}))
        self.rejected_upgrade(hashes,"installed file differs; refusing overwrite:"+LOCK)

    def internal_directory_alias(self, root, name):
        original = root/name
        backing = root/("alias-backing-"+name.replace("/","-"))
        original.rename(backing)
        original.symlink_to(backing,target_is_directory=True)
        return original,backing

    def restore_directory_alias(self, original, backing):
        original.unlink()
        backing.rename(original)

    def test_installed_managed_parent_and_addon_root_aliases_reject(self):
        for name in ["addons","addons/mapgen","resources","resources/mapgen","config"]:
            with self.subTest(name=name):
                original,backing = self.internal_directory_alias(self.target,name)
                try:
                    before = self.snapshot()
                    self.rejected(self.installed(),"unsafe install destination:")
                    self.assertEqual(before,self.snapshot())
                    self.assertTrue(original.is_symlink())
                finally:
                    self.restore_directory_alias(original,backing)

    def test_archive_install_and_verify_parent_aliases_reject_without_writes(self):
        for name in ["addons","addons/mapgen","resources","resources/mapgen","config"]:
            with self.subTest(name=name):
                original,backing = self.internal_directory_alias(self.target,name)
                try:
                    for command in ["install","verify"]:
                        before = self.snapshot()
                        self.rejected(self.archive_boundary_fixture_cli(command),"unsafe install destination:")
                        self.assertEqual(before,self.snapshot())
                finally:
                    self.restore_directory_alias(original,backing)

    def test_upgrade_parent_aliases_reject_before_first_write(self):
        hashes = self.legacy_fixture()
        for name in ["addons","addons/mapgen","resources","resources/mapgen","config"]:
            with self.subTest(name=name):
                original,backing = self.internal_directory_alias(self.target,name)
                try:
                    self.rejected_upgrade(hashes,"unsafe install destination:")
                    self.assertTrue(original.is_symlink())
                    for new in ["preload_job.gd","work_gate.gd","reward_clearance.gd"]:
                        self.assertFalse((self.target/"addons/mapgen"/new).exists())
                    self.assertFalse((self.target/"resources/mapgen/gears_request_930007.json").exists())
                finally:
                    self.restore_directory_alias(original,backing)

    def test_additional_source_parent_aliases_reject_before_upgrade_writes(self):
        hashes = self.legacy_fixture()
        source = Path(self.temporary.name)/"additional-source"
        leaf = source/"resources/mapgen/gears_request_930007.json"
        leaf.parent.mkdir(parents=True)
        leaf.write_bytes(self.payload["resources/mapgen/gears_request_930007.json"])
        for name in ["resources","resources/mapgen"]:
            with self.subTest(name=name):
                original,backing = self.internal_directory_alias(source,name)
                try:
                    before = self.snapshot()
                    result = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes,additional_source=source)
                    self.rejected(result,"unsafe additional input:resources/mapgen/gears_request_930007.json")
                    self.assertEqual(before,self.snapshot())
                    self.assertTrue(original.is_symlink())
                finally:
                    self.restore_directory_alias(original,backing)

    def test_additional_source_leaf_alias_rejects_before_upgrade_writes(self):
        hashes = self.legacy_fixture()
        source = Path(self.temporary.name)/"additional-source"
        leaf = source/"resources/mapgen/gears_request_930007.json"
        leaf.parent.mkdir(parents=True)
        leaf.symlink_to(ROOT/"resources/mapgen/gears_request_930007.json")
        before = self.snapshot()
        result = self.archive_boundary_fixture_cli("upgrade",legacy_hashes=hashes,additional_source=source)
        self.rejected(result,"unsafe additional input:resources/mapgen/gears_request_930007.json")
        self.assertEqual(before,self.snapshot())

    def test_explicit_target_alias_retains_canonical_project_boundary(self):
        alias = Path(self.temporary.name)/"explicit-project-alias"
        alias.symlink_to(self.target,target_is_directory=True)
        before = self.snapshot()
        result = self.cli("verify-installed","--target",alias)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(json.loads(result.stdout)["target"],str(self.target.resolve()))
        self.assertEqual(before,self.snapshot())


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(InstallMapgenCandidateTests))
    failures = len(result.failures)+len(result.errors)
    print("MAPGEN CANDIDATE INSTALL: %d tests, %d failures" % (result.testsRun,failures))
    sys.exit(0 if result.wasSuccessful() else 1)
