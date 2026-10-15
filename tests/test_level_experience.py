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


class ExplicitPolicyComparisonTests(unittest.TestCase):
    def report_pair(self):
        from unittest.mock import patch
        source={"res://tests/driver.gd":"a"*64}
        core={"res://scripts/player/player_motor.gd":"b"*64}
        case={"case":{"root_seed":"synthetic-compare","map_index":1,"strategy":"fast","phase_wait_ticks":0},"capture_contract_version":2,
              "policy_basis":{"encounter_policy":"kill_from_bank_v1","driver_sources":source,"core_invariants":core},
              "observer_basis":source,"capability_basis":{},"physics_hz":60,"captured_scope":{},"source_commit":"a"*40,"manifest_hash":"b"*64,
              "action_signature":[],"outcome":"route_policy_failed","stats":{"accepted_events":{},"ticks":1}}
        report={"policy":{},"cases":[case],"fingerprint":"f"*64}
        return report,copy.deepcopy(report)
    def test_compare_rejects_motor_and_transitive_driver_changes(self):
        from unittest.mock import patch
        for field,key in (("core_invariants","res://scripts/player/player_motor.gd"),("driver_sources","res://tests/driver.gd")):
            left,right=self.report_pair();right["cases"][0]["policy_basis"][field][key]="0"*64
            with patch.object(experience,"validate_report",return_value=None):
                with self.assertRaisesRegex(ValueError,"core implementation"):experience.compare(left,right)
    def test_compare_same_policy_projection_content_difference_allowed(self):
        from unittest.mock import patch
        left,right=self.report_pair();right["cases"][0]["manifest_hash"]="c"*64
        with patch.object(experience,"validate_report",return_value=None):
            self.assertTrue(experience.compare(left,right)["cases"][0]["manifest_changed"])


class PolicyCausalTimeTests(unittest.TestCase):
    """Synthetic adjacency counterexamples; native runner supplies actual physics."""
    def actual_contract_fixture(self):
        import level_formal as formal
        c=synthetic_capture();sources=formal.source_files()
        c.update(capture_contract_version=2,encounter_policy="kill_from_bank_v1",policy_observations=[],
                 policy_basis={"schema_version":1,"encounter_policy":"kill_from_bank_v1","reward_policy":"two_actual_medium_and_camp_v1",
                    "driver_sources":{"res://"+p:sources[p] for p in formal.driver_source_paths()},
                    "core_invariants":{"res://"+p:sources[p] for p in formal.core_source_paths()}})
        c["initial_capability"]["shot_energy"]={"shot_energy_cost":20.,"hit_energy_recovery":20.}
        shot=dict(tick=2,kind="shot_accepted",edge="edge",owner_id=10,session_id=1,shot_id=1,packet_id=1,resource_epoch=3,
                  event_id="10:1:1",direction=[1.,0.],projectile_direction=[1.,0.],energy_after=80.)
        damage=dict(tick=4,kind="damage_committed",edge="edge",source="player_projectile:10",target="fixture_enemy",event_id="10:1:1",damage_kind=0,health_after=2.,lethal=False,actor_epoch=7)
        c["events"]=[shot,damage];c["frames"][1]["accepted_events"]=[shot];c["frames"][3]["accepted_events"]=[damage]
        c["resource_receipts"]=[dict(event_id="shot/1/1",operation="consume",status=0,amount_applied=-20.,requested_amount=20.,current=80.,capacity=100.,tick=2,session_id=1,epoch=3),
                                dict(event_id="hit/1/1",operation="grant",status=0,amount_applied=20.,requested_amount=20.,current=100.,capacity=100.,tick=4,session_id=1,epoch=3)]
        return c
    def test_actual_contract_fixture_and_clamped_zero_positive(self):
        c=self.actual_contract_fixture();experience.validate_capture(c)
        c["resource_receipts"][1].update(amount_applied=0.,current=100.)
        experience.validate_capture(c)
    def test_receipt_time_session_epoch_and_applied_mutations_rejected(self):
        for index,key,value in [(0,"tick",3),(0,"session_id",99),(0,"epoch",99),(0,"status",1),(1,"tick",3),(1,"session_id",99),(1,"epoch",99),(1,"amount_applied",21.)]:
            c=self.actual_contract_fixture();c["resource_receipts"][index][key]=value
            with self.subTest(index=index,key=key):
                with self.assertRaises(ValueError):experience.validate_capture(c)
    def test_late_death_does_not_waive_earlier_hit_refund(self):
        c=self.actual_contract_fixture();c["resource_receipts"]=c["resource_receipts"][:1]
        fatal=dict(tick=181,kind="damage_committed",edge="edge",source="actual_later_enemy",target="player",event_id="later",damage_kind=0,health_after=0.,lethal=True,actor_epoch=7)
        ended=dict(tick=181,kind="run_ended",edge="edge",reason="failure")
        c["events"].extend([fatal,ended]);c.update(outcome="run_ended/failure",route_reached=False,terminal_observation={"tick":181})
        with self.assertRaisesRegex(ValueError,"refund receipt"):experience.validate_capture(c)
    def test_only_same_actual_fatal_batch_can_cancel_refund(self):
        c=self.actual_contract_fixture();c["resource_receipts"]=c["resource_receipts"][:1]
        fatal=dict(tick=4,kind="damage_committed",edge="edge",source="actual_simultaneous",target="player",event_id="fatal",damage_kind=0,health_after=0.,lethal=True,actor_epoch=7)
        ended=dict(tick=4,kind="run_ended",edge="edge",reason="failure")
        c["events"].extend([fatal,ended]);c["frames"][3]["accepted_events"].extend([fatal,ended]);c.update(outcome="run_ended/failure",route_reached=False)
        experience.validate_capture(c)
        c["events"][-2]["actor_epoch"]=8
        with self.assertRaisesRegex(ValueError,"refund receipt"):experience.validate_capture(c)

class ResourceClaimEvidenceTests(unittest.TestCase):
    """Service-ledger shaped UNIT cases; actual heart/note physics is separate."""
    def sample(self, resource="coin", amount=7):
        identity="region/cache/test";choice=identity+"/resource/"+resource;event="run_test/"+identity+"/resource"
        meta={"notes":2,"meta_currency":2,"profile_revision":4,"upgrades":{},"save_status":"memory_only"}
        before={"coins":9,"wallet_grants":{"old":9},"health":4.,"health_capacity":5.,"health_epoch":2,"health_receipts":{},"meta":meta,"meta_receipts":{}}
        after=copy.deepcopy(before)
        if resource=="coin":after["coins"]+=amount;after["wallet_grants"][event]=amount
        if resource=="heart":
            after["health"]=5.;after["health_receipts"][event]={"operation":"heal","requested_amount":amount,"event_id":event,"status":0,"amount_applied":1.,"current":5.,"capacity":5.,"epoch":2}
        if resource=="note":
            after["meta"].update(notes=2+amount,meta_currency=2+amount,profile_revision=5);after["meta_receipts"][event]={"kind":"notes","amount":amount}
        output={"choice":choice,"resource":resource,"amount":amount}
        claim={"chest":identity,"choice":choice,"claim_output":output,"wallet_receipts":after["wallet_grants"],"before":{k:before[k] for k in ["coins","health","meta"]},"after":{k:after[k] for k in ["coins","health","meta"]},"transaction":{"schema_version":1,"stage_index":2,"receipt_prefix":"run_test","offer":{"offer_id":identity,"candidates":[{"id":choice,"kind":"resource","resource":resource,"amount":amount,"valid":True}]},"before":before,"after":after}}
        capture={"capture_contract_version":3,"map_index":2,"manifest":{"rewards":[{"id":identity,"resources":[{"kind":resource,"amount":amount}]}]},"formal_run_manifest_final":{"stages":[{"stage_index":1,"outputs":{}},{"stage_index":2,"outputs":{"cache/"+identity:copy.deepcopy(output)}}]}}
        return capture,claim
    def test_coin_heart_clamp_note_and_concurrent_transactions(self):
        for resource in ["coin","heart","note"]:
            c,o=self.sample(resource);experience.validate_cache_claim(c,o)
        c,o=self.sample();o["transaction"]["after"]["wallet_grants"]["other_auto_coin"]=3;o["transaction"]["after"]["coins"]+=3;o["after"]["coins"]+=3;experience.validate_cache_claim(c,o)
        c,o=self.sample("heart");r=o["transaction"]["after"]["health_receipts"]["run_test/region/cache/test/resource"];self.assertEqual(r["amount_applied"],1);self.assertEqual(r["requested_amount"],7)
        c,o=self.sample("note");after=o["transaction"]["after"];after["meta_receipts"]["other_note"]={"kind":"notes","amount":2};after["meta"]["notes"]+=2;after["meta"]["meta_currency"]+=2;after["meta"]["profile_revision"]+=1;experience.validate_cache_claim(c,o)
    def test_original_four_claim_mutations_rejected(self):
        for mutate in [lambda o:o.update(wallet_receipts={}),lambda o:o["after"].update(coins=o["before"]["coins"]),lambda o:o["claim_output"].update(amount=999999),lambda o:o["claim_output"].update(resource="imaginary_resource")]:
            c,o=self.sample();mutate(o)
            with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)
    def test_wrong_stage_chest_offer_and_unknown_version_rejected(self):
        for mutate in [lambda c,o:c["formal_run_manifest_final"]["stages"][1].update(stage_index=3),lambda c,o:c["formal_run_manifest_final"]["stages"][1]["outputs"].clear(),lambda c,o:o["transaction"].update(stage_index=1),lambda c,o:o["transaction"]["offer"].update(offer_id="different_cache"),lambda c,o:o["transaction"].update(schema_version=99),lambda c,o:o["transaction"]["offer"]["candidates"][0].update(amount=99)]:
            c,o=self.sample();mutate(c,o)
            with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)
    def test_receipt_reuse_wrong_id_duplicate_and_missing_effect_rejected(self):
        for mode in ["reuse","wrong_id","duplicate","missing_effect","missing_offer"]:
            c,o=self.sample();tx=o["transaction"];grants=tx["after"]["wallet_grants"];event="run_test/region/cache/test/resource"
            if mode=="reuse":tx["before"]["wallet_grants"][event]=7
            if mode=="wrong_id":grants["other/cache/resource"]=grants.pop(event)
            if mode=="duplicate":grants["other_run/region/cache/test/resource"]=7;tx["after"]["coins"]+=7;o["after"]["coins"]+=7
            if mode=="missing_effect":tx["after"]["coins"]-=7;o["after"]["coins"]-=7
            if mode=="missing_offer":tx.pop("offer")
            with self.subTest(mode=mode):
                with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)
    def test_heal_clamp_and_notes_receipt_neighbors_rejected(self):
        for resource,field,value in [("heart","requested_amount",999),("heart","amount_applied",7),("heart","status",False),("heart","epoch",99),("note","amount",999),("note","kind","upgrade")]:
            c,o=self.sample(resource);ledger=o["transaction"]["after"]["health_receipts" if resource=="heart" else "meta_receipts"];next(iter(ledger.values()))[field]=value
            with self.subTest(resource=resource,field=field):
                with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)
    def test_full_health_note_alternative_and_legacy_boundaries(self):
        c,o=self.sample("note");o["before"]["health"]=5.;o["after"]["health"]=5.;o["transaction"]["before"]["health"]=5.;o["transaction"]["after"]["health"]=5.;experience.validate_cache_claim(c,o)
        c,o=self.sample("heart");o["before"]["health"]=5.;o["transaction"]["before"]["health"]=5.;next(iter(o["transaction"]["after"]["health_receipts"].values()))["amount_applied"]=0.
        with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)
        c,o=self.sample();c["capture_contract_version"]=2;o.pop("transaction");experience.validate_cache_claim(c,o)
        c["capture_contract_version"]=3
        with self.assertRaises(ValueError):experience.validate_cache_claim(c,o)


class DamageRankingRevisionTests(unittest.TestCase):
    """Bounded ranking semantics, synthetic fixtures are not live Motor proof."""
    def test_actual_player_target_is_separate_from_enemy_and_unknown(self):
        c=synthetic_capture()
        for tick,target in [(1,"player"),(2,"enemy"),(3,None),(4,"enemy")]:
            event={"tick":tick,"kind":"damage_committed","edge":"edge"}
            if target is not None:event["target"]=target
            c["events"].append(event);c["frames"][tick-1]["accepted_events"].append(event)
        result=experience.analyze_capture(c)
        self.assertEqual([result["stats"][k] for k in ["player_damage_events","non_player_damage_events","unknown_target_damage_events"]],[1,2,1])
        self.assertNotIn("player_damage_events",experience.analyze_capture(c,analysis_version=1)["stats"])
        for bad in [0,3,True,"2"]:
            with self.subTest(version=bad):
                with self.assertRaises(ValueError):experience.analyze_capture(c,analysis_version=bad)

    def test_old_report_recomputes_exactly_and_new_ranking_prioritizes_player_harm(self):
        from test_level_formal_receipts import make_receipt
        build=experience.ROOT/"build";build.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=build) as tmp:
            paths=[]
            for label,target,count in [("enemy_hits","enemy",6),("player_hurt","player",1)]:
                data=synthetic_capture();data["root_seed"]=label;data["engine"]="4.7.2-stable (official)"
                for tick in range(1,count+1):
                    event={"tick":tick,"kind":"damage_committed","edge":"edge","target":target}
                    data["events"].append(event);data["frames"][tick-1]["accepted_events"].append(event)
                path=Path(tmp)/(label+".json");path.write_text(json.dumps(data));paths.append(path)
                log=path.with_suffix(".log");log.write_text("Godot Engine v4.7.2.stable.official.abc123\nLEVEL FORMAL CAPTURE: 180 frames, 1 edges, outcome=route_target_reached, capture_errors=0\n")
                path.with_suffix(".invocation.json").write_text(json.dumps(make_receipt(path,data,log,{"synthetic-unit-observer":"a"*64})))
            legacy=experience.report(paths,analysis_version=1);current=experience.report(paths)
            self.assertNotIn("analysis_version",legacy)
            self.assertEqual(legacy["worst_candidates"][0]["root_seed"],"enemy_hits")
            self.assertEqual(current["worst_candidates"][0]["root_seed"],"player_hurt")
            self.assertEqual(experience.validate_report(legacy),legacy)
            self.assertEqual(experience.validate_report(current),current)
            with self.assertRaisesRegex(ValueError,"analysis revision changed"):experience.compare(legacy,current)
            bad=copy.deepcopy(current);bad["cases"][1]["stats"]["player_damage_events"]=0
            bad["fingerprint"]=experience.fingerprint({k:v for k,v in bad.items() if k!="fingerprint"})
            with self.assertRaises(ValueError):experience.validate_report(bad)


if __name__ == "__main__": unittest.main()
