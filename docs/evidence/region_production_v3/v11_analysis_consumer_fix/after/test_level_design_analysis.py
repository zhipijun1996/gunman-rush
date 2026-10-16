"""Falsifiable evidence/diagnostic cases, independent of Godot capture execution."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from level_design_analysis import analyze_capture, compare_reports, LEGACY_PLAINS_SCENERY_SHA256


def capture():
    return {
        "schema_version": 1, "source_commit": "a" * 40, "engine": "Godot 4.7.2",
        "manifests": [{"seed": "fixture", "manifest_hash": "b" * 64, "region": "forest_fixture",
                       "version": "fixture-v1", "areas": [{"id": "entry", "role": "entry"},
                       {"id": "boss", "role": "boss"}],
                       "connections": [{"id": "lane", "a": "entry", "b": "boss", "kind": "horizontal",
                                        "condition": "open", "bidirectional": True,
                                        "recipe": "arbitrary-id", "action_signature": "jump>land"}],
                       "nodes": [], "rewards": [], "enemies": []}],
        "traces": [{"seed": "fixture", "manifest_hash": "b" * 64,
                    "strategy": "fast", "scope": "motor_terrain", "enemies_instantiated": False,
                    "device": "synthetic_router", "physics_hz": 60,
                    "actions_semantics": "router_input_requests_not_accepted_action_events",
                    "capability": {"equipped_weapon": {"id": "pulse_gun"},
                                   "granted_actions": ["jump", "shot_recoil"], "tuning": {"ground_speed": 260},
                                   "shot_energy": {"current": 100}},
                    "frames": [{"tick": i, "position": [i * 4.0, 0.0], "velocity": [240.0, 0.0],
                                "grounded": True, "shots": 2, "shot_energy": 100.0,
                                "actions": [], "axis": 1.0} for i in range(181)],
                    "edges": [{"id": "lane", "forward": True, "start_tick": 0, "end_tick": 180}],
                    "failures": []}],
    }


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.data = capture()

    def codes(self, data=None, policy=None):
        return {f["code"] for f in analyze_capture(data or self.data, policy)["findings"]}

    def test_realistic_bounded_scope_never_claims_fun_pass(self):
        result = analyze_capture(self.data)
        self.assertEqual(result["verdict"], "REVIEW")
        self.assertEqual(result["subjective_quality"], "unverified")
        self.assertIn("low_interaction_candidate", self.codes())
        self.assertEqual(result["maps"][0]["topology"]["role_routes"][0]["path"], ["entry", "boss"])

    def test_required_capture_and_trace_fields_reject(self):
        mutations = [lambda d: d.update(traces=[]), lambda d: d.update(manifests=[]),
                     lambda d: d.update(source_commit="short"), lambda d: d.update(schema_version=2),
                     lambda d: d.update(engine=""), lambda d: d.update(failures=1),
                     lambda d: d["traces"][0].update(capability={}),
                     lambda d: d["traces"][0].update(frames=[]),
                     lambda d: d["traces"][0].update(edges=[]),
                     lambda d: d["traces"][0].update(seed="wrong"),
                     lambda d: d["traces"][0].update(manifest_hash="wrong"),
                     lambda d: d["traces"][0].update(failures=["hazard"]),
                     lambda d: d["traces"][0].update(actions_semantics="accepted_without_proof"),
                     lambda d: d["traces"][0]["capability"].update(equipped_weapon=["two", "guns"])]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = copy.deepcopy(self.data)
                mutate(data)
                self.assertEqual(analyze_capture(data)["verdict"], "REJECT")

    def test_invalid_frames_never_silently_pass(self):
        mutations = [dict(position=[float("nan"), 0]), dict(position=[float("inf"), 0]),
                     dict(position=[99999, 0]), dict(tick=99), dict(velocity=[0]),
                     dict(grounded="yes"), dict(axis=2), dict(shot_energy=-1), dict(shots=-1),
                     dict(actions=[{"type": "shoot", "direction": [float("nan"), 0]}]),
                     dict(safe_trace=False), dict(continuous_trace=False)]
        for change in mutations:
            with self.subTest(change=change):
                data = copy.deepcopy(self.data)
                data["traces"][0]["frames"][1].update(change)
                self.assertEqual(analyze_capture(data)["verdict"], "REJECT")

    def test_edge_evidence_errors_reject(self):
        for change in [dict(id="fake"), dict(start_tick=-1), dict(end_tick=999),
                       dict(start_tick=180), dict(forward="true"), dict(passed=False)]:
            data = copy.deepcopy(self.data)
            data["traces"][0]["edges"][0].update(change)
            self.assertEqual(analyze_capture(data)["verdict"], "REJECT")
        self.data["manifests"][0]["connections"][0]["bidirectional"] = False
        self.data["traces"][0]["edges"][0]["forward"] = False
        self.assertIn("illegal_edge_direction", self.codes())

    def test_missing_or_duplicate_evidence_rejects(self):
        self.data["manifests"].append(copy.deepcopy(self.data["manifests"][0]))
        self.assertIn("duplicate_manifest", self.codes())
        self.data = capture()
        self.data["traces"].append(copy.deepcopy(self.data["traces"][0]))
        self.assertIn("duplicate_trace", self.codes())
        self.data = capture()
        extra = copy.deepcopy(self.data["manifests"][0])
        extra["seed"] = "unrecorded"
        self.data["manifests"].append(extra)
        self.assertIn("manifest_without_trace", self.codes())

    def test_graph_unreachable_and_return_are_not_physics_claims(self):
        self.assertNotIn("unreachable_areas", self.codes())
        m = self.data["manifests"][0]
        m["areas"].append({"id": "hidden", "role": "challenge_reward"})
        m["connections"].append({"id": "lock", "a": "entry", "b": "hidden", "condition": "hook", "kind": "stairs", "bidirectional": True})
        result = analyze_capture(self.data)
        self.assertEqual(result["verdict"], "REVIEW")
        self.assertIn("unreachable_areas", self.codes())
        self.assertIn("no_open_return", self.codes())
        self.assertEqual(result["maps"][0]["topology"]["restricted_edges"], [{"id": "lock", "condition": "hook"}])
        m["connections"][0]["b"] = "nonexistent"
        self.assertEqual(analyze_capture(self.data)["verdict"], "REJECT")

    def test_interaction_and_observation_are_distinguished(self):
        self.assertIn("low_interaction_candidate", self.codes())
        for frame in self.data["traces"][0]["frames"]:
            if frame["tick"] % 30 == 0:
                frame["actions"] = [{"type": "jump", "direction": [0, 0]}]
        # Submitted requests may be rejected; they cannot erase idle diagnostics.
        self.assertIn("low_interaction_candidate", self.codes())
        self.assertEqual(analyze_capture(self.data)["routes"][0]["action_signature"]["descriptor"], [[]])
        for frame in self.data["traces"][0]["frames"]:
            if frame["tick"] % 30 == 0:
                frame["grounded"] = False
        self.assertNotIn("low_interaction_candidate", self.codes())
        # Waiting at an observation point is not reported as grounded walking.
        for frame in self.data["traces"][0]["frames"]:
            frame.update(axis=0, position=[0, 0], velocity=[0, 0], grounded=True, actions=[])
        self.assertNotIn("low_interaction_candidate", self.codes())

    def test_requests_are_not_accepted_actions_and_capacity_is_not_counter(self):
        t = self.data["traces"][0]
        t["frames"][5]["actions"] = [{"type": "jump", "direction": [0, 0]}]
        t["frames"][10]["shots"] = 1
        result = analyze_capture(self.data)
        self.assertEqual(result["verdict"], "REVIEW")
        edge = result["routes"][0]["edges"][0]
        self.assertNotIn("jump", edge["actual_action_signature"]["descriptor"])
        self.assertEqual(edge["input_request_signature"]["descriptor"][0]["type"], "jump")
        self.assertIn("air_shot_capacity_spent", edge["actual_action_signature"]["descriptor"])

    def test_grounded_energy_effect_interrupts_low_interaction_without_air_shot_spend(self):
        t = self.data["traces"][0]
        for frame in t["frames"]:
            frame["shot_energy"] = 100 - (frame["tick"] // 30) * 10
        result = analyze_capture(self.data)
        self.assertNotIn("low_interaction_candidate", {f["code"] for f in result["findings"]})
        self.assertIn("shot_energy_spent", result["routes"][0]["edges"][0]["actual_action_signature"]["descriptor"])
        self.assertEqual(result["routes"][0]["stats"]["observed_air_shot_capacity_spent"], 0)

    def test_skin_id_and_translation_do_not_create_new_actions(self):
        original = analyze_capture(self.data)
        self.data["manifests"][0]["connections"][0]["recipe"] = "different_skin"
        for frame in self.data["traces"][0]["frames"]:
            frame["position"][0] += 5000
        changed = analyze_capture(self.data)
        self.assertEqual(original["routes"][0]["action_signature"], changed["routes"][0]["action_signature"])
        self.assertEqual(original["routes"][0]["intent_signature"], changed["routes"][0]["intent_signature"])

    def test_static_join_and_consumer_projection_are_scoped(self):
        m = self.data["manifests"][0]
        m["nodes"] = [{"id": "join", "module_id": "region_connection", "geometry": {"platforms": [[0, 0, 500, 32]]}}]
        self.assertIn("static_join_candidate", self.codes())
        m["nodes"][0]["geometry"]["platforms"][0][2] = 50
        self.assertNotIn("static_join_candidate", self.codes())
        m["areas"][0]["landmark"] = "ivy"
        self.assertNotIn("scenery_identity_fold", self.codes())
        m.update(region="plains", version="plains-region-v8")
        self.data["capture_source_hashes"] = {"res://scripts/art/plains_region_scenery.gd": LEGACY_PLAINS_SCENERY_SHA256}
        self.assertIn("scenery_identity_fold", self.codes())
        m["areas"][0]["landmark"] = "windmill"
        self.assertNotIn("scenery_identity_fold", self.codes())

    def test_pressure_is_explicit_design_intent(self):
        self.assertNotIn("continuous_pressure_intent", self.codes())
        self.data["manifests"][0]["connections"][0]["pressure"] = "timing"
        result = analyze_capture(self.data, {"pressure_intent_seconds": 2})
        finding = next(f for f in result["findings"] if f["code"] == "continuous_pressure_intent")
        self.assertEqual(finding["evidence_kind"], "design_intent_on_recorded_route")

    def test_plains_versions_are_explicit_without_old_projection_on_v9(self):
        manifest = self.data["manifests"][0]
        self.data["capture_source_hashes"] = {"res://scripts/art/plains_region_scenery.gd": LEGACY_PLAINS_SCENERY_SHA256}
        manifest["areas"][0]["landmark"] = "ivy"
        for version in ("plains-region-v8", "plains-region-v9", "plains-region-v10"):
            manifest.update(region="plains", version=version)
            report = analyze_capture(self.data)
            self.assertNotIn("unsupported_plains_version", {f["code"] for f in report["findings"]})
            self.assertEqual("scenery_projection" in report["maps"][0], version == "plains-region-v8")
        manifest["version"] = "plains-region-v999"
        report = analyze_capture(self.data)
        self.assertEqual(report["verdict"], "REJECT")
        self.assertIn("unsupported_plains_version", {f["code"] for f in report["findings"]})

    def test_legacy_projection_requires_observed_original_consumer_source(self):
        manifest=self.data["manifests"][0]
        manifest.update(region="plains",version="plains-region-v8")
        manifest["areas"][0]["landmark"]="ivy"
        for hashes in ({}, {"res://scripts/art/plains_region_scenery.gd":"f"*64},
                       {"res://another_consumer.gd":LEGACY_PLAINS_SCENERY_SHA256}):
            with self.subTest(hashes=hashes):
                self.data["capture_source_hashes"]=hashes
                report=analyze_capture(self.data)
                self.assertNotIn("scenery_projection",report["maps"][0])
                self.assertNotIn("scenery_identity_fold",{f["code"] for f in report["findings"]})
                if "res://scripts/art/plains_region_scenery.gd" not in hashes:
                    self.assertIn("scenery_consumer_identity_unknown",{f["code"] for f in report["findings"]})
        self.data["capture_source_hashes"]={"scripts/art/plains_region_scenery.gd":LEGACY_PLAINS_SCENERY_SHA256}
        self.assertIn("scenery_identity_fold",self.codes())
        manifest.update(region="forest_fixture")
        self.assertNotIn("scenery_identity_fold",self.codes())

    def test_repeated_observed_chain_and_revisit_diagnostics(self):
        t = self.data["traces"][0]
        t["edges"] = [{"id": "lane", "forward": i % 2 == 0, "start_tick": i * 60, "end_tick": (i + 1) * 60} for i in range(3)]
        for i in [10, 70, 130]:
            t["frames"][i]["grounded"] = False
        result = analyze_capture(self.data)
        self.assertIn("repeated_actual_action_chain", {f["code"] for f in result["findings"]})
        self.assertEqual(result["routes"][0]["stats"]["revisits"], 2)
        t["edges"] = t["edges"][:1]
        self.assertNotIn("repeated_actual_action_chain", self.codes())

    def test_aggregate_challenge_requires_actual_area_and_both_connections(self):
        m = self.data["manifests"][0]
        m["areas"].append({"id": "trial", "role": "challenge_reward"})
        m["connections"] = [{"id": "in", "a": "entry", "b": "trial", "kind": "challenge", "condition": "open", "bidirectional": False},
                            {"id": "out", "a": "trial", "b": "boss", "kind": "drop", "condition": "open", "bidirectional": False}]
        self.data["traces"][0]["edges"][0].update(id="trial", kind="challenge_and_evacuation")
        result = analyze_capture(self.data)
        self.assertEqual(result["verdict"], "REVIEW")
        self.assertEqual(result["routes"][0]["edges"][0]["aggregate_connections"], ["in", "out"])
        m["connections"].pop()
        self.assertIn("invalid_trace_edge", self.codes())

    def test_invalid_policy_and_scope_rejected(self):
        for policy in [[], {"id": ""}, {"low_interaction_seconds": 0}, {"biome": "ice"}, {"device": "phone"}, {"static_join_distance": float("inf")}]:
            self.assertEqual(analyze_capture(self.data, policy)["verdict"], "REJECT")

    def test_endpoint_resource_and_malformed_identity_evidence_rejected(self):
        m = self.data["manifests"][0]
        m["areas"][0]["position"] = [0, 0]
        m["areas"][1]["position"] = [720, 0]
        self.assertEqual(analyze_capture(self.data)["verdict"], "REVIEW")
        m["areas"][1]["position"] = [5000, 0]
        self.assertIn("edge_position_mismatch", self.codes())
        self.data = capture()
        self.data["traces"][0]["capability"].update(air_shot_flight_cap=1)
        self.assertIn("resource_capacity_exceeded", self.codes())
        self.data = capture()
        self.data["traces"][0]["seed"] = ["not-a-string"]
        self.assertEqual(analyze_capture(self.data)["verdict"], "REJECT")
        self.assertEqual(compare_reports({"routes": [None]}, {})["verdict"], "REJECT")

    def test_recorded_edges_must_form_a_continuous_itinerary(self):
        t = self.data["traces"][0]
        t["edges"] = [{"id": "lane", "forward": True, "start_tick": 0, "end_tick": 60},
                      {"id": "lane", "forward": True, "start_tick": 61, "end_tick": 180}]
        self.assertIn("disconnected_recorded_itinerary", self.codes())
        t["edges"][1]["forward"] = False
        self.assertNotIn("disconnected_recorded_itinerary", self.codes())

    def test_compare_requires_exact_strategy_capability_resources_device_policy(self):
        original = analyze_capture(self.data)
        self.assertEqual(compare_reports(original, original)["verdict"], "REVIEW")
        for key, value in [("strategy", "tour"), ("device", "phone"), ("physics_hz", 30), ("seed", "other"),
                           ("scope", "with_enemies"), ("enemies_instantiated", True),
                           ("capability", {"different": True})]:
            changed = copy.deepcopy(original)
            changed["routes"][0][key] = value
            self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT")
        changed = copy.deepcopy(original)
        changed["policy"]["id"] = "changed"
        self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT")
        changed_capture = copy.deepcopy(self.data)
        changed_capture["manifests"][0]["manifest_hash"] = "c" * 64
        changed_capture["traces"][0]["manifest_hash"] = "c" * 64
        changed = analyze_capture(changed_capture)
        result = compare_reports(original, changed)
        self.assertEqual(result["verdict"], "REVIEW")
        self.assertTrue(result["routes"][0]["manifest_changed"])

    def test_compare_rejects_empty_truncated_and_modified_reports(self):
        original = analyze_capture(self.data)
        shells = [{}, {"verdict": "REVIEW"}, {"verdict": "REVIEW", "routes": [
            {"stats": {}, "action_signature": {"descriptor": []}}]}]
        for shell in shells:
            self.assertEqual(compare_reports(shell, shell)["verdict"], "REJECT")
        for field in ("producer", "source_commit", "engine", "maps", "routes", "policy", "findings", "source_basis", "capture_source_hashes", "report_fingerprint"):
            changed = copy.deepcopy(original)
            changed.pop(field)
            self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT", field)
        for field in ("stats", "capability", "device", "physics_hz", "scope", "edges", "manifest_hash", "action_signature"):
            changed = copy.deepcopy(original)
            changed["routes"][0].pop(field)
            self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT", field)
        mutations = [lambda r: r["routes"][0]["stats"].update(distance=1),
                     lambda r: r["routes"][0]["stats"].update(frame_count="181"),
                     lambda r: r["routes"][0]["action_signature"].update(sha256="0" * 64),
                     lambda r: r["routes"][0]["action_signature"].update(descriptor=[]),
                     lambda r: r["maps"][0]["structure_signature"].update(sha256="0" * 64),
                     lambda r: r.update(verdict="REJECT"),
                     lambda r: r["findings"][0].update(severity="error")]
        for mutate in mutations:
            changed = copy.deepcopy(original)
            mutate(changed)
            self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT")

    def test_compare_validates_structure_beyond_content_fingerprint(self):
        import hashlib
        original = analyze_capture(self.data)
        # Recomputing a digest cannot make a structurally empty report valid.
        for mutate in [lambda r: r.update(maps=[]), lambda r: r["routes"][0].update(stats={}),
                       lambda r: r["routes"][0]["stats"].update(frame_count=2),
                       lambda r: r["routes"][0]["action_signature"].update(sha256="0" * 64)]:
            changed = copy.deepcopy(original)
            mutate(changed)
            changed.pop("report_fingerprint")
            changed["report_fingerprint"] = hashlib.sha256(json.dumps(changed, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()
            self.assertEqual(compare_reports(original, changed)["verdict"], "REJECT")

    def test_comparison_source_change_includes_dirty_tree_basis_and_hashes(self):
        original = analyze_capture(self.data)
        for extra in [{"source_basis": "a" * 64}, {"capture_source_hashes": {"tools/capture.gd": "b" * 64}}]:
            changed_capture = copy.deepcopy(self.data)
            changed_capture.update(extra)
            result = compare_reports(original, analyze_capture(changed_capture))
            self.assertEqual(result["verdict"], "REVIEW")
            self.assertTrue(result["source_changed"])

    def test_reproducible_synthetic_before_after_demo(self):
        """Writes a diagnostic rehearsal only; neither fixture is Motor evidence."""
        root = Path(__file__).resolve().parents[1]
        source = root / "tests/fixtures/level_design_v2"
        before_capture = json.loads((source / "analysis_before.json").read_text())
        after_capture = json.loads((source / "analysis_after.json").read_text())
        for data in (before_capture, after_capture):
            self.assertTrue(data["synthetic_fixture"])
            self.assertEqual(data["traces"][0]["scope"], "synthetic_fixture_not_motor_proof")
            self.assertEqual(data["manifests"][0]["region"], "future_forest_fixture")
        before = analyze_capture(before_capture)
        after = analyze_capture(after_capture)
        comparison = compare_reports(before, after)
        self.assertEqual(before["verdict"], "REVIEW")
        self.assertEqual(after["verdict"], "REVIEW")
        self.assertEqual(comparison["verdict"], "REVIEW")
        delta = comparison["routes"][0]
        self.assertEqual(delta["stats_delta"]["low_interaction_candidates"], -1)
        self.assertTrue(delta["actual_action_changed"])
        self.assertTrue(delta["manifest_changed"])
        self.assertEqual(comparison["subjective_quality"], "unverified")
        cosmetic = copy.deepcopy(before_capture)
        cosmetic["manifests"][0]["manifest_hash"] = "d" * 64
        cosmetic["traces"][0]["manifest_hash"] = "d" * 64
        cosmetic["manifests"][0]["skin"] = "another_texture"
        cosmetic_comparison = compare_reports(before, analyze_capture(cosmetic))
        self.assertFalse(cosmetic_comparison["routes"][0]["actual_action_changed"])
        self.assertEqual(cosmetic_comparison["routes"][0]["stats_delta"]["low_interaction_candidates"], 0)
        output = root / "build/level_design_v2/analysis_demo"
        output.mkdir(parents=True, exist_ok=True)
        for name, result in [("before_report", before), ("after_report", after),
                             ("comparison", comparison), ("cosmetic_comparison", cosmetic_comparison)]:
            (output / (name + ".json")).write_text(json.dumps(result, indent=2) + "\n")


    def plains_v11_capture(self):
        data = copy.deepcopy(self.data)
        manifest = data['manifests'][0]
        manifest.update(region='plains', version='plains-region-v11-root-bell-v2',
                        root_bell_admission={'version': 'root-bell-encounter-v2', 'status': 'no_physically_qualified_lane', 'replaced': 0})
        data['scope'] = 'formal_manifest_and_assembler_shotlatch_traces_not_enemy_or_boss_completion'
        for trace in data['traces']:
            trace.update(scope='assembler_shotlatch_without_enemies_or_boss_fight', enemies_instantiated=False)
        data['formal_run_manifest'] = {'versions': {'generated_layout': manifest['version'], 'encounters': manifest['version']},
            'stages': [{'outputs': {'stage_generator': {'version': manifest['version']},
                                   'enemy_layout': {'version': manifest['version'], 'enemies': []},
                                   'generated_layout': copy.deepcopy(manifest)}}]}
        return data

    def test_explicit_supported_versions_cover_current_generator_literals(self):
        import re
        from unittest.mock import patch
        import level_design_analysis as analysis
        root = Path(__file__).resolve().parents[1]
        known = set()
        for name, constant in [('scripts/generation/plains_region_generator.gd', 'VERSION'),
                               ('scripts/generation/plains_root_bell_encounter_v2.gd', 'CONTENT_VERSION')]:
            match = re.search(r'^const ' + constant + r'\s*:?=\s*"([^"\n]+)"', (root / name).read_text(), re.M)
            self.assertIsNotNone(match, 'Current implemented version must remain an explicit audited literal')
            known.add(match.group(1))
        def require_coverage():
            self.assertTrue(known.issubset(set(analysis.SUPPORTED_PLAINS_VERSIONS)),
                            'Current generator version needs an explicit analysis adapter and review')
        require_coverage()
        # A real local fault injection into the finite consumer list, not native evidence.
        with patch.object(analysis, 'SUPPORTED_PLAINS_VERSIONS', ('plains-region-v8', 'plains-region-v9')):
            with self.assertRaises(AssertionError):
                require_coverage()
            self.assertEqual(analyze_capture(self.plains_v11_capture())['verdict'], 'REJECT')

    def test_v11_explicit_contract_is_review_without_legacy_projection_or_combat_claim(self):
        data = self.plains_v11_capture()
        report = analyze_capture(data)
        self.assertEqual(report['verdict'], 'REVIEW')
        self.assertEqual(report['subjective_quality'], 'unverified')
        self.assertNotIn('scenery_projection', report['maps'][0])
        self.assertFalse(report['routes'][0]['enemies_instantiated'])
        self.assertTrue(any('do not validate RootBell combat' in x for x in report['limitations']))
        data['manifests'][0]['version'] = 'plains-region-v12'
        self.assertEqual(analyze_capture(data)['verdict'], 'REJECT')
        self.assertIn('unsupported_plains_version', self.codes(data))

    def test_v11_mixed_formal_versions_and_downgrade_are_rejected(self):
        for field in ['root', 'stage', 'enemy', 'generated', 'downgrade']:
            with self.subTest(field=field):
                data = self.plains_v11_capture()
                outputs = data['formal_run_manifest']['stages'][0]['outputs']
                if field == 'root': data['formal_run_manifest']['versions']['encounters'] = 'plains-region-v10'
                elif field == 'stage': outputs['stage_generator']['version'] = 'plains-region-v10'
                elif field == 'enemy': outputs['enemy_layout']['version'] = 'plains-region-v10'
                elif field == 'generated': outputs['generated_layout']['version'] = 'plains-region-v10'
                else: data['manifests'][0]['version'] = 'plains-region-v10'
                self.assertEqual(analyze_capture(data)['verdict'], 'REJECT')
                self.assertIn('plains_v11_contract', self.codes(data))

    def test_v11_missing_or_tampered_formal_binding_and_admission_are_rejected(self):
        mutations = [lambda d: d.pop('formal_run_manifest'),
                     lambda d: d['formal_run_manifest'].update(stages=[]),
                     lambda d: d['manifests'][0]['root_bell_admission'].update(version='future-admission'),
                     lambda d: d['manifests'][0]['root_bell_admission'].update(replaced=1),
                     lambda d: d['manifests'][0]['root_bell_admission'].update(replaced=True),
                     lambda d: d['manifests'][0]['connections'][0].update(recipe='tampered-only-analysis-side'),
                     lambda d: d['formal_run_manifest']['stages'][0]['outputs']['enemy_layout'].update(enemies=[{'id': 'forged'}]),
                     lambda d: d['traces'][0].update(enemies_instantiated=True),
                     lambda d: d['traces'][0].update(scope='claimed_full_combat'),
                     lambda d: d.update(scope='claimed_full_campaign')]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = self.plains_v11_capture()
                mutate(data)
                self.assertEqual(analyze_capture(data)['verdict'], 'REJECT')

    def test_v11_single_root_record_binds_its_declared_lane(self):
        data = self.plains_v11_capture()
        m = data['manifests'][0]
        m['nodes'] = [{'id': 'join', 'module_id': 'region_connection'}]
        m['enemies'] = [{'id': 'enemy', 'area': 'join', 'behavior_id': 'root_bell', 'pattern': 'ground_mark_interrupt',
                         'aerial': False, 'patrol_radius': 0, 'position': [10, 0]}]
        m['root_bell_admission'].update(status='one_candidate', replaced=1, id='enemy', module='join')
        output = data['formal_run_manifest']['stages'][0]['outputs']
        output['generated_layout'] = copy.deepcopy(m)
        output['enemy_layout']['enemies'] = copy.deepcopy(m['enemies'])
        self.assertEqual(analyze_capture(data)['verdict'], 'REVIEW')
        # Actual Godot RunManifest JSON roundtrip represents this count as 1.0.
        m['root_bell_admission']['replaced'] = 1.0
        output['generated_layout'] = copy.deepcopy(m)
        self.assertEqual(analyze_capture(data)['verdict'], 'REVIEW')
        for change in [dict(aerial=True), dict(patrol_radius=False), dict(area='not-the-lane'), dict(pattern='unknown')]:
            with self.subTest(change=change):
                bad = copy.deepcopy(data)
                bad['manifests'][0]['enemies'][0].update(change)
                bad_output = bad['formal_run_manifest']['stages'][0]['outputs']
                bad_output['generated_layout'] = copy.deepcopy(bad['manifests'][0])
                bad_output['enemy_layout']['enemies'] = copy.deepcopy(bad['manifests'][0]['enemies'])
                self.assertEqual(analyze_capture(bad)['verdict'], 'REJECT')

    def test_v11_missing_identity_and_duplicate_lane_cannot_match_none(self):
        for mutation in ['all_missing', 'empty_strings', 'duplicate_lane']:
            with self.subTest(mutation=mutation):
                data = self.plains_v11_capture()
                m = data['manifests'][0]
                m['nodes'] = [{'id': 'join', 'module_id': 'region_connection'}]
                m['enemies'] = [{'id': 'enemy', 'area': 'join', 'behavior_id': 'root_bell',
                                 'pattern': 'ground_mark_interrupt', 'aerial': False,
                                 'patrol_radius': 0, 'position': [10, 0]}]
                m['root_bell_admission'].update(status='one_candidate', replaced=1, id='enemy', module='join')
                if mutation == 'all_missing':
                    for key in ['id', 'area']: m['enemies'][0].pop(key)
                    for key in ['id', 'module']: m['root_bell_admission'].pop(key)
                    m['nodes'][0].pop('id')
                elif mutation == 'empty_strings':
                    m['enemies'][0].update(id=' ', area=' ')
                    m['root_bell_admission'].update(id=' ', module=' ')
                    m['nodes'][0]['id'] = ' '
                else: m['nodes'].append(copy.deepcopy(m['nodes'][0]))
                output = data['formal_run_manifest']['stages'][0]['outputs']
                output['generated_layout'] = copy.deepcopy(m)
                output['enemy_layout']['enemies'] = copy.deepcopy(m['enemies'])
                self.assertEqual(analyze_capture(data)['verdict'], 'REJECT')
                self.assertIn('plains_v11_contract', self.codes(data))


if __name__ == "__main__":
    unittest.main()
