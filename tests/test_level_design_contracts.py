"""Falsifiable positive/negative contract tests, separate from actual Motor evidence."""
import copy
import json
from pathlib import Path
import sys
import hashlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from level_design_contracts import SCHEMA, validate_design, validate_region_production_proof, validate_forest_h_slice

FIXTURES = ROOT / "tests/fixtures/level_design_v2"


class DesignContractTests(unittest.TestCase):
    def test_H_only_proof_rejects_leaked_later_capabilities(self):
        contract={'region_id':'thorn_forest','kind':'boss','scope':'prototype',
                  'capability_gate':{'alternatives':[['H']]},'allowed_capabilities':['H']}
        data={'artifact_kind':'region_production_capture','region_id':'thorn_forest','proof_kind':'boss',
              'scope':'actual_region_prototype','assertions':1,'failures':[],'observations':[{'kind':'SIMULATED contract fixture'}],
              'consumer':'scripts/demo/thorn_forest_h_slice.gd','source_commit':'a'*40,
              'capability_snapshot':{'abilities':['H'],'equipped_weapon':'pulse_gun','current_weapon_count':1}}
        self.assertEqual(validate_region_production_proof(data,contract),[])
        for extra in ('W','D','U1','U2'):
            with self.subTest(extra=extra):
                candidate=copy.deepcopy(data);candidate['capability_snapshot']['abilities'].append(extra)
                self.assertIn('outside the authorized prototype',' '.join(validate_region_production_proof(candidate,contract)))

    def test_region_proof_identity_is_separate_from_design_or_shared_checks(self):
        # Declaration fixture only; native receipt validation belongs to the loop.
        contract={'region_id':'thorn_forest','kind':'boss','scope':'prototype','capability_gate':{'alternatives':[['H']]}}
        data={'artifact_kind':'region_production_capture','region_id':'thorn_forest','proof_kind':'boss',
              'scope':'actual_region_prototype','assertions':7,'failures':[],
              'observations':[{'note':'SIMULATED declaration contract'}],
              'consumer':'scripts/bosses/simulated_forest_boss.gd','source_commit':'a'*40,
              'capability_snapshot':{'abilities':['H'],'equipped_weapon':'pulse_lv1','current_weapon_count':1}}
        self.assertEqual(validate_region_production_proof(data,contract),[])
        for field,value in [('region_id','windchime_plains'),('proof_kind','integration'),('scope','development_only'),
                            ('artifact_kind','level_design_intent'),('assertions',True),('observations',[]),
                            ('consumer','../../fake.gd'),('source_commit','HEAD'),('capability_snapshot',{})]:
            with self.subTest(field=field):
                candidate=copy.deepcopy(data);candidate[field]=value
                self.assertTrue(validate_region_production_proof(candidate,contract))
        for capabilities in ([],['W'],['D','U1','U2']):
            candidate=copy.deepcopy(data);candidate['capability_snapshot']['abilities']=capabilities
            self.assertTrue(validate_region_production_proof(candidate,contract))
        candidate=copy.deepcopy(data);candidate['capability_snapshot']['current_weapon_count']=2
        self.assertTrue(validate_region_production_proof(candidate,contract))

    def test_actual_forest_native_trace_rejects_deleted_events_return_and_capability_leaks(self):
        # Byte-preserved native process artifact, not a fabricated successful fixture.
        data=json.loads((ROOT/'docs/evidence/region_production_v3/forest_h_slice/native/positive/capture.json').read_text())
        self.assertEqual(validate_forest_h_slice(data),[])
        for case in ('missing-anchor','no-hook'):
            actual=json.loads((ROOT/f'docs/evidence/region_production_v3/forest_h_slice/native/{case}/capture.json').read_text())
            self.assertTrue(validate_forest_h_slice(actual),case)
        mutations={
            'remove_actual_landings':lambda d:d.update(events=[e for e in d['events'] if e['kind']!='landed']),
            'remove_hook_kick':lambda d:d.update(events=[e for e in d['events'] if e['kind']!='hook_kick']),
            'remove_return_frames':lambda d:d.update(observations=d['observations'][:90]),
            'fake_landing_tick':lambda d:[e.update(tick=1) for e in d['events'] if e['kind']=='landed' and 'CanopyBranch' in e.get('supports',[])],
            'missing_router_request':lambda d:d.update(input_requests=[]),
            'missing_source_body':lambda d:d.pop('body_size'),
            'midroute_extra_capability':lambda d:d['final_capability_snapshot']['granted_actions'].append('wall_climb'),
        }
        for name,change in mutations.items():
            with self.subTest(name=name):
                candidate=copy.deepcopy(data);change(candidate)
                self.assertTrue(validate_forest_h_slice(candidate),name)
        for capability in ('W','D','U1','U2'):
            candidate=copy.deepcopy(data);candidate['capability_snapshot']['abilities'].append(capability)
            self.assertTrue(validate_forest_h_slice(candidate),capability)
        for key in ('capability_snapshot','final_capability_snapshot','captured_scope','events','geometry','body_size','observations','input_requests'):
            candidate=copy.deepcopy(data);candidate[key]=None
            with self.subTest(malformed=key):self.assertTrue(validate_forest_h_slice(candidate))

    def test_forest_request_transition_and_resource_causal_rejections(self):
        # Actual captured positive; mutations are consumer tests, not native reruns.
        data=json.loads((ROOT/'docs/evidence/region_production_v3/forest_h_slice/native/positive/capture.json').read_text())
        changes={
            'hook_events_tick1':lambda d:[e.update(tick=1) for e in d['events'] if e['kind'].startswith('hook_')],
            'hook_events_outside_route':lambda d:[e.update(tick=len(d['observations'])+1) for e in d['events'] if e['kind'].startswith('hook_')],
            'erase_observed_states':lambda d:[f.update(traversal='idle',hook_used=False) for f in d['observations']],
            'request_after_route':lambda d:d['input_requests'][0].update(tick=1000000),
            'request_before_cast':lambda d:d['input_requests'][0].update(tick=d['input_requests'][0]['tick']-1),
            'impossible_energy':lambda d:d['observations'][50].update(energy=99999),
            'hidden_energy_cost':lambda d:d['observations'][50].update(energy=d['observations'][50]['energy']-1),
            'terminal_health':lambda d:d['observations'][50].update(health=0),
            'injected_health':lambda d:d['observations'][50].update(health=99999),
            'infinite_health':lambda d:d['observations'][50].update(health=float('inf')),
            'bool_health':lambda d:d['observations'][50].update(health=True),
            'hook_token_reset_before_kick':lambda d:d['observations'][26].update(hook_used=False),
            'extra_air_shot':lambda d:d['observations'][50].update(air_shots=d['capability_snapshot']['raw']['air_shot_flight_cap']+1),
            'missing_free_transition':lambda d:d.update(events=[e for e in d['events'] if e['kind']!='free']),
            'duplicate_accepted_cast':lambda d:d['events'].insert(2,copy.deepcopy(d['events'][1])),
            'shift_landing_inside_support_window':lambda d:[e.update(tick=e['tick']+1) for e in d['events'] if e['kind']=='landed'],
            'wrong_event_position':lambda d:d['events'][1].update(position=[0,0]),
            'missing_aim':lambda d:d['input_requests'][0].pop('direction'),
        }
        for name,change in changes.items():
            with self.subTest(name=name):
                candidate=copy.deepcopy(data);change(candidate)
                self.assertTrue(validate_forest_h_slice(candidate),name)

    def test_original_quality_consumer_rejects_coherent_causal_counterexamples(self):
        # Simulated receipt-selection unit cases over byte-preserved actual native
        # data/logs, not new native executions or worker responses.
        import level_design
        import production_loop as loop
        folder=ROOT/'docs/evidence/region_production_v3/forest_h_slice/native/positive'
        original=json.loads((folder/'capture.json').read_text())
        receipt=json.loads((folder/'capture.invocation.json').read_text())
        record_path=ROOT/'docs/quality/records/V3-FOREST-STARTUP-01.json'
        # A frozen pre-verdict metadata fixture selects the semantic unit input.
        # Live V3-FOREST-STARTUP-01 is permanently blocked/REJECT after two rounds;
        # unit acceptance must never alter or infer acceptance of that live task.
        actual_record=json.loads((ROOT/'docs/evidence/region_production_v3/forest_h_slice/child_final_quality_record.json').read_text())
        contract={'id':'V3-FOREST-STARTUP-01','quality_record':str(record_path.relative_to(ROOT)),
                  'completion':'stage','required_gates':['G0','G1'],
                  'region_proof':{'region_id':'thorn_forest','kind':'golden','scope':'prototype',
                                  'capability_gate':{'alternatives':[['H']]},'allowed_capabilities':['H']}}
        changes={
            'positive':lambda d:None,
            'hook_events_tick1':lambda d:[e.update(tick=1) for e in d['events'] if e['kind'].startswith('hook_')],
            'erase_states':lambda d:[f.update(traversal='idle',hook_used=False) for f in d['observations']],
            'request_outside':lambda d:d['input_requests'][0].update(tick=1000000),
            'energy_injection':lambda d:d['observations'][50].update(energy=99999),
            'health_death':lambda d:d['observations'][50].update(health=0),
        }
        original_read=loop.quality.read_json
        with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
            capture=Path(temp)/'capture.json';log=capture.with_suffix('.log')
            log.write_bytes((folder/'capture.log').read_bytes())
            for name,change in changes.items():
                with self.subTest(name=name):
                    data=copy.deepcopy(original);change(data);capture.write_text(json.dumps(data))
                    checksum=hashlib.sha256(capture.read_bytes()).hexdigest()
                    invocation=copy.deepcopy(receipt)
                    invocation.update(capture=str(capture.relative_to(ROOT)),capture_sha256=checksum,source_files=level_design.source_files())
                    invocation['command']=[arg if not arg.startswith('--output=') else '--output=res://'+str(capture.relative_to(ROOT)) for arg in invocation['command']]
                    capture.with_suffix('.invocation.json').write_text(json.dumps(invocation))
                    selected=copy.deepcopy(actual_record)
                    selected['production_snapshot']=loop.digest({p:h for p,h in loop.snapshot().items() if not p.startswith('docs/quality/records/')})
                    selected['region_proofs']=[{'path':str(capture.relative_to(ROOT)),'sha256':checksum}]
                    with patch.object(loop.quality,'read_json',side_effect=lambda path:selected if Path(path)==record_path else original_read(path)):
                        result=loop.check_task_quality(contract)
                    self.assertEqual(result['scope_complete'],name=='positive',result)
                    self.assertFalse(result['content_complete'])
                    if name!='positive':self.assertTrue(any('Canopy' in error for error in result['quality']['errors']))

    def setUp(self):
        self.design = json.loads((FIXTURES / "plains_design.json").read_text())

    def codes(self, data=None):
        return {e["code"] for e in validate_design(self.design if data is None else data)}

    def test_valid_cross_biome_and_golden_cards(self):
        for name in ("plains_design.json", "thorn_forest_design.json", "golden_challenges.json"):
            with self.subTest(name=name):
                self.assertEqual(validate_design(json.loads((FIXTURES / name).read_text())), [])

    def test_empty_malformed_and_future_versions_fail_closed(self):
        for value in (None, [], {}, "", {"schema_version": 2}):
            with self.subTest(value=value): self.assertTrue(validate_design(value))
        self.design["schema_version"] = True
        self.assertIn("schema_version", self.codes())

    def test_every_required_field_has_missing_and_wrong_type_rejection(self):
        # Walk all actual nested records to catch forgotten field consumers.
        cases = []
        def visit(value, schema, path):
            if isinstance(schema, dict):
                for key, sub in schema.items():
                    cases.append((path, key))
                    visit(value[key], sub, path + [key])
            elif isinstance(schema, tuple) and schema[0] == "list":
                for i, item in enumerate(value): visit(item, schema[1], path + [i])
        visit(self.design, SCHEMA, [])
        for path, key in cases:
            for missing in (True, False):
                candidate = copy.deepcopy(self.design)
                target = candidate
                for part in path: target = target[part]
                if missing: del target[key]
                else: target[key] = None
                with self.subTest(path=path, key=key, missing=missing):
                    self.assertTrue(validate_design(candidate))

    def test_unknown_fields_and_empty_arrays_are_not_success(self):
        self.design["runtime"] = {"passed": True}
        self.assertIn("unknown_field", self.codes())
        del self.design["runtime"]
        self.design["challenges"] = []
        self.assertIn("empty_contract", self.codes())

    def test_nonfinite_values_rejected_at_any_depth(self):
        for value in (float("nan"), float("inf"), -float("inf")):
            self.design["topology"]["nodes"][0]["position"]["x"] = value
            self.assertIn("non_finite", self.codes())

    def test_unknown_duplicate_ids_and_references(self):
        self.design["topology"]["edges"][0]["to"] = "missing"
        self.assertIn("unknown_reference", self.codes())
        self.design["topology"]["edges"][0]["to"] = "exit"
        self.design["rooms"].append(copy.deepcopy(self.design["rooms"][0]))
        self.assertIn("duplicate_id", self.codes())
        self.design["rooms"].pop()
        self.design["capabilities"]["optional"].append("hook")
        self.assertIn("duplicate_reference", self.codes())
        self.assertIn("capability_partition", self.codes())

    def test_capability_partition_and_implementation_status(self):
        self.design["capabilities"]["optional"] = []
        self.assertIn("capability_partition", self.codes())
        self.design["capabilities"]["optional"] = ["hook"]
        self.design["capabilities"]["catalog"][3]["implemented"] = False
        self.assertIn("capability_status", self.codes())

    def test_all_eight_experience_categories_are_required(self):
        self.design["biome"]["experience_categories"][0] = "invented"
        self.assertIn("experience_categories", self.codes())

    def test_weapon_identity_level_and_guarantees(self):
        build = self.design["capabilities"]["supported_builds"][0]
        build["equipped_weapon"] = "missing"
        self.assertIn("single_weapon", self.codes())
        build["equipped_weapon"] = "pulse_gun"
        build["weapon_level"] = 4
        self.assertIn("weapon_level", self.codes())
        build["weapon_level"] = 1
        build["abilities"].remove("jump")
        self.assertIn("baseline_capabilities", self.codes())
        build["abilities"].append("jump")
        build["abilities"].append("thorn_resonance")
        self.assertIn("baseline_capabilities", self.codes())

    def test_action_transition_must_match_order_not_just_action_set(self):
        self.design["phrases"][0]["transitions"].reverse()
        self.assertIn("action_transition", self.codes())
        self.design["phrases"][0]["transitions"].reverse()
        self.design["challenges"][0]["required_capabilities"].remove("shot_recoil")
        self.assertIn("action_capabilities", self.codes())

    def test_main_route_cannot_hide_master_or_future_requirements(self):
        c = self.design["challenges"][0]
        c["tier"] = "master"
        self.assertIn("main_master", self.codes())
        c["route_role"] = "hidden"
        self.assertIn("main_master", self.codes())  # edge still main
        c["tier"] = "ordinary"; c["route_role"] = "main"
        c["required_capabilities"].append("thorn_resonance")
        self.assertIn("future_main", self.codes())
        c["required_capabilities"].remove("thorn_resonance")
        self.design["topology"]["edges"][0]["requires"].append("thorn_resonance")
        self.assertIn("future_main", self.codes())

    def test_hidden_role_cannot_disguise_mandatory_master_challenge(self):
        self.design["topology"]["edges"][0]["role"] = "hidden"
        self.design["challenges"][0].update(tier="master", route_role="hidden")
        self.assertIn("mandatory_master", self.codes())
        bypass = copy.deepcopy(self.design["topology"]["edges"][0])
        bypass.update(id="ordinary_bypass", role="main", challenge_ids=[])
        self.design["topology"]["edges"].append(bypass)
        self.assertEqual(self.codes(), set())

    def test_master_cannot_gate_an_ability_required_to_reach_goal(self):
        master = copy.deepcopy(self.design["challenges"][0])
        master.update(id="master_gate", tier="master", route_role="hidden")
        self.design["challenges"].append(master)
        grant = copy.deepcopy(self.design["topology"]["nodes"][1])
        grant.update(id="hook_grant", grants=["hook"])
        self.design["topology"]["nodes"].append(grant)
        gate = copy.deepcopy(self.design["topology"]["edges"][0])
        gate.update(id="master_to_grant", to="hook_grant", role="hidden", challenge_ids=["master_gate"])
        back = copy.deepcopy(self.design["topology"]["edges"][1])
        back.update(id="grant_return", **{"from": "hook_grant"})
        self.design["topology"]["edges"] += [gate, back]
        self.design["topology"]["edges"][0]["requires"].append("hook")
        self.assertIn("mandatory_master", self.codes())
        # A real ordinary grant route makes the master branch optional.
        bypass = copy.deepcopy(gate)
        bypass.update(id="ordinary_grant_route", role="reward", challenge_ids=[])
        self.design["topology"]["edges"].append(bypass)
        self.assertEqual(self.codes(), set())

    def test_nonmaster_route_required_for_every_single_weapon_build(self):
        self.design["topology"]["edges"][0]["role"] = "hidden"
        self.design["challenges"][0].update(tier="master", route_role="hidden")
        other = copy.deepcopy(self.design["capabilities"]["supported_builds"][0])
        other.update(id="other", equipped_weapon="shadow_shuriken", available_weapons=["shadow_shuriken"])
        self.design["capabilities"]["supported_builds"].append(other)
        self.design["challenges"][0]["supported_builds"].append("other")
        self.design["topology"]["edges"][0]["weapon_ids"].append("shadow_shuriken")
        bypass = copy.deepcopy(self.design["topology"]["edges"][0])
        bypass.update(id="pulse_only_bypass", role="main", challenge_ids=[], weapon_ids=["pulse_gun"])
        self.design["topology"]["edges"].append(bypass)
        errors = validate_design(self.design)
        self.assertEqual([e["path"] for e in errors if e["code"] == "mandatory_master"], ["$.capabilities.supported_builds.other"])
        bypass["weapon_ids"].append("shadow_shuriken")
        self.assertEqual(self.codes(), set())

    def test_state_ranges_and_evidence_separation(self):
        self.design["challenges"][0]["entry"]["velocity"]["x"] = {"min": 4, "max": 3}
        self.assertIn("state_range", self.codes())
        self.design["challenges"][0]["entry"]["velocity"]["x"] = {"min": 0, "max": 0}
        self.design["challenges"][0]["tolerance"]["status"] = "measured"
        self.assertIn("design_evidence_claim", self.codes())
        self.design["challenges"][0]["tolerance"]["status"] = "uncalibrated"
        self.design["evidence_boundary"]["physics"] = "passed"
        self.assertIn("enum_value", self.codes())

    def test_future_grants_cannot_pretend_implemented(self):
        self.design["topology"]["nodes"][0]["grants"] = ["thorn_resonance"]
        self.assertIn("future_grant", self.codes())

    def test_pacing_requires_actual_directed_route(self):
        self.design["pacing"]["strategies"][0]["node_ids"] = ["arrival", "arrival", "exit"]
        self.assertIn("strategy_path", self.codes())

    def test_capability_lock_granted_before_use_passes_circular_lock_fails(self):
        # Actual implementation exists but formal grant is only a design here.
        self.design["topology"]["nodes"][0]["grants"] = ["hook"]
        self.design["topology"]["edges"][0]["requires"].append("hook")
        self.assertEqual(self.codes(), set())
        self.design["topology"]["nodes"][0]["grants"] = []
        self.design["topology"]["nodes"][1]["grants"] = ["hook"]
        self.assertIn("goal_unreachable", self.codes())
        self.assertIn("grant_unreachable", self.codes())

    def test_return_paths_required_and_one_way_exit_explicit(self):
        self.design["topology"]["edges"][1]["requires"] = ["hook"]
        self.assertIn("return_unreachable", self.codes())
        self.design["topology"]["nodes"][1]["return_policy"] = "one_way_exit"
        self.assertEqual(self.codes(), set())
        self.design["topology"]["nodes"][0]["return_policy"] = "one_way_exit"
        self.assertIn("invalid_exit", self.codes())

    def test_every_build_needs_a_path_and_available_is_not_equipped(self):
        other = copy.deepcopy(self.design["capabilities"]["supported_builds"][0])
        other.update(id="other", equipped_weapon="shadow_shuriken", available_weapons=["pulse_gun", "shadow_shuriken"])
        self.design["capabilities"]["supported_builds"].append(other)
        self.design["challenges"][0]["supported_builds"].append("other")
        self.assertIn("goal_unreachable", self.codes())  # no borrowing the available pulse gun
        self.design["topology"]["edges"][0]["weapon_ids"].append("shadow_shuriken")
        self.assertEqual(self.codes(), set())
        self.design["challenges"][0]["supported_builds"].remove("other")
        self.assertIn("goal_unreachable", self.codes())

    def test_orphan_optional_room_is_not_a_valid_connected_topology(self):
        node = copy.deepcopy(self.design["topology"]["nodes"][1])
        node["id"] = "orphan"
        self.design["topology"]["nodes"].append(node)
        self.assertIn("disconnected_node", self.codes())

    def test_state_search_does_not_union_unconnected_branch_grants(self):
        catalog = self.design["capabilities"]["catalog"]
        catalog.append({"id": "wall_jump", "implemented": True, "source": "docs/quality/actor_actions_spec.md"})
        self.design["capabilities"]["optional"].append("wall_jump")
        for branch, ability in (("left", "hook"), ("right", "wall_jump")):
            node = copy.deepcopy(self.design["topology"]["nodes"][1])
            node.update(id=branch, grants=[ability])
            self.design["topology"]["nodes"].append(node)
            edge = copy.deepcopy(self.design["topology"]["edges"][1])
            edge.update(id=branch + "_out", **{"from": "arrival", "to": branch})
            self.design["topology"]["edges"].append(edge)
        self.design["topology"]["edges"][0]["requires"] += ["hook", "wall_jump"]
        self.assertIn("goal_unreachable", self.codes())
        for branch in ("left", "right"):
            edge = copy.deepcopy(self.design["topology"]["edges"][1])
            edge.update(id=branch + "_back", **{"from": branch, "to": "arrival"})
            self.design["topology"]["edges"].append(edge)
        self.assertEqual(self.codes(), set())

    def test_bounded_state_analysis_fails_instead_of_accepting_partial_search(self):
        with patch("level_design_contracts.MAX_CAPABILITY_STATES", 1):
            self.assertIn("state_budget", self.codes())
        self.assertEqual(self.codes(), set())

    def test_foundry_binding_does_not_confuse_phrase_and_itinerary(self):
        binding = self.design["challenges"][0]["foundry"]
        self.assertEqual(self.codes(), set())
        binding["phrase_count"] = 3
        self.assertIn("foundry_card", self.codes())
        binding.update(kind="itinerary", template_id="mixed")
        self.assertEqual(self.codes(), set())
        for count in (0.5, 99, 2, 1, 3.0, True):
            binding["phrase_count"] = count
            with self.subTest(count=count): self.assertTrue(self.codes())
        binding["phrase_count"] = 3
        binding["template_id"] = "height_then_precision"
        self.assertIn("foundry_card", self.codes())
        binding["template_id"] = "mixed"
        self.assertEqual(self.codes(), set())

    def test_landing_art_provenance_and_device_contract_cannot_be_omitted(self):
        for path in [("scene_compositions", 0, "occlusion_check"),
                     ("scene_compositions", 0, "assets", 0, "license"),
                     ("encounters", 0, "safe_landing"),
                     ("challenges", 0, "device_constraints", "touch")]:
            candidate = copy.deepcopy(self.design); target = candidate
            for part in path[:-1]: target = target[part]
            del target[path[-1]]
            self.assertIn("required_field", self.codes(candidate))

if __name__ == "__main__":
    unittest.main()
