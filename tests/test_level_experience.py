"""Diagnostic counterexamples use explicit synthetic data, never Motor proof."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
import level_experience as experience


def synthetic_capture():
    scope={k:True for k in ("enemies_instantiated","enemy_attacks_enabled","enemy_contacts_enabled","environment_damage_enabled","production_camera_enabled","production_rewards_enabled")}
    scope.update({k:False for k in ("controller_manual_step","actor_teleport_by_driver","resource_injection","enemy_disable")})
    cap={"equipped_weapon":{"id":"fixture_single"},"config_hashes":{"fixture":"a"*64},"granted_actions":["jump","shot_recoil"]}
    frames=[dict(tick=i,position=[i*10.,0.],velocity=[10.,0.],grounded=True,axis=1.,health=3.,shot_energy=100.,shots=2,
                 shot_cooldown=0.,recovery_count=0,edge="edge",accepted_events=[],input_requests=[]) for i in range(1,181)]
    return dict(schema_version=1,artifact_kind="formal_level_capture",capture_errors=[],captured_scope=scope,map_index=1,strategy="fast",
                root_seed="synthetic-not-runtime",phase_wait_ticks=0,source_commit="a"*40,manifest_hash="b"*64,physics_hz=60,
                manifest={"manifest_hash":"b"*64,"areas":[{"id":"area","role":"junction"}],"connections":[{"id":"edge"}]},frames=frames,
                edges=[{"id":"edge","start_tick":1,"end_tick":180,"reached":True}],events=[],tick_count=180,initial_capability=cap,
                outcome="route_target_reached",route_reached=True,initial_scenery_inventory=[{"descendants":[{"class":"Sprite2D","texture_class":"GradientTexture2D"}]}])


class ExperienceTests(unittest.TestCase):
    def test_instantiated_atlas_and_landmark_metadata_resolve_actual_identity(self):
        c=synthetic_capture()
        rows=[{"class":"Sprite2D","texture":"","texture_class":"AtlasTexture","texture_atlas":"res://actual/decor.png"},
              {"class":"Sprite2D","texture":"","texture_class":"AtlasTexture","texture_atlas":"res://actual/decor.png",
               "landmark_id":"stones","landmark":{"asset_id":"stones","area_id":"observed_junction"}},
              {"class":"Sprite2D","texture":"","texture_class":"AtlasTexture","texture_atlas":""}]
        c["initial_scenery_inventory"]=[{"descendants":rows}]
        facts=experience.scenery_facts(c)
        self.assertEqual(facts["prop_assets"],{"res://actual/decor.png":1,"stones":1,"unknown":1})
        self.assertEqual(facts["textured_prop_nodes"],3)
        self.assertIn("subjective fun/beauty",experience.analyze_capture(c)["unverified"])

    def test_historical_empty_atlas_identity_remains_reproducible_and_unverified(self):
        c=synthetic_capture()
        c["initial_scenery_inventory"]=[{"descendants":[{"class":"Sprite2D","texture":"","texture_class":"AtlasTexture"}]}]
        result=experience.analyze_capture(c)
        self.assertEqual(result["scenery"]["prop_assets"],{"":1})
        self.assertIn("subjective fun/beauty",result["unverified"])

    def test_walk_and_missing_landmark_candidates_not_fun_pass(self):
        result=experience.analyze_capture(synthetic_capture())
        self.assertEqual(result["stats"]["low_interaction_candidates"],1)
        self.assertEqual(result["stats"]["textured_prop_nodes"],0)
        self.assertEqual([x["kind"] for x in result["diagnostics"]],["low_interaction_candidate","missing_instantiated_landmarks"])
        self.assertIn("subjective fun/beauty",result["unverified"])

    def test_rejected_requests_do_not_clear_walking(self):
        c=synthetic_capture()
        for f in c["frames"]:f["input_requests"]=[{"type":"shoot"}]
        self.assertEqual(experience.analyze_capture(c)["stats"]["low_interaction_candidates"],1)

    def test_actual_event_breaks_chain(self):
        c=synthetic_capture();e={"tick":90,"kind":"jump_accepted","edge":"edge"};c["events"]=[e];c["frames"][89]["accepted_events"]=[e]
        self.assertEqual(experience.analyze_capture(c)["stats"]["low_interaction_candidates"],0)

    def test_invented_accepted_event_rejected(self):
        c=synthetic_capture();c["frames"][1]["accepted_events"]=[{"kind":"jump_accepted","tick":2}]
        with self.assertRaises(ValueError):experience.analyze_capture(c)

    def test_journal_event_cannot_be_reused_on_other_frames(self):
        c=synthetic_capture();e={"tick":1,"kind":"jump_accepted","edge":"edge"};c["events"]=[e]
        for frame in c["frames"]:frame["accepted_events"]=[e]
        with self.assertRaisesRegex(ValueError,"different observation tick"):experience.analyze_capture(c)

    def test_event_multiplicity_and_complete_frame_partition(self):
        e={"tick":90,"kind":"jump_accepted","edge":"edge"}
        for frame_events in ([],[e,e]):
            c=synthetic_capture();c["events"]=[e];c["frames"][89]["accepted_events"]=frame_events
            with self.subTest(events=frame_events):
                with self.assertRaises(ValueError):experience.analyze_capture(c)
        # Two equal events are legal only when the real journal also has two.
        c["events"]=[e,e];self.assertEqual(len(experience.analyze_capture(c)["action_signature"]),2)

    def test_unknown_action_kind_is_not_real_action_evidence(self):
        c=synthetic_capture();e={"tick":90,"kind":"fun_pass","edge":"edge"};c["events"]=[e];c["frames"][89]["accepted_events"]=[e]
        with self.assertRaises(ValueError):experience.analyze_capture(c)

    def test_live_near_enemy_requires_encounter_review(self):
        c=synthetic_capture()
        for frame in c["frames"]:
            frame["runtime"]={"enemies":[{"id":"live","position":frame["position"],"terminal":False}]}
        self.assertEqual(experience.analyze_capture(c)["stats"]["low_interaction_candidates"],0)
        for frame in c["frames"]:frame["runtime"]["enemies"][0]["terminal"]=True
        self.assertEqual(experience.analyze_capture(c)["stats"]["low_interaction_candidates"],1)

    def test_capture_counterexamples_fail_closed(self):
        changes=[lambda c:c.update(frames=[]),lambda c:c["frames"][2].update(tick=99),lambda c:c["frames"][0].update(position=[float("nan"),0]),
                 lambda c:c["captured_scope"].update(enemy_disable=True),lambda c:c["frames"][0].update(edge="other_map"),
                 lambda c:c["edges"][0].update(end_tick=181),lambda c:c.update(manifest_hash="bad")]
        for change in changes:
            with self.subTest(change=change):
                c=synthetic_capture();change(c)
                with self.assertRaises(ValueError):experience.validate_capture(c)

    def test_terminal_interval_requires_actual_terminal_journal(self):
        c=synthetic_capture();c["edges"][0].update(aborted=True,reached=False,end_tick=181)
        with self.assertRaises(ValueError):experience.validate_capture(c)
        c["terminal_observation"]={"tick":181};c["events"]=[{"tick":181,"kind":"run_ended","edge":"edge"}]
        experience.validate_capture(c)

    def test_shell_compare_and_fingerprint_mutations_rejected(self):
        for value in ({},{"artifact_kind":"level_experience_report","schema_version":1,"cases":[],"artifacts":[]}):
            with self.assertRaises(ValueError):experience.compare(value,value)

    def test_rehashed_report_must_match_retained_derived_content(self):
        # Synthetic capture/log/receipt UNIT FIXTURES, never Motor evidence.
        # No validation boundary is mocked: actual receipt checks also run.
        from test_level_formal_receipts import make_receipt
        build=experience.ROOT/"build";build.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=build) as tmp:
            capture=Path(tmp)/"capture.json";data=synthetic_capture();data["engine"]="4.7.2-stable (official)";capture.write_text(json.dumps(data))
            log=capture.with_suffix(".log");log.write_text("Godot Engine v4.7.2.stable.official.abc123\nLEVEL FORMAL CAPTURE: 180 frames, 1 edges, outcome=route_target_reached, capture_errors=0\n")
            receipt=capture.with_suffix(".invocation.json");receipt.write_text(json.dumps(make_receipt(capture,data,log,{"synthetic-unit-observer":"a"*64})))
            original=experience.report([capture]);experience.validate_report(original)
            mutations=[lambda r:r["cases"][0]["stats"].update(ticks=.5),
                       lambda r:r["cases"][0]["stats"].update(seconds=999999),
                       lambda r:r["cases"][0].update(outcome="fictional",edges=[{}]),
                       lambda r:r["artifacts"][0].update(path="does/not/exist"),
                       lambda r:r["dimensions"]["Q6"].update(status="passed"),
                       lambda r:r.update(player_acceptance="passed",device_acceptance="passed"),
                       lambda r:r["cases"][0]["action_signature"].append("invented_action"),
                       lambda r:r["cases"][0]["diagnostics"].clear()]
            for mutate in mutations:
                value=copy.deepcopy(original);mutate(value);value["fingerprint"]=experience.fingerprint({k:v for k,v in value.items() if k!="fingerprint"})
                with self.subTest(mutation=mutate):
                    with self.assertRaises(ValueError):experience.compare(value,value)

    def test_scoped_knowledge_integrity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/"docs/quality").mkdir(parents=True);evidence=root/"proof.txt";evidence.write_text("actual scope description")
            lesson=dict(id="one",source_kind="design_review",source_commit="a"*40,region_ids=["windchime_plains"],capability_scope="base pulse only",
                        claim="candidate observation",limits=["not player approval"],evidence=[{"path":"proof.txt","sha256":experience.sha(evidence)}])
            path=root/"docs/quality/level_lessons.json";path.write_text(json.dumps({"schema_version":1,"lessons":[lesson]}))
            self.assertEqual(experience.load_lessons("thorn_forest",root),[])
            self.assertEqual(len(experience.load_lessons("windchime_plains",root)),1)
            evidence.write_text("changed")
            with self.assertRaises(ValueError):experience.load_lessons("windchime_plains",root)


if __name__=="__main__":unittest.main()
