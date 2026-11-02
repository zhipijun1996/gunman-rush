"""Q1–Q8 evidence from live formal captures; observations, never a fun score."""
import argparse
from collections import Counter
import hashlib
import json
import math
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = {"id": "formal-experience-observation-v1", "calibration": "uncalibrated_candidates",
          "walk_seconds": 2.0, "walk_distance": 400.0, "near_enemy_distance": 180.0}
DIMENSIONS = ["space_exploration", "platforming_actions", "enemy_terrain_encounters",
              "region_identity_learning", "pacing_emotion", "visual_audio_composition",
              "roguelike_replay", "fairness_controls_engineering"]


def read(path):
    from level_design import read as strict_read
    return strict_read(path)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, allow_nan=False).encode()).hexdigest()


def load_lessons(region_id, root=ROOT):
    """Load sourced, scoped experience; a review remains a review, never a rule."""
    if region_id is None:
        return []
    root = Path(root)
    path = root / "docs/quality/level_lessons.json"
    if not path.exists():
        return []
    data = read(path)
    if not isinstance(data, dict) or data.get("schema_version") != 1 or not isinstance(data.get("lessons"), list):
        raise ValueError("Invalid experience knowledge ledger")
    seen, applicable = set(), []
    for lesson in data["lessons"]:
        required = {"id", "source_kind", "source_commit", "region_ids", "capability_scope", "claim", "limits", "evidence"}
        if not isinstance(lesson, dict) or not required <= lesson.keys() or not isinstance(lesson["id"], str) or lesson["id"] in seen:
            raise ValueError("Invalid or duplicate sourced lesson")
        seen.add(lesson["id"])
        if lesson["source_kind"] not in {"engine_fact", "computed_proxy", "design_review", "player_feedback"}:
            raise ValueError("Knowledge must distinguish facts, proxies, reviews and player feedback")
        if not isinstance(lesson["region_ids"], list) or not lesson["region_ids"] or not isinstance(lesson["capability_scope"], str) or not lesson["capability_scope"].strip():
            raise ValueError("Knowledge needs explicit regional and capability scope")
        if not isinstance(lesson["claim"], str) or not lesson["claim"].strip() or not lesson["limits"] or not lesson["evidence"]:
            raise ValueError("Knowledge needs a bounded claim and evidence")
        for ref in lesson["evidence"]:
            file = (root / ref["path"]).resolve()
            if not file.is_relative_to(root.resolve()) or not file.is_file() or sha(file) != ref["sha256"]:
                raise ValueError("Stale/missing knowledge evidence: " + str(ref.get("path")))
        if region_id in lesson["region_ids"]:
            applicable.append(lesson)
    return applicable


def pair(value, label):
    if not isinstance(value, list) or len(value) != 2 or any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in value):
        raise ValueError("Invalid finite pair: " + label)
    return value


def validate_capture(capture):
    if not isinstance(capture, dict) or capture.get("schema_version") != 1 or capture.get("artifact_kind") != "formal_level_capture":
        raise ValueError("Expected live formal capture, not terrain-only or design fixture")
    if capture.get("capture_errors") != [] or not isinstance(capture.get("frames"), list) or not capture["frames"]:
        raise ValueError("Empty/failed formal capture")
    scope = capture.get("captured_scope", {})
    for key in ("enemies_instantiated", "enemy_attacks_enabled", "enemy_contacts_enabled", "environment_damage_enabled", "production_camera_enabled", "production_rewards_enabled"):
        if scope.get(key) is not True:
            raise ValueError("Formal observation lacks consumer: " + key)
    for key in ("controller_manual_step", "actor_teleport_by_driver", "resource_injection", "enemy_disable"):
        if scope.get(key) is not False:
            raise ValueError("Formal observation changed runtime: " + key)
    if type(capture.get("map_index")) is not int or capture.get("map_index") not in (1, 2) or capture.get("strategy") not in ("fast", "growth", "deep", "return"):
        raise ValueError("Invalid formal strategy/map")
    if not isinstance(capture.get("root_seed"), str) or not capture["root_seed"] or type(capture.get("phase_wait_ticks")) is not int or capture["phase_wait_ticks"] < 0:
        raise ValueError("Missing actual seed or phase")
    if not isinstance(capture.get("manifest"), dict) or not capture["manifest"].get("areas") or not capture["manifest"].get("connections"):
        raise ValueError("Missing actual formal Manifest")
    if not re.fullmatch(r"[0-9a-f]{40}", str(capture.get("source_commit", ""))) or not re.fullmatch(r"[0-9a-f]{64}", str(capture.get("manifest_hash", ""))):
        raise ValueError("Missing source or Manifest fingerprint")
    if capture["manifest"].get("manifest_hash") != capture.get("manifest_hash"):
        raise ValueError("Capture/Manifest identity mismatch")
    allowed_edges = {str(e["id"]) for e in capture["manifest"]["connections"]} | {str(a["id"]) for a in capture["manifest"]["areas"]} | {"tutorial"}
    if type(capture.get("physics_hz")) not in (int, float) or not math.isfinite(capture["physics_hz"]) or capture["physics_hz"] <= 0:
        raise ValueError("Missing actual tick rate")
    previous = 0
    journal = capture.get("events")
    if not isinstance(journal, list):
        raise ValueError("Missing actual event journal")
    event_kinds = {"jump_accepted", "shot_accepted", "landed", "segment_returned", "died", "energy_recovered",
                   "input_rejected", "player_health", "damage_committed", "run_ended", "reward_modal_submission"}
    global_events = Counter()
    for event in journal:
        if not isinstance(event, dict) or event.get("kind") not in event_kinds or type(event.get("tick")) is not int:
            raise ValueError("Invalid actual event semantics")
        global_events[fingerprint(event)] += 1
    attributed_events = Counter()
    for frame in capture["frames"]:
        tick = frame.get("tick")
        if type(tick) is not int or tick != previous + 1:
            raise ValueError("Missing/discontinuous real observation frame")
        previous = tick
        if frame.get("edge") not in allowed_edges:
            raise ValueError("Frame references a different map/edge")
        pair(frame.get("position"), "position")
        pair(frame.get("velocity"), "velocity")
        for key in ("health", "shot_energy", "shots", "shot_cooldown", "recovery_count"):
            value = frame.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise ValueError("Invalid runtime state: " + key)
        if not isinstance(frame.get("accepted_events"), list) or not isinstance(frame.get("input_requests"), list):
            raise ValueError("Actions must separate requests and accepted events")
        for event in frame["accepted_events"]:
            if not isinstance(event, dict) or event.get("tick") != tick:
                raise ValueError("Accepted event belongs to a different observation tick")
            key = fingerprint(event)
            attributed_events[key] += 1
            if attributed_events[key] > global_events[key]:
                raise ValueError("Accepted observation absent or reused beyond actual journal multiplicity")
    for event in capture.get("events", []):
        if type(event.get("tick")) is not int or not 0 <= event["tick"] <= previous + 1 or not event.get("kind"):
            raise ValueError("Event outside recorded/terminal tick")
    if capture.get("tick_count") != previous:
        raise ValueError("Trace tick total differs from frames")
    recorded_events = Counter(fingerprint(e) for e in journal if 1 <= e["tick"] <= previous)
    if attributed_events != recorded_events:
        raise ValueError("Recorded journal events must belong to exactly their actual frame")
    if not isinstance(capture.get("edges"), list) or not capture["edges"] or type(capture.get("route_reached")) is not bool:
        raise ValueError("Missing actual route outcome")
    outcomes = {"route_target_reached", "route_policy_failed", "growth_policy_failed", "tutorial_policy_failed", "frame_budget_exhausted", "run_ended/failure", "run_ended/victory"}
    outcomes.update("deep_policy_failed/" + str(a["id"]) for a in capture["manifest"]["areas"])
    if capture.get("outcome") not in outcomes or capture["route_reached"] != (capture["outcome"] == "route_target_reached"):
        raise ValueError("Invalid observed route outcome")
    for edge in capture["edges"]:
        terminal_end = previous
        if edge.get("aborted") is True and edge.get("reached") is False:
            terminal = capture.get("terminal_observation", {})
            if terminal.get("tick") == previous + 1 and any(e["kind"] == "run_ended" and e["tick"] == previous + 1 for e in capture.get("events", [])):
                terminal_end = previous + 1
        if edge.get("id") not in allowed_edges or type(edge.get("reached")) is not bool or type(edge.get("start_tick")) is not int or type(edge.get("end_tick")) is not int or not 1 <= edge["start_tick"] <= edge["end_tick"] <= terminal_end:
            raise ValueError("Invalid actual route interval")
    if capture.get("capture_contract_version") in (2,3):
        validate_policy_capture(capture)
    elif "capture_contract_version" in capture or "policy_basis" in capture or "encounter_policy" in capture:
        raise ValueError("Unknown incomplete policy protocol")
    return capture


def validate_policy_capture(capture):
    from level_formal import ENCOUNTER_POLICIES, driver_source_paths, core_source_paths
    basis = capture.get("policy_basis", {})
    if basis.get("schema_version") != 1 or capture.get("encounter_policy") not in ENCOUNTER_POLICIES or basis.get("encounter_policy") != capture["encounter_policy"]:
        raise ValueError("Invalid explicit encounter policy identity")
    for field, expected in (("driver_sources",driver_source_paths()),("core_invariants",core_source_paths())):
        actual = basis.get(field)
        if not isinstance(actual,dict) or set(actual) != {"res://"+p for p in expected} or any(not isinstance(v,str) or not re.fullmatch(r"[0-9a-f]{64}",v) for v in actual.values()):
            raise ValueError("Incomplete actual policy source basis/"+field)
    receipts=capture.get("resource_receipts")
    observations=capture.get("policy_observations")
    if not isinstance(receipts,list) or not isinstance(observations,list): raise ValueError("Missing actual policy receipts")
    indexed={}
    for receipt in receipts:
        required=("event_id","operation","status","amount_applied","requested_amount","current","capacity","tick","session_id","epoch")
        if not isinstance(receipt,dict) or any(k not in receipt for k in required): raise ValueError("Incomplete actual resource receipt")
        if receipt["status"]!=0 or not isinstance(receipt["event_id"],str) or not receipt["event_id"] or type(receipt["tick"]) is not int or not 1<=receipt["tick"]<=capture["tick_count"]+1: raise ValueError("Non-applied/out-of-window receipt")
        for key in ("amount_applied","requested_amount","current","capacity"):
            if type(receipt[key]) not in (int,float) or not math.isfinite(receipt[key]):raise ValueError("Invalid resource amount")
        if not 0<=receipt["current"]<=receipt["capacity"] or receipt["requested_amount"]<=0:raise ValueError("Invalid resource state")
        key=(receipt["epoch"],receipt["event_id"])
        if key in indexed:raise ValueError("Duplicate actual receipt")
        indexed[key]=receipt
    shots={}
    energy=capture["initial_capability"]["shot_energy"]
    free=energy.get("shooting_consumes_energy") is False
    if free:
        policy="res://game/player/resources/demo_ui_01/time_energy_v2.tres"
        cap=capture["initial_capability"]
        if energy.get("definition_path")!=policy or energy.get("definition_version")!=2 or energy.get("definition_sha256")!=sha(ROOT/policy[6:]) or cap.get("config_hashes",{}).get("shot_energy")!=energy["definition_sha256"] or cap.get("config_hashes",{}).get("player_tuning")!=sha(ROOT/"config/player_tuning.json"):
            raise ValueError("Current free-shot policy/config provenance differs from actual source")
        if receipts:raise ValueError("Current time energy cannot contain paid-shot/hit or invented eventful receipts")
        frames=capture["frames"];tuning=cap["tuning"];previous=energy["current"];focus_deltas={}
        actual_tuning=read(ROOT/"config/player_tuning.json")
        if type(tuning.get("max_air_shots")) is not int or any(tuning.get(key)!=actual_tuning[key] for key in ("max_air_shots","focus_stamina_drain","focus_stamina_recovery","focus_max_air_duration")) or cap.get("physics_hz")!=actual_tuning["physics_hz"]:raise ValueError("Current time/air budget differs from actual config")
        setup=capture.get("state",{}).get("focus_setup",{})
        changes=setup.get("transactions",[])
        if setup:
            state=capture.get("state",{})
            if capture.get("natural_low") is not True or setup.get("input")!="actual_router_jumpheld_and_airborne_aim" or setup.get("policy_path")!=policy or setup.get("policy_sha256")!=energy["definition_sha256"] or setup.get("released") is not True or not changes or any(not state.get("entry_tick",0)<tx.get("tick",-1)<=state.get("low_tick",0) for tx in changes):raise ValueError("Current focus ledger is outside the actual low-entry input window")
            if not math.isclose(setup.get("initial",-1),frames[state["entry_tick"]-1]["shot_energy"],abs_tol=.001):raise ValueError("Current focus initial state differs from actual entry frame")
        if type(cap.get("air_shot_flight_cap")) is not int or cap["air_shot_flight_cap"]!=tuning["max_air_shots"]:raise ValueError("Current air-charge budget differs from actual tuning")
        for frame in frames:
            tick=frame["tick"];balance=previous;transactions=[tx for tx in changes if tx["tick"]==tick]
            if not 0<=frame["shots"]<=cap["air_shot_flight_cap"]:raise ValueError("Current air-charge capacity exceeded")
            for tx in transactions:
                if tx["epoch"]!=frame["resource_epoch"] or tx["session_id"]!=frame["session_id"] or tx["grounded"]!=frame["grounded"] or tx["capacity"]!=energy["capacity"] or not math.isclose(balance+tx["amount"],tx["current"],abs_tol=.001):raise ValueError("Current focus transaction time/session/epoch/balance differs")
                if not 0<tx["real_delta"]<=1/cap["physics_hz"]+.00001:raise ValueError("Current focus transaction delta outside native clock")
                if tx["amount"]<0:
                    expected=min(balance,tuning["focus_stamina_drain"]*min(tx["real_delta"],max(0,tuning["focus_max_air_duration"]-tx["focus_air_before"])))
                    if tx["operation"]!="consume" or tx["grounded"] or not tx["aiming"] or not tx["focus_active"] or not math.isclose(-tx["amount"],expected,abs_tol=.001):raise ValueError("Current time energy lacks actual airborne-focus consumption")
                elif tx["operation"]!="grant" or not tx["grounded"] or not math.isclose(tx["amount"],min(energy["capacity"]-balance,tuning["focus_stamina_recovery"]*tx["real_delta"]),abs_tol=.001):raise ValueError("Current time credit is not actual grounded-focus recovery")
                balance=tx["current"]
            if not transactions and frame["grounded"]:balance=min(energy["capacity"],balance+tuning["focus_stamina_recovery"]/cap["physics_hz"])
            if not math.isclose(balance,frame["shot_energy"],abs_tol=.001):raise ValueError("Current time-energy frame differs from genuine focus/ground ledger")
            focus_deltas[tick]=balance-previous
            previous=frame["shot_energy"]
        if any(type(tx.get("tick")) is not int or not 1<=tx["tick"]<=capture["tick_count"] for tx in changes):raise ValueError("Current focus transaction outside capture")
    for event in capture["events"]:
        if event["kind"]!="shot_accepted":continue
        required=("owner_id","session_id","shot_id","packet_id","resource_epoch","event_id","projectile_direction","energy_after")
        if any(k not in event for k in required):raise ValueError("Missing actual projectile identity")
        eid=f"{event['owner_id']}:{event['session_id']}:{event['shot_id']}"
        if event["event_id"]!=eid or eid in shots:raise ValueError("Forged/repeated projectile identity")
        pair(event["projectile_direction"],"projectile direction")
        if event["projectile_direction"]!=event["direction"]:raise ValueError("Accepted/projectile aim mismatch")
        rid=f"shot/{event['session_id']}/{event['packet_id']}"
        consumption=[r for r in receipts if r["event_id"]==rid]
        if free:
            frame=capture["frames"][event["tick"]-1]
            if consumption or event["session_id"]!=frame["session_id"] or event["resource_epoch"]!=frame["resource_epoch"] or not 0<=event["energy_after"]<=energy["capacity"] or not math.isclose(event["energy_after"]+focus_deltas[event["tick"]],frame["shot_energy"],abs_tol=.001):raise ValueError("Free accepted projectile has paid receipt or wrong actual session/epoch/frame energy")
        else:
            if len(consumption)!=1 or consumption[0]["operation"]!="consume" or not math.isclose(consumption[0]["amount_applied"],-energy["shot_energy_cost"],abs_tol=1e-6) or consumption[0]["requested_amount"]!=energy["shot_energy_cost"]:raise ValueError("Accepted shot missing APPLIED energy consumption")
            consumed=consumption[0]
            if consumed["tick"]!=event["tick"] or consumed["epoch"]!=event["resource_epoch"] or consumed["session_id"]!=event["session_id"] or not math.isclose(consumed["current"],event["energy_after"],abs_tol=1e-6):raise ValueError("Shot receipt has wrong actual time/session/epoch/balance")
        shots[eid]=event
    for event in capture["events"]:
        if event["kind"]!="damage_committed":continue
        if "event_id" not in event or "damage_kind" not in event or "health_after" not in event:raise ValueError("Missing committed damage identity")
        if type(event["damage_kind"]) is not int or event["damage_kind"] not in (0,1) or type(event["health_after"]) not in (int,float) or not math.isfinite(event["health_after"]) or event["health_after"]<0 or event.get("lethal")!=(event["health_after"]==0):raise ValueError("Invalid committed health/kind semantics")
        if str(event.get("source","")).startswith("player_projectile:"):
            shot=shots.get(event["event_id"])
            if shot is None:raise ValueError("Committed hit lacks accepted actual projectile")
            if event["source"]!=f"player_projectile:{shot['owner_id']}" or event["damage_kind"]!=0:raise ValueError("Committed hit source differs from accepted owner")
            hit_id=f"hit/{shot['session_id']}/{shot['packet_id']}"
            refunds=[r for r in receipts if r["event_id"]==hit_id]
            if free:
                if refunds:raise ValueError("Free committed projectile invented a time-energy refund")
                continue # Actual projectile/owner/kind/health checks above still apply.
            # Fatal batches invalidate the actor before refunds; never fabricate it.
            fatal_same_tick=any(e["kind"]=="damage_committed" and e.get("target")=="player" and e.get("lethal") is True and e["tick"]==event["tick"] and e.get("actor_epoch")==event.get("actor_epoch") for e in capture["events"])
            ended_same_tick=any(e["kind"]=="run_ended" and e.get("reason")=="failure" and e["tick"]==event["tick"] for e in capture["events"])
            if not refunds and fatal_same_tick and ended_same_tick:continue
            if len(refunds)!=1 or refunds[0]["operation"]!="grant" or refunds[0]["requested_amount"]!=energy["hit_energy_recovery"] or not 0<=refunds[0]["amount_applied"]<=energy["hit_energy_recovery"]:raise ValueError("Committed hit lacks actual clamped refund receipt")
            refund=refunds[0]
            if refund["tick"]!=event["tick"] or refund["epoch"]!=shot["resource_epoch"] or refund["session_id"]!=shot["session_id"] or event["tick"]<shot["tick"]:raise ValueError("Hit refund has wrong actual time/session/epoch")
            expected=min(refund["requested_amount"],refund["capacity"]-(refund["current"]-refund["amount_applied"]))
            if not math.isclose(refund["amount_applied"],expected,abs_tol=1e-6):raise ValueError("Hit refund amount does not match real capacity clamp")
    committed_ids={e.get("event_id") for e in capture["events"] if e["kind"]=="damage_committed" and str(e.get("source","")).startswith("player_projectile:")}
    for refund in receipts:
        if refund["event_id"].startswith("hit/"):
            matching=[e for e in shots.values() if refund["event_id"]==f"hit/{e['session_id']}/{e['packet_id']}" and e["event_id"] in committed_ids]
            if not matching:raise ValueError("Hit refund lacks actual committed projectile damage")
    for observation in observations:
        if not isinstance(observation,dict) or type(observation.get("tick")) is not int or not 0<=observation["tick"]<=capture["tick_count"]+1:raise ValueError("Invalid policy observation tick")
        if observation.get("kind")=="actual_enemy_dead":
            commits=[e for e in capture["events"] if e["kind"]=="damage_committed" and e.get("target")==observation.get("enemy") and e.get("lethal") is True and e["tick"]<=observation["tick"]]
            if observation.get("health")!=0 or not commits:raise ValueError("Claimed enemy death lacks real terminal committed damage")
        if observation.get("kind")=="actual_cache_claim":
            validate_cache_claim(capture,observation)
            identity=observation.get("chest")
            if observation.get("claimed") is not True or not observation.get("claim_output") or observation.get("claim_output",{}).get("choice")!=observation.get("choice"):raise ValueError("Claimed cache lacks production output")
            final=capture.get("final_runtime",{})
            if identity not in final.get("claimed_ids",[]) or not any(c.get("id")==identity and c.get("claimed") is True for c in final.get("chests",[])):raise ValueError("Claimed cache lacks actual terminal ledger")
            submissions=[e for e in capture["events"] if e["kind"]=="reward_modal_submission" and e.get("offer_id")==identity and e.get("choice")==observation.get("choice") and e["tick"]<=observation["tick"]]
            if len(submissions)!=1:raise ValueError("Claimed cache lacks unique actual modal submission")
            frame=capture["frames"][observation["tick"]-1]
            if not frame.get("grounded") or math.dist(frame["position"],observation.get("position",[]))>2:raise ValueError("Cache callback not at actual supported frame")
    return capture


def validate_cache_claim(capture, observation):
    """Resource proof v3; v2 retains its explicitly partial historical evidence.

    This verifies recorded native transactions, not independent authentication.
    Wallet/health/meta dictionaries are actual service ledgers, never AI payouts.
    """
    identity=observation.get("chest");output=observation.get("claim_output",{})
    if not isinstance(identity,str) or not isinstance(output,dict):raise ValueError("Invalid cache identity/output")
    stages=capture.get("formal_run_manifest_final",{}).get("stages",[])
    matching=[s for s in stages if s.get("stage_index")==capture.get("map_index")]
    if len(matching)!=1 or matching[0].get("outputs",{}).get("cache/"+identity)!=output:
        raise ValueError("Cache output differs from actual final stage output")
    if any("cache/"+identity in s.get("outputs",{}) for s in stages if s not in matching):raise ValueError("Cache output in wrong stage")
    resource=output.get("resource");amount=output.get("amount")
    if resource not in {"coin","heart","note"} or isinstance(amount,bool) or not isinstance(amount,(int,float)) or not math.isfinite(amount) or amount<=0 or int(amount)!=amount:
        raise ValueError("Unsupported/unrecorded resource reward")
    rewards=[r for r in capture.get("manifest",{}).get("rewards",[]) if identity==r.get("id") or identity.endswith("/"+str(r.get("id")))]
    if len(rewards)!=1:raise ValueError("Missing unique generated cache")
    if resource!="note" and not any(r.get("kind")==resource and r.get("amount")==amount for r in rewards[0].get("resources",[])):
        raise ValueError("Resource reward not in generated cache")
    before=observation.get("before",{});after=observation.get("after",{})
    grants=observation.get("wallet_receipts")
    if not isinstance(grants,dict):raise ValueError("Missing actual wallet receipts")
    if capture.get("capture_contract_version")==2:
        # Historical v2 did not record offers or pre-transaction HP/meta ledgers.
        # Do not invent that evidence or silently label it as v3-complete.
        if resource=="coin":
            matching_receipts=[v for k,v in grants.items() if k.endswith("/"+identity+"/resource")]
            if matching_receipts!=[amount] or after.get("coins",0)-before.get("coins",0)<amount:raise ValueError("Legacy cache missing actual wallet receipt/effect")
        elif resource=="note":
            if after.get("meta",{}).get("notes",0)-before.get("meta",{}).get("notes",0)<amount:raise ValueError("Legacy cache missing note effect")
        elif after.get("health",0)<=before.get("health",0):raise ValueError("Legacy cache missing heal effect")
        return
    transaction=observation.get("transaction")
    if not isinstance(transaction,dict) or transaction.get("schema_version")!=1 or transaction.get("stage_index")!=capture.get("map_index"):raise ValueError("Missing/wrong native cache transaction")
    prefix=transaction.get("receipt_prefix")
    if not isinstance(prefix,str) or not prefix:raise ValueError("Missing actual run receipt prefix")
    event_id=prefix+"/"+identity+"/resource"
    offer=transaction.get("offer",{})
    candidates=offer.get("candidates",[])
    if offer.get("offer_id")!=identity or not isinstance(candidates,list) or not candidates or len({c.get("id") for c in candidates})!=len(candidates):raise ValueError("Invalid actual cache offer")
    selected=[c for c in candidates if c.get("id")==observation.get("choice")]
    if len(selected)!=1 or selected[0].get("kind")!="resource" or selected[0].get("valid") is not True or selected[0].get("resource")!=resource or selected[0].get("amount")!=amount:
        raise ValueError("Selected actual offer differs from committed output")
    first=transaction.get("before",{});last=transaction.get("after",{})
    for view,state in [(before,first),(after,last)]:
        if any(view.get(k)!=state.get(k) for k in ["coins","health","meta"]):raise ValueError("Cache effects differ from native transaction snapshots")
    if grants!=last.get("wallet_grants"):raise ValueError("Actual wallet receipt projection mismatch")
    def delta(field):
        a=first.get(field);b=last.get(field)
        if not isinstance(a,dict) or not isinstance(b,dict) or any(k not in b or b[k]!=v for k,v in a.items()):raise ValueError("Changed/deleted existing "+field)
        return {k:v for k,v in b.items() if k not in a}
    wallet_delta=delta("wallet_grants");health_delta=delta("health_receipts");meta_delta=delta("meta_receipts")
    if any(isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or v<0 or int(v)!=v for v in last["wallet_grants"].values()):raise ValueError("Invalid wallet transaction amount")
    if last["coins"]-first["coins"]!=sum(wallet_delta.values()):raise ValueError("Wallet net effects differ from all new grants")
    if first.get("health_epoch")!=last.get("health_epoch") or first.get("health_capacity")!=last.get("health_capacity"):raise ValueError("Cache proof crosses health lifecycle/capacity")
    capacity=last.get("health_capacity")
    if not isinstance(capacity,(int,float)) or not math.isfinite(capacity) or capacity<=0:raise ValueError("Missing health capacity")
    for key,r in health_delta.items():
        if not isinstance(r,dict) or r.get("event_id")!=key or type(r.get("status")) is not int or r.get("status")!=0 or r.get("epoch")!=last["health_epoch"] or r.get("capacity")!=capacity or r.get("operation") not in {"heal","damage","grant"}:raise ValueError("Invalid actual health receipt")
        requested=r.get("requested_amount");applied=r.get("amount_applied");current=r.get("current")
        if any(isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) for v in [requested,applied,current]) or requested<=0 or not 0<=current<=capacity:raise ValueError("Invalid actual health amounts")
        previous=current-applied
        expected=-min(requested,previous) if r["operation"]=="damage" else min(requested,capacity-previous)
        if not 0<=previous<=capacity or abs(applied-expected)>1e-5:raise ValueError("Actual heal/damage clamp mismatch")
    if abs(last["health"]-first["health"]-sum(r["amount_applied"] for r in health_delta.values()))>1e-5:raise ValueError("Health effects differ from all new native receipts")
    if any(not isinstance(r,dict) or r.get("kind")!="notes" or isinstance(r.get("amount"),bool) or not isinstance(r.get("amount"),(int,float)) or r["amount"]<=0 or int(r["amount"])!=r["amount"] for r in meta_delta.values()):raise ValueError("Invalid native note receipt")
    meta_before=first.get("meta",{});meta_after=last.get("meta",{})
    for field in ["notes","meta_currency"]:
        if meta_after.get(field,0)-meta_before.get(field,0)!=sum(r["amount"] for r in meta_delta.values()):raise ValueError("Meta effects differ from new note receipts")
    if meta_after.get("profile_revision",0)-meta_before.get("profile_revision",0)!=len(meta_delta):raise ValueError("Note persistence revision mismatch")
    for field in set(meta_before)|set(meta_after):
        if field not in {"notes","meta_currency","profile_revision","save_status"} and meta_before.get(field)!=meta_after.get(field):raise ValueError("Unexplained meta mutation during resource claim")
    ledger={"coin":wallet_delta,"heart":health_delta,"note":meta_delta}[resource]
    if event_id not in ledger or event_id in first[{"coin":"wallet_grants","heart":"health_receipts","note":"meta_receipts"}[resource]]:raise ValueError("Missing unique new selected resource receipt")
    suffix="/"+identity+"/resource"
    if [(kind,key) for kind,rows in [("coin",wallet_delta),("heart",health_delta),("note",meta_delta)] for key in rows if key.endswith(suffix)]!=[(resource,event_id)]:raise ValueError("Duplicate/cross-resource selected reward receipt")
    receipt=ledger[event_id]
    if resource=="coin" and receipt!=amount:raise ValueError("Selected coin receipt differs from offer")
    if resource=="heart" and (receipt.get("operation")!="heal" or receipt.get("requested_amount")!=amount or receipt.get("amount_applied",0)<=0):raise ValueError("Selected heal receipt differs from offer/actual eligibility")
    if resource=="note" and receipt!={"kind":"notes","amount":amount}:raise ValueError("Selected note receipt differs from offer")


def capability_basis(capture):
    capability = capture["initial_capability"]
    return {key: capability.get(key) for key in (
        "equipped_weapon", "granted_actions", "tuning", "config_hashes", "effective_max_jumps",
        "air_shot_flight_cap", "shot_energy", "combat_energy", "build", "air_shots", "physics_hz")}


def scenery_facts(capture):
    areas = capture["manifest"]["areas"]
    eligible = [a["id"] for a in areas if a.get("role") in {"rest", "camp", "junction", "entry", "merchant"}]
    rows = [row for scene in capture.get("initial_scenery_inventory", []) for row in scene.get("descendants", [])]
    props = [row for row in rows if row.get("class") == "Sprite2D" and (
        row.get("texture") or row.get("texture_class") not in (None, "GradientTexture2D") or row.get("landmark_id"))]
    def asset_identity(row):
        if "texture_atlas" in row or "landmark" in row:
            return (row.get("landmark_id") or row.get("landmark", {}).get("asset_id")
                    or row.get("texture") or row.get("texture_atlas") or "unknown")
        # Retained pre-atlas inventories remain reproducible. Their empty asset
        # strings/texture class labels express unknown identity, never approval.
        return row.get("landmark_id", row.get("texture", row.get("texture_class", "unknown")))
    return {"eligible_areas": eligible, "textured_prop_nodes": len(props),
            "prop_assets": dict(Counter(asset_identity(row) for row in props)),
            "inventory_scope": "actual instantiated scenery, not GPU aesthetic approval"}


def analysis_revision(version):
    if type(version) is not int or version not in (1, 2):
        raise ValueError("Unknown experience analysis revision")
    return version


def analyze_capture(capture, policy=None, analysis_version=2):
    analysis_revision(analysis_version)
    validate_capture(capture)
    policy = dict(POLICY if policy is None else policy)
    if set(policy) != set(POLICY) or not isinstance(policy["id"], str) or not policy["id"] or policy["calibration"] != "uncalibrated_candidates":
        raise ValueError("Observation policy must be explicit and bounded, not a quality score")
    for key in ("walk_seconds", "walk_distance", "near_enemy_distance"):
        if type(policy[key]) not in (int, float) or not math.isfinite(policy[key]) or policy[key] <= 0:
            raise ValueError("Invalid observation threshold")
    frames, events = capture["frames"], capture.get("events", [])
    diagnostics, walk, last_runtime = [], [], {}
    signatures, counts = [], Counter(e["kind"] for e in events)

    def finish_walk():
        if len(walk) > 1:
            duration = len(walk) / capture["physics_hz"]
            distance = sum(math.dist(a["position"], b["position"]) for a, b in zip(walk, walk[1:]))
            if duration >= policy["walk_seconds"] and distance >= policy["walk_distance"]:
                diagnostics.append({"kind": "low_interaction_candidate", "source_kind": "computed_proxy", "quality_dimension": "Q5",
                    "edge": walk[0]["edge"], "start_tick": walk[0]["tick"], "end_tick": walk[-1]["tick"], "seconds": duration,
                    "distance": distance, "position": walk[0]["position"], "reason": "continuous grounded movement without accepted action, nearby observed live enemy or resource change",
                    "limits": "May be intentional observation, recovery or story space; design intent and rendered footage must decide"})
        walk.clear()

    previous = None
    for frame in frames:
        if "runtime" in frame:
            last_runtime = frame["runtime"]
        meaningful = [e["kind"] for e in frame["accepted_events"] if e["kind"] in {
            "jump_accepted", "shot_accepted", "landed", "energy_recovered", "damage_committed", "segment_returned", "reward_modal_submission"}]
        signatures.extend(meaningful)
        near = any(not enemy.get("terminal") and math.dist(enemy["position"], frame["position"]) <= policy["near_enemy_distance"]
                   for enemy in last_runtime.get("enemies", []))
        resource_change = previous is not None and any(frame[k] != previous[k] for k in ("health", "shot_energy", "shots", "recovery_count"))
        if frame.get("grounded") and abs(frame.get("axis", 0)) > .1 and not meaningful and not near and not resource_change:
            if walk and walk[-1]["edge"] != frame["edge"]:
                finish_walk()
            walk.append(frame)
        else:
            finish_walk()
        previous = frame
    finish_walk()
    for event in events:
        if event["kind"] in ("died", "segment_returned", "damage_committed"):
            diagnostics.append({"kind": event["kind"], "source_kind": "engine_fact", "quality_dimension": "Q8", **event,
                                "limits": "Observed input-policy outcome; not proof all human strategies fail"})
    scenery = scenery_facts(capture)
    if scenery["eligible_areas"] and scenery["textured_prop_nodes"] == 0:
        diagnostics.append({"kind": "missing_instantiated_landmarks", "source_kind": "engine_fact", "quality_dimension": "Q6",
            "areas": scenery["eligible_areas"], "reason": "eligible authored landmarks but no textured prop instantiated in actual scenery",
            "limits": "Does not measure subjective beauty or other background consumers"})
    runtime_frames = [f for f in frames if "runtime" in f]
    enemy_ids = {e["id"] for f in runtime_frames for e in f["runtime"].get("enemies", [])}
    case = {"root_seed": capture["root_seed"], "map_index": capture["map_index"], "strategy": capture["strategy"], "phase_wait_ticks": capture["phase_wait_ticks"]}
    return {"case": case, "manifest_hash": capture["manifest_hash"], "source_commit": capture["source_commit"],
        "observer_basis": capture["policy_basis"]["driver_sources"] if capture.get("capture_contract_version") in (2,3) else capture.get("capture_source_hashes", {}),
        **({"policy_basis":capture["policy_basis"],"capture_contract_version":capture["capture_contract_version"]} if capture.get("capture_contract_version") in (2,3) else {}),
        "capability_basis": capability_basis(capture), "physics_hz": capture["physics_hz"], "captured_scope": capture["captured_scope"],
        "outcome": capture["outcome"], "route_reached": capture["route_reached"], "edges": capture["edges"],
        "stats": {"ticks": capture["tick_count"], "seconds": capture["tick_count"] / capture["physics_hz"],
            **({"player_damage_events": sum(e["kind"] == "damage_committed" and e.get("target") == "player" for e in events),
                "non_player_damage_events": sum(e["kind"] == "damage_committed" and bool(e.get("target")) and e["target"] != "player" for e in events),
                "unknown_target_damage_events": sum(e["kind"] == "damage_committed" and not e.get("target") for e in events)} if analysis_version == 2 else {}),
            "observed_enemies": len(enemy_ids), "accepted_events": dict(counts), "reached_edges": sum(e.get("reached", False) for e in capture["edges"]),
            "low_interaction_candidates": sum(d["kind"] == "low_interaction_candidate" for d in diagnostics),
            "textured_prop_nodes": scenery["textured_prop_nodes"]},
        "scenery": scenery, "action_signature": signatures, "diagnostics": diagnostics, "screenshots": capture.get("screenshots", []),
        "unverified": ["Boss fight/campaign completion", "all possible player strategies", "device feel and performance", "subjective fun/beauty", "weapon builds not actually equipped"]}


def report(capture_paths, policy=None, analysis_version=2):
    analysis_revision(analysis_version)
    cases, artifacts = [], []
    for path in capture_paths:
        capture = read(path)
        # Baseline evidence remains analyzable after a change. Validate against
        # its recorded source snapshot, never relabel it as current/fresh proof.
        from level_formal import validate_capture as validate_invocation, find_legacy_migration
        path = Path(path)
        receipt_path = path.with_suffix(".invocation.json")
        receipt = read(receipt_path)
        errors = validate_invocation(path, capture, receipt, path.with_suffix(".log"), current_sources=receipt.get("source_files"), legacy_migration=find_legacy_migration(path))
        for source, value in capture.get("capture_source_hashes", {}).items():
            if receipt.get("source_files", {}).get(source.removeprefix("res://")) != value:
                errors.append("observer source differs from invocation receipt")
        if errors:
            raise ValueError("Formal invocation inconsistent: " + "; ".join(errors))
        cases.append(analyze_capture(capture, policy, analysis_version))
        artifacts.append({"path": str(path), "sha256": sha(path), "kind": "formal_capture", "receipt": str(receipt_path), "receipt_sha256": sha(receipt_path)})
    if not cases or len({fingerprint(c["case"]) for c in cases}) != len(cases):
        raise ValueError("Experience report needs nonempty unique actual cases")
    dimensions = {"Q" + str(i + 1): {"dimension": name, "status": "review", "evidence_basis": "engine facts and bounded proxies; independent design review required"}
                  for i, name in enumerate(DIMENSIONS)}
    result = {"schema_version": 1, "artifact_kind": "level_experience_report", "verdict": "REVIEW",
              "policy": dict(POLICY if policy is None else policy), "dimensions": dimensions,
              "cases": cases, "artifacts": artifacts, "player_acceptance": "unverified", "device_acceptance": "unverified",
              "provenance": "local_invocation_consistency_not_external_authentication; historical source snapshots retained",
              "worst_candidates": [c["case"] for c in sorted(cases, key=lambda c: (c["route_reached"], -(c["stats"]["player_damage_events"] if analysis_version == 2 else c["stats"]["accepted_events"].get("damage_committed", 0)), -c["stats"]["low_interaction_candidates"]))[:10]]}
    # v1 archives keep their exact original schema/fingerprint and old ordering.
    # New ordering isolates harm to the player from successful shots at enemies
    # or switches; none of these counts is a human difficulty/fun score.
    if analysis_version == 2:
        result["analysis_version"] = analysis_version
    result["fingerprint"] = fingerprint(result)
    return result


def validate_report(value):
    if not isinstance(value, dict) or value.get("artifact_kind") != "level_experience_report" or value.get("schema_version") != 1 or not value.get("cases") or not value.get("artifacts"):
        raise ValueError("Empty or wrong experience report")
    payload = {k: v for k, v in value.items() if k != "fingerprint"}
    if value.get("fingerprint") != fingerprint(payload):
        raise ValueError("Experience report fingerprint mismatch")
    if len({fingerprint(c["case"]) for c in value["cases"]}) != len(value["cases"]):
        raise ValueError("Duplicate experience cases")
    if len(value["artifacts"]) != len(value["cases"]) or set(value.get("dimensions", {})) != {"Q"+str(i) for i in range(1,9)}:
        raise ValueError("Incomplete case evidence or Q1–Q8 coverage declarations")
    for artifact in value["artifacts"]:
        if not re.fullmatch(r"[0-9a-f]{64}",str(artifact.get("sha256",""))) or not re.fullmatch(r"[0-9a-f]{64}",str(artifact.get("receipt_sha256",""))) or not artifact.get("path") or not artifact.get("receipt"):
            raise ValueError("Missing artifact/receipt bindings")
        path, receipt = Path(artifact["path"]).resolve(), Path(artifact["receipt"]).resolve()
        if not path.is_relative_to(ROOT / "build") or receipt != path.with_suffix(".invocation.json"):
            raise ValueError("Evidence must reference the actual retained formal capture and invocation")
        if not path.is_file() or not receipt.is_file() or sha(path) != artifact["sha256"] or sha(receipt) != artifact["receipt_sha256"]:
            raise ValueError("Missing or changed experience evidence")
    # A digest only detects byte changes; it does not prove any statistic,
    # interval or acceptance claim. Recompute the complete bounded report from
    # its retained, invocation-validated captures. This also validates policy
    # semantics and prevents edits to Q/player/device states from becoming PASS.
    expected = report([a["path"] for a in value["artifacts"]], value.get("policy"), analysis_revision(value.get("analysis_version", 1)))
    if value != expected:
        raise ValueError("Experience report differs from actual derived evidence; subjective acceptance cannot be injected")
    return value


def compare(before, after):
    validate_report(before); validate_report(after)
    if analysis_revision(before.get("analysis_version", 1)) != analysis_revision(after.get("analysis_version", 1)):
        raise ValueError("Experience analysis revision changed; reanalyze both retained cohorts")
    if before["policy"] != after["policy"]:
        raise ValueError("Observation policy changed; comparison cannot infer improvement")
    left, right = ({fingerprint(c["case"]): c for c in r["cases"]} for r in (before, after))
    if left.keys() != right.keys():
        raise ValueError("Seed/map/strategy/phase cohort mismatch")
    comparisons = []
    for key, a in left.items():
        b = right[key]
        if a.get("capture_contract_version") != b.get("capture_contract_version") or a.get("policy_basis") != b.get("policy_basis"):
            raise ValueError("Encounter/reward policy, transitive driver or core implementation changed")
        if a["capability_basis"] != b["capability_basis"] or a["physics_hz"] != b["physics_hz"] or a["captured_scope"] != b["captured_scope"] or a.get("observer_basis") != b.get("observer_basis"):
            raise ValueError("Capability, device/consumer scope or physics mismatch")
        comparisons.append({"case": a["case"], "before_source": a["source_commit"], "after_source": b["source_commit"],
            "manifest_changed": a["manifest_hash"] != b["manifest_hash"], "actual_action_changed": a["action_signature"] != b["action_signature"],
            "outcome": [a["outcome"], b["outcome"]], "stats_delta": {k: b["stats"][k] - a["stats"][k] for k in a["stats"] if k != "accepted_events"},
            "event_delta": {k: b["stats"]["accepted_events"].get(k, 0) - a["stats"]["accepted_events"].get(k, 0) for k in set(a["stats"]["accepted_events"]) | set(b["stats"]["accepted_events"])}})
    return {"schema_version": 1, "artifact_kind": "level_experience_comparison", "verdict": "REVIEW", "cases": comparisons,
            "before_fingerprint": before["fingerprint"], "after_fingerprint": after["fingerprint"],
            "limits": "Differences are measured effects; subjective fun and visual appeal still require review/player evidence"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    analyze = sub.add_parser("analyze"); inputs=analyze.add_mutually_exclusive_group(required=True); inputs.add_argument("--captures", nargs="+"); inputs.add_argument("--batch"); analyze.add_argument("--output", required=True)
    comparator = sub.add_parser("compare"); comparator.add_argument("--before", required=True); comparator.add_argument("--after", required=True); comparator.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    if args.command == "analyze":
        paths=args.captures
        if args.batch:
            batch=read(args.batch)
            if batch.get("artifact_kind")!="formal_capture_batch" or not batch.get("cases") or batch.get("captured_cases")!=len(batch["cases"]) or batch.get("requested_cases")!=len(batch["cases"]) or not all(c.get("captured") for c in batch["cases"]):
                raise ValueError("Incomplete formal batch; preserve failed cases rather than filtering them away")
            paths=[ROOT/c["capture"] for c in batch["cases"]]
        result=report(paths)
    else:
        result=compare(read(args.before),read(args.after))
    output = Path(args.output); output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    print("EXPERIENCE REVIEW:", len(result["cases"]), "actual cases; subjective acceptance unverified;", output)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, TypeError) as error:
        print("Experience rejected:", error, file=sys.stderr); sys.exit(1)
