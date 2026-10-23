"""Contract counterexamples: declarations must not masquerade as play evidence."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("level_content_contract", ROOT / "tools/level_content_contract.py")
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)


def record(cid="a", layer="module"):
    return contract.make_content(cid, layer, "windchime_plains", "source.tres", "a" * 40,
                                 hashlib.sha256(b"source").hexdigest())


def bundle(*contents):
    return {"schema_version": 1, "artifact_kind": "level_content_bundle", "capability_catalog": ["jump", "grapple"],
            "contents": list(contents or [record()]), "connections": []}


def port(pid, direction):
    return {"id": pid, "direction": direction, "position": [0, 0], "velocity_x": [0, 10], "velocity_y": [0, 0],
            "states": ["grounded"], "resources": {"energy": [5, 10]}, "capabilities": ["jump"],
            "phase": "", "coordinate_frame": "world"}


class ContentContractTests(unittest.TestCase):
    def test_unassessed_import_is_valid_and_does_not_grant_admission(self):
        value = bundle()
        self.assertEqual([], contract.validate_bundle(value))
        self.assertEqual("candidate", value["contents"][0]["quality"]["admission"])
        self.assertEqual("unverified", value["contents"][0]["evidence"]["technical"]["status"])

    def test_future_schema_and_unknown_field_rejected(self):
        value = bundle()
        value["schema_version"] = 2
        self.assertTrue(contract.validate_bundle(value))
        value["schema_version"] = 1
        value["contents"][0]["fun_proven"] = True
        self.assertTrue(contract.validate_bundle(value))

    def test_macro_is_optional_and_map_can_directly_reference_cell_and_module(self):
        cell, module, world = record("cell", "cell"), record("module"), record("world", "map")
        world["identity"]["composition_status"] = "decomposed"
        world["parts"] = [{"id": x["id"], "content_id": x["id"], "layer": x["layer"], "version": 1,
                           "offset": [0, 0]} for x in (cell, module)]
        self.assertEqual([], contract.validate_bundle(bundle(cell, module, world)))

    def test_composition_cycle_and_missing_child_are_rejected(self):
        content = record()
        content["parts"] = [{"id": "self", "content_id": "a", "layer": "module", "version": 1, "offset": [0, 0]}]
        self.assertTrue(contract.validate_bundle(bundle(content)))
        content["parts"][0].update(content_id="missing", layer="cell")
        self.assertTrue(contract.validate_bundle(bundle(content)))

    def test_external_part_requires_actual_source_digest(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "source.tres").write_bytes(b"source")
            value = bundle()
            value["contents"][0]["parts"] = [{"id": "external", "content_id": "external-cell", "layer": "cell",
                                               "version": 1, "offset": [0, 0],
                                               "source": {"path": "source.tres", "sha256": hashlib.sha256(b"source").hexdigest()}}]
            self.assertEqual([], contract.validate_bundle(value, root))
            value["contents"][0]["parts"][0]["source"]["sha256"] = "0" * 64
            self.assertTrue(any("hash mismatch" in e for e in contract.validate_bundle(value, root)))

    def test_artifact_traversal_and_symlink_escape_rejected(self):
        value = bundle()
        value["contents"][0]["provenance"]["artifacts"][0]["path"] = "../source.tres"
        self.assertTrue(contract.validate_bundle(value))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "repo"
            root.mkdir()
            outside = Path(temp) / "source.tres"
            outside.write_bytes(b"source")
            (root / "source.tres").symlink_to(outside)
            self.assertTrue(contract.validate_bundle(bundle(), root))

    def test_empty_or_group_unknown_capability_and_partial_semantics(self):
        value = bundle()
        req = value["contents"][0]["requirements"]
        req.update(status="partial", any_of_groups=[[]])
        self.assertTrue(contract.validate_bundle(value))
        req["any_of_groups"] = [["flight"]]
        self.assertTrue(contract.validate_bundle(value))
        req["any_of_groups"] = [["jump", "grapple"]]
        self.assertEqual([], contract.validate_bundle(value))
        req["status"] = "unspecified"
        self.assertTrue(contract.validate_bundle(value))

    def test_ungranted_ability_lock_cannot_be_self_granted(self):
        value = bundle(record("map", "map"))
        topology = value["contents"][0]["topology"]
        req = copy.deepcopy(value["contents"][0]["requirements"])
        req.update(status="defined", all_of=["grapple"])
        topology.update(nodes=["entry", "goal"], entry=["entry"], goals=["goal"], available_capabilities=["jump"],
                        edges=[{"from": "entry", "to": "goal", "role": "main", "requirements": req,
                                "grants": ["grapple"], "risk_reward": ""}])
        self.assertTrue(any("ungranted" in e for e in contract.validate_bundle(value)))
        topology["available_capabilities"].append("grapple")
        self.assertEqual([], contract.validate_bundle(value))

    def test_action_cycle_and_dangling_interaction_rejected(self):
        value = bundle()
        design = value["contents"][0]["design"]
        design["actions"] = [{"id": "jump", "verb": "jump", "target": "", "depends_on": ["jump"],
                              "decision": "", "success": "landed", "failure": "fall"}]
        self.assertTrue(contract.validate_bundle(value))
        design["actions"][0]["depends_on"] = []
        design["interactions"] = [{"from": "jump", "to": "unknown", "relation": "opens"}]
        self.assertTrue(contract.validate_bundle(value))

    def test_multiport_connection_checks_full_exit_envelope(self):
        a, b = record("a"), record("b")
        a["ports"] = [port("out", "exit"), port("reward-return", "both")]
        b["ports"] = [port("in", "entry"), port("alternate", "entry")]
        value = bundle(a, b)
        value["connections"] = [{"from": {"content": "a", "port": "out", "offset": [20, 0]},
                                 "to": {"content": "b", "port": "in", "offset": [20, 0]}}]
        self.assertEqual([], contract.validate_bundle(value))
        a["ports"][0]["velocity_x"] = [0, 11]
        self.assertTrue(any("velocity" in e for e in contract.validate_bundle(value)))
        a["ports"][0]["velocity_x"] = [0, 10]
        a["ports"][0]["resources"]["energy"] = [4, 10]
        self.assertTrue(any("resources" in e for e in contract.validate_bundle(value)))
        a["ports"][0]["resources"]["energy"] = [5, 10]
        b["ports"][0]["capabilities"].append("grapple")
        self.assertTrue(any("ungranted" in e for e in contract.validate_bundle(value)))

    def test_nonfinite_and_reversed_state_bounds_rejected(self):
        value = bundle()
        value["contents"][0]["ports"] = [port("in", "entry")]
        value["contents"][0]["ports"][0]["velocity_x"] = [5, 1]
        self.assertTrue(contract.validate_bundle(value))
        value["contents"][0]["ports"][0]["velocity_x"] = [0, float("inf")]
        self.assertTrue(contract.validate_bundle(value))

    def test_fake_pass_labels_and_ai_review_cannot_grant_human_or_formal_status(self):
        value = bundle()
        content = value["contents"][0]
        content["evidence"]["technical"].update(status="passed", method="real_motor")
        self.assertTrue(any("real Motor" in e for e in contract.validate_bundle(value)))
        content["evidence"]["technical"]["status"] = "unverified"
        content["evidence"]["ai"].update(status="reviewed", reviewer="AI", findings=["清晰起手，落点未知"])
        self.assertEqual([], contract.validate_bundle(value))
        content["evidence"]["human"]["status"] = "accepted"
        self.assertTrue(contract.validate_bundle(value))
        content["evidence"]["human"]["status"] = "unverified"
        content["quality"]["admission"] = "formal"
        self.assertTrue(contract.validate_bundle(value))

    def test_technical_artifact_hash_and_observations_are_required(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "source.tres").write_bytes(b"source")
            value = bundle()
            target = root / "native.json"
            target.write_text(json.dumps({"passed": True}))
            evidence = value["contents"][0]["evidence"]["technical"]
            evidence.update(status="passed", method="real_motor", artifacts=[{"path": "native.json", "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}])
            self.assertTrue(contract.validate_bundle(value, root))

    def test_published_json_schema_is_same_machine_vocabulary(self):
        self.assertEqual(contract.SCHEMA, json.loads((ROOT / "docs/ai_level_design_v1/content.schema.json").read_text()))

    def test_native_receipt_identity_input_and_terminal_counterexamples(self):
        # Synthetic unit data exercises only the receipt reader. It is never a
        # gameplay result or production evidence, even when its shape is valid.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "config").mkdir()
            (root / "tools").mkdir()
            (root / "source.tres").write_bytes(b"source")
            producer = root / "tools/level_pilot_validate.gd"
            producer.write_bytes(b"unit-format-fixture-not-godot")
            tuning_file = root / "config/player_tuning.json"
            tuning_file.write_text("{}")
            selected = {"id": "a", "strategies": ["main", "reward", "direct", "no_jump"]}
            catalog_file = root / "config/custom-pilot.json"
            catalog_file.write_text(json.dumps({"candidates": [selected]}))
            sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
            frame = {"frame": 1, "motion_steps": 1, "grounded": True, "requested_actions": [],
                     "accepted_actions": [], "shots": 2, "stamina": 100, "position": [10, 0], "velocity": [0, 0]}
            native = {"schema_version": 1, "id": "a", "candidate": "a", "strategy": "main", "condition": "main", "variant": 0,
                      "exit_code": 0, "failures": [], "danger_contacts": [], "passed": True, "ok": True, "real_motor": True,
                      "driver_reached": True, "actual_goal": True, "entry_contract": True, "exit_contract": True,
                      "audio_released": True, "midroute_injection": False, "resource_override": False,
                      "manual_motor_step": False, "manual_controller_tick": True, "production_pool": False,
                      "source_fingerprint": "b" * 64, "scope": contract.PILOT_SCOPE,
                      "runtime_consumer": "scripts/generation/platforming_module.gd", "frames": [frame],
                      "catalog_path": "config/custom-pilot.json", "catalog_sha256": sha(catalog_file),
                      "source_hash": sha(producer), "tuning": {"source_sha256": sha(tuning_file)},
                      "routes": {"main": [0]}, "anchors": [[10, 0]]}
            identity = {"catalog_item": selected, "candidate": "a", "strategy": "main", "variant": 0, "tuning": native["tuning"]}
            native["input_fingerprint"] = hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=False,
                                                                    separators=(",", ":")).encode()).hexdigest()
            value = bundle()
            content = value["contents"][0]
            content["runtime"]["consumer"] = native["runtime_consumer"]
            content["provenance"]["artifacts"].append({"path": "tools/level_pilot_validate.gd", "sha256": sha(producer)})
            evidence = content["evidence"]["technical"]
            evidence.update(status="passed", method="real_motor", scope=contract.PILOT_SCOPE)
            target = root / "native.json"

            def check(data):
                target.write_text(json.dumps(data))
                evidence["artifacts"] = [{"path": "native.json", "sha256": sha(target)}]
                # This fixture isolates the native-format reader. Complete
                # current-runtime ledger binding has its own negative controls.
                with patch.object(contract, '_current_ledger', return_value=True):
                    return contract.validate_bundle(value, root)

            self.assertEqual([], check(native))
            mutations = [
                ("other candidate", lambda d: d.update(id="other", candidate="other")),
                ("wrong input", lambda d: d.update(input_fingerprint="0" * 64)),
                ("wrong consumer", lambda d: d.update(runtime_consumer="scripts/other.gd")),
                ("formal scope", lambda d: d.update(scope="formal_map")),
                ("failed raw", lambda d: d.update(exit_code=1, passed=False)),
                ("dirty terminal", lambda d: d.update(audio_released=False)),
                ("wrong motor count", lambda d: d["frames"][0].update(motion_steps=2)),
                ("unobserved input", lambda d: d["frames"][0].pop("requested_actions")),
                ("wrong terminal", lambda d: d["frames"][0].update(position=[50, 0])),
                ("not grounded", lambda d: d["frames"][0].update(grounded=False)),
                ("resource injection", lambda d: d.update(resource_override=True)),
                ("wrong catalog path", lambda d: d.update(catalog_path="../custom.json")),
            ]
            for label, mutate in mutations:
                with self.subTest(label=label):
                    changed = copy.deepcopy(native)
                    mutate(changed)
                    self.assertTrue(check(changed))
            self.assertEqual([], check(native))
            catalog_file.write_text(json.dumps({"candidates": [{**selected, "extra": "changed input"}]}))
            self.assertTrue(check(native))

    def test_current_source_pass_requires_exact_outer_ledger_and_complete_inventory(self):
        import sys
        sys.path.insert(0, str(ROOT / 'tools'))
        import level_content_pilot as pilot
        from level_content import digest
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            native = root / 'native.json'
            native.write_text('{"format_test_only":true}')
            ledger = root / 'receipt.json'
            request = {'candidate': 'a', 'strategy': 'main', 'variant': 0}
            source = {'scripts/player/player_controller.gd': 'a' * 64, 'tools/godot.sh': 'b' * 64}
            receipt = {'runtime_source': source, 'request': request,
                       'source_fingerprint': digest(source), 'raw_path': 'native.json',
                       'raw_sha256': hashlib.sha256(native.read_bytes()).hexdigest(), 'technical_pass': True}
            ledger.write_text(json.dumps(receipt))
            with patch.object(pilot, 'snapshot', return_value=source), patch.object(pilot, 'cached_valid', return_value=True):
                self.assertFalse(contract._current_ledger(native, [native], root))
                self.assertTrue(contract._current_ledger(native, [native, ledger], root))
            with patch.object(pilot, 'snapshot', return_value={**source, 'scripts/new_dependency.gd': 'c' * 64}), patch.object(pilot, 'cached_valid', return_value=True):
                self.assertFalse(contract._current_ledger(native, [native, ledger], root))
            with patch.object(pilot, 'snapshot', return_value={**source, 'scripts/player/player_controller.gd': 'c' * 64}), patch.object(pilot, 'cached_valid', return_value=True):
                self.assertFalse(contract._current_ledger(native, [native, ledger], root))


if __name__ == "__main__":
    unittest.main()
