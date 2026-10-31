"""Synthetic receipt/state-machine counterexamples; these are not Motor evidence."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import level_formal as formal


def make_receipt(path, data, log, sources):
    """Build a schema2 accepted UNIT FIXTURE; caller owns synthetic capture/log."""
    request = {key: data[key] for key in ("source_commit", "root_seed", "map_index", "strategy", "phase_wait_ticks")}
    request["max_ticks"] = 18000
    return dict(schema_version=2, scope="actual_live_demo_app_capture", status="accepted", errors=[],
                source_commit=data["source_commit"], source_files=sources, source_before=sources, source_after=sources,
                request=request, command=formal.command_for(request, path), capture=str(path.relative_to(formal.ROOT)),
                capture_sha256=formal.file_hash(path), log_sha256=formal.file_hash(log), exit_code=0,
                visible=False, realtime=False, frame_dir="", frame_stride=120)


class FormalSourceInventoryTests(unittest.TestCase):
    def test_runtime_inventory_hashes_real_game_edits_additions_and_deletions(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            required = ['project.godot', 'tools/godot.sh', 'tools/level_formal.py', 'tools/level_design.py',
                        'tools/level_formal_capture.gd', 'tools/level_capability_snapshot.gd',
                        'scripts/legacy.gd', 'game/application/run_session.gd']
            for name in required + ['build/old.gd', 'docs/evidence/frozen.gd']:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('fixture bytes')
            with patch.object(formal, 'ROOT', root), patch.object(formal, '__file__', str(root/'tools/level_formal.py')), \
                    patch.object(formal, 'driver_source_paths', return_value=[]):
                before = formal.source_files()
                self.assertEqual(set(before), set(required))
                (root/'game/application/run_session.gd').write_text('changed actual owner')
                self.assertNotEqual(before, formal.source_files())
                path = root/'game/application/new_untracked.gd'; path.write_text('added owner')
                self.assertIn('game/application/new_untracked.gd', formal.source_files())
                path.unlink()
                self.assertNotIn('game/application/new_untracked.gd', formal.source_files())


class FormalReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="unit-receipts-", dir=formal.ROOT / "build")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.path = self.folder / "capture.json"
        self.log = self.path.with_suffix(".log")
        self.sources = {"tools/level_formal_capture.gd":"a"*64, "tests/level_formal_trace.gd":"b"*64}
        self.data = dict(schema_version=1, artifact_kind="formal_level_capture", source_commit="c"*40,
                         root_seed="synthetic-unit-not-motor", map_index=1, strategy="fast", phase_wait_ticks=0,
                         manifest={"manifest_hash":"d"*64}, manifest_hash="d"*64, frames=[{"tick":1}], edges=[],
                         outcome="route_policy_failed", route_reached=False, capture_errors=[], engine="4.7.2-stable (official)",
                         capture_source_hashes={"res://"+k:v for k,v in self.sources.items()},
                         captured_scope={k:True for k in ("enemies_instantiated", "enemy_attacks_enabled", "enemy_contacts_enabled", "production_rewards_enabled", "production_camera_enabled")})
        self.data["captured_scope"].update({k:False for k in ("controller_manual_step", "actor_teleport_by_driver", "resource_injection", "enemy_disable")})
        self.log_text = "Godot Engine v4.7.2.stable.official.abc123\nLEVEL FORMAL CAPTURE: 1 frames, 0 edges, outcome=route_policy_failed, capture_errors=0\n"
        formal.write(self.path, self.data); self.log.write_text(self.log_text)
        self.receipt = make_receipt(self.path, self.data, self.log, self.sources)
        formal.write(self.path.with_suffix(".invocation.json"), self.receipt)

    def validate(self, receipt=None):
        return formal.validate_capture(self.path, self.data, receipt or self.receipt, self.log, current_sources=self.sources)

    def test_accepted_terminal_positive(self):
        self.assertEqual(self.validate(), [])

    def test_terminal_status_and_errors_fail_closed(self):
        for fields in ({"status":"running"}, {"status":"rejected"}, {"errors":["previous source drift"]}, {"source_after":None}, {"source_after":{"changed":"f"*64}}, {"schema_version":99}, {"exit_code":True}):
            with self.subTest(fields=fields):
                receipt = copy.deepcopy(self.receipt); receipt.update(fields)
                self.assertTrue(self.validate(receipt))

    def test_payload_counterexamples(self):
        for field, value in (("capture_sha256","0"*64),("log_sha256","0"*64),("command",[]),("source_files",{})):
            with self.subTest(field=field):
                receipt=copy.deepcopy(self.receipt);receipt[field]=value
                self.assertTrue(self.validate(receipt))
        self.data["captured_scope"]["enemy_disable"] = True
        formal.write(self.path,self.data);self.receipt["capture_sha256"]=formal.file_hash(self.path)
        self.assertIn("altered formal runtime",self.validate())

    def simulate(self, sources_after=None, process_failure=None):
        output=self.folder/"produced"/"capture.json"
        def producer(command, **kwargs):
            if process_failure: raise process_failure
            formal.write(output,self.data);kwargs["stdout"].write(self.log_text);kwargs["stdout"].flush()
            return Mock(returncode=0,poll=Mock(return_value=0))
        with patch.object(formal,"source_files",side_effect=[self.sources, sources_after or self.sources]), patch.object(formal.subprocess,"check_output",return_value=self.data["source_commit"]), patch.object(formal.subprocess,"Popen",side_effect=producer):
            result=formal.capture_one(self.data["root_seed"],1,"fast",output)
        return output,result,formal.read(output.with_suffix(".invocation.json"))

    def test_producer_accepts_only_after_validation(self):
        output,result,receipt=self.simulate()
        self.assertTrue(result["captured"]); self.assertEqual(receipt["status"],"accepted")
        self.assertEqual(formal.validate_capture(output,self.data,receipt,output.with_suffix(".log"),self.sources),[])

    def test_source_drift_stays_rejected_on_historical_reanalysis(self):
        changed={**self.sources,"changed":"e"*64}
        output,result,receipt=self.simulate(changed)
        self.assertFalse(result["captured"]); self.assertEqual(receipt["status"],"rejected")
        # The exact old exploit supplies the receipt's own source map.
        self.assertTrue(formal.validate_capture(output,self.data,receipt,output.with_suffix(".log"),receipt["source_files"]))

    def test_spawn_failure_is_terminal_and_cannot_be_overwritten(self):
        output,result,receipt=self.simulate(process_failure=OSError("simulated missing engine"))
        self.assertFalse(result["captured"]);self.assertEqual(receipt["status"],"rejected")
        with self.assertRaises(ValueError): formal.capture_one("retry",1,"fast",output)

    def test_empty_producer_output_is_terminal_rejection(self):
        self.data={}
        # Preserve producer request metadata, then make its output empty.
        output=self.folder/"empty"/"capture.json"
        def producer(command, **kwargs):
            formal.write(output,{});kwargs["stdout"].write(self.log_text);kwargs["stdout"].flush()
            return Mock(returncode=0,poll=Mock(return_value=0))
        with patch.object(formal,"source_files",return_value=self.sources),patch.object(formal.subprocess,"check_output",return_value="c"*40),patch.object(formal.subprocess,"Popen",side_effect=producer):
            result=formal.capture_one("unit-empty",1,"fast",output)
        self.assertFalse(result["captured"])
        self.assertEqual(formal.read(output.with_suffix(".invocation.json"))["status"],"rejected")

    def test_interruption_never_writes_accepted_receipt(self):
        output=self.folder/"interrupt"/"capture.json"
        with patch.object(formal,"source_files",return_value=self.sources),patch.object(formal.subprocess,"check_output",return_value="c"*40),patch.object(formal.subprocess,"Popen",side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):formal.capture_one("unit-interrupted",1,"fast",output)
        self.assertEqual(formal.read(output.with_suffix(".invocation.json"))["status"],"rejected")

    def legacy(self):
        receipt=copy.deepcopy(self.receipt)
        for field in ("status","errors","source_before","source_after"):receipt.pop(field)
        receipt["schema_version"]=1
        formal.write(self.path.with_suffix(".invocation.json"),receipt)
        case=dict(capture=str(self.path.relative_to(formal.ROOT)),captured=True,errors=[],seed=self.data["root_seed"],map_index=1,strategy="fast",phase_wait_ticks=0,outcome=self.data["outcome"],route_reached=False,frames=1)
        batch=self.folder/"batch.json"
        formal.write(batch,dict(schema_version=1,artifact_kind="formal_capture_batch",requested_cases=1,captured_cases=1,cases=[case]))
        return receipt,batch

    def migrate(self,batch):
        with patch.object(formal,"_frozen_sources",return_value=self.sources),patch.object(formal.subprocess,"check_output",return_value="e"*40):
            return formal.migrate_legacy_batch(batch,"explicit-synthetic-frozen-tree")

    def test_legacy_requires_explicit_sidecar_and_preserves_original(self):
        receipt,batch=self.legacy(); original=self.path.with_suffix(".invocation.json").read_bytes()
        self.assertTrue(self.validate(receipt))
        self.migrate(batch); sidecar=formal.find_legacy_migration(self.path)
        self.assertEqual(self.path.with_suffix(".invocation.json").read_bytes(),original)
        with patch.object(formal,"_frozen_sources",return_value=self.sources):
            self.assertEqual(formal.validate_capture(self.path,self.data,receipt,self.log,self.sources,sidecar),[])

    def test_legacy_rejected_batch_or_unfrozen_source_cannot_migrate(self):
        receipt,batch=self.legacy();data=formal.read(batch);data["cases"][0]["captured"]=False;formal.write(batch,data)
        with self.assertRaises(ValueError):self.migrate(batch)
        data["cases"][0]["captured"]=True;formal.write(batch,data)
        with patch.object(formal,"_frozen_sources",return_value={"other":"f"*64}),patch.object(formal.subprocess,"check_output",return_value="e"*40):
            with self.assertRaises(ValueError):formal.migrate_legacy_batch(batch,"wrong-source")

    def test_legacy_changed_receipt_batch_and_membership_rejected(self):
        receipt,batch=self.legacy();self.migrate(batch);sidecar=formal.find_legacy_migration(self.path)
        original_batch=batch.read_bytes();original_receipt=self.path.with_suffix(".invocation.json").read_bytes()
        with patch.object(formal,"_frozen_sources",return_value=self.sources):
            changed=copy.deepcopy(receipt);changed["error"]="previous rejection";formal.write(self.path.with_suffix(".invocation.json"),changed)
            self.assertTrue(formal.validate_legacy_migration(self.path,changed,sidecar))
            self.path.with_suffix(".invocation.json").write_bytes(original_receipt)
            data=formal.read(batch);data["cases"][0]["errors"]=["source drift"];formal.write(batch,data)
            self.assertTrue(formal.validate_legacy_migration(self.path,receipt,sidecar))
            # Even updating the sidecar batch hash cannot bless original failed cases.
            proof=formal.read(sidecar);proof["batch_sha256"]=formal.file_hash(batch);formal.write(sidecar,proof)
            self.assertTrue(formal.validate_legacy_migration(self.path,receipt,sidecar))
            batch.write_bytes(original_batch)
            self.assertTrue(formal.validate_legacy_migration(self.folder/"unlisted.json",receipt,sidecar))


class ExplicitPolicyBasisTests(unittest.TestCase):
    """Source identity counterexamples only, never actual physics evidence."""
    def setUp(self):
        self.sources=formal.source_files()
        self.data={"runtime_source_hashes":{"res://"+k:v for k,v in self.sources.items() if k == "project.godot" or k.startswith(("scripts/","scenes/","resources/","config/","shaders/","assets/"))},"capture_source_hashes":{"res://"+k:self.sources[k] for k in ["tools/level_formal_capture.gd","tests/level_formal_trace.gd","scripts/art/plains_region_scenery.gd"]},"capture_contract_version":2,"encounter_policy":"kill_from_bank_v1","resource_receipts":[],"policy_observations":[],
                   "policy_basis":{"schema_version":1,"encounter_policy":"kill_from_bank_v1","reward_policy":"two_actual_medium_and_camp_v1",
                                   "driver_sources":{"res://"+p:self.sources[p] for p in formal.driver_source_paths()},
                                   "core_invariants":{"res://"+p:self.sources[p] for p in formal.core_source_paths()}}}
    def test_actual_complete_projection(self):
        self.assertEqual(formal.validate_policy_basis(self.data,self.sources),[])
    def test_missing_changed_motor_driver_or_empty_full_source_rejected(self):
        for section in ("driver_sources","core_invariants"):
            for mutation in ("delete","change"):
                data=copy.deepcopy(self.data);key=next(iter(data["policy_basis"][section]))
                if mutation=="delete":del data["policy_basis"][section][key]
                else:data["policy_basis"][section][key]="0"*64
                self.assertTrue(formal.validate_policy_basis(data,self.sources))
        data=copy.deepcopy(self.data);data["policy_basis"]["core_invariants"]["res://scripts/player/player_motor.gd"]="0"*64
        self.assertTrue(formal.validate_policy_basis(data,self.sources))
        self.assertTrue(formal.validate_policy_basis(self.data,{}))
        reduced=dict(self.sources);del reduced["scripts/art/plains_region_scenery.gd"]
        self.assertTrue(formal.validate_policy_basis(self.data,reduced))
    def test_legitimate_scenery_difference_preserves_full_binding(self):
        changed=dict(self.sources);changed["scripts/art/plains_region_scenery.gd"]="f"*64
        data=copy.deepcopy(self.data);data["runtime_source_hashes"]["res://scripts/art/plains_region_scenery.gd"]="f"*64
        self.assertEqual(formal.validate_policy_basis(data,changed),[])
        self.assertTrue(formal.validate_policy_basis(self.data,changed))
    def test_unknown_version_and_missing_independent_runtime_rejected(self):
        self.assertTrue(formal.validate_policy_basis({"capture_contract_version":99},self.sources))
        data=copy.deepcopy(self.data);data["runtime_source_hashes"].pop("res://scripts/player/player_motor.gd")
        self.assertTrue(formal.validate_policy_basis(data,self.sources))
    def test_explicit_command_and_unknown_policy(self):
        request=dict(source_commit="a"*40,root_seed="unit",map_index=1,strategy="fast",phase_wait_ticks=0,max_ticks=100)
        path=formal.ROOT/"build/unit.json"
        self.assertFalse(any(x.startswith("--encounter-policy") for x in formal.command_for(request,path)))
        request["encounter_policy"]="kill_from_bank_v1"
        self.assertIn("--encounter-policy=kill_from_bank_v1",formal.command_for(request,path))
        request["encounter_policy"]="pretend_all_pass"
        with self.assertRaises(ValueError):formal.command_for(request,path)


if __name__ == "__main__": unittest.main()
