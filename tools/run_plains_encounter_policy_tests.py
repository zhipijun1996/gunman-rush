"""Original Harness specialty: actual input, causal receipts and versioned replay.

Native fixtures are labelled fixtures. Four paired formal captures and a live
normal-failure/retry retain failures; a captured route failure is not a pass.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import tarfile
import time

import harness
import level_formal as formal
import level_experience as experience
from level_design import ROOT, read, write

MARKER = r"^PLAINS ENCOUNTER POLICY: [1-9]\d* assertions, 0 failures, [1-9]\d* cases$"
ERRORS = r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit"
CASES = [("level-design-v2-baseline",1,"return"), ("level-design-v2-baseline",2,"fast"),
         ("level-design-v2-baseline",2,"growth"), ("level-design-v2-baseline/01",1,"fast")]

def require(ok, reason):
    if not ok: raise ValueError(reason)








def validate_native(data, recovery=False, reward_resource=""):
    require(data.get("artifact_kind")=="actual_encounter_policy_proof" and data.get("schema_version")==1 and data.get("failures")==0 and data.get("assertions",0)>0,"empty/failed native proof")
    rows=data.get("cases",[])
    require(isinstance(rows,list) and bool(rows),"missing actual cases")
    expected={"formal_pit_return_retry"} if recovery else {"solid_occlusion","cooldown_rejected","air_energy_rejected"}|{"kill_and_dead_"+b for b in ["patrol","charger","diver","hopper","sentry","fan_sentry"]}|{"bait_state_"+b for b in ["charger","diver","hopper","sentry","fan_sentry"]}
    require({r.get("id") for r in rows}==expected and len(rows)==len(expected),"actual case matrix incomplete/repeated")
    for row in rows:
        frames=row.get("frames"); events=row.get("events")
        require(isinstance(frames,list) and bool(frames) and isinstance(events,list),"empty actual trajectory")
        require([f.get("tick") for f in frames]==list(range(1,len(frames)+1)),"discontinuous actual physics observation")
        if recovery:
            require(row.get("scope")=="actual_live_CampaignFixture_normal_start" and row.get("same_scene") is True,"wrong formal consumer")
            returns=[e for e in events if e.get("kind")=="segment_returned"]
            damage=[e for e in events if e.get("kind")=="damage_committed" and e.get("target")=="player" and e.get("damage_kind")==1]
            expected_returns=2 if reward_resource=="heart" else 1
            require(len(returns)==expected_returns and len(damage)==expected_returns and all(r["tick"]==d["tick"] for r,d in zip(returns,damage)),"failure/recovery lacks actual environment causality")
            require(row["before_health"]-row["after_health"]==1 and row["after_session"]==row["before_session"]+1 and row.get("recovery_count")==expected_returns,"invalid selective recovery")
            require(row.get("latch_open") is True and row.get("claimed_after") is True and row["wallet_before"]==row["wallet_after"],"committed world/reward state not retained")
            require(any(e.get("kind")=="jump_accepted" and e["tick"]>returns[-1]["tick"] for e in events),"missing actual retry jump")
            require(sum((a-b)**2 for a,b in zip(row["retry_position"],row["expected_exit"]))<4 and frames[-1]["grounded"],"retry never reaches grounded exit")
            require(any(o.get("kind")=="actual_cache_claim" and o.get("claimed") and o.get("chest")==row["reward_id"] for o in row.get("policy_observations",[])),"reward was never actually claimed before failure")
            observations={o.get("kind"):o for o in row.get("policy_observations",[])}
            require(observations.get("unopened_modal_rejected",{}).get("accepted") is False,"unopened UI callback not rejected")
            wrong=observations.get("actual_wrong_choice_rejected",{})
            require(wrong.get("queued") is True and wrong.get("rejected") is True and wrong.get("claimed") is False and wrong.get("modal_opened") is True,"invalid queued choice bypassed transaction rejection")
            duplicate=observations.get("actual_duplicate_claim_rejected",{})
            require(duplicate.get("accepted") is False and duplicate.get("rejected") is True and duplicate.get("balance")==row["wallet_after"],"duplicate claim accepted or double granted")
            require(row["after_actor_epoch"]==row["before_actor_epoch"]+1,"selective return actor epoch did not advance")
            energy=row["before_resources"]["shot_energy"]["current"]
            recovery_rate=row["before_resources"]["shot_energy"]["ground_energy_recovery"]/row["before_resources"]["physics_hz"]
            for frame in frames[row["failure_start_tick"]:row["return_tick"]]:
                require(frame["shot_energy"]-energy <= recovery_rate+.0001,"return injected shooting energy")
                energy=frame["shot_energy"]
            require(row["before_runtime"]["enemy_count"]==row["returned_runtime"]["enemy_count"] and row["before_runtime"]["claimed_ids"]==row["returned_runtime"]["claimed_ids"],"return reset committed world state")
            for claim in [o for o in row.get("policy_observations",[]) if o.get("kind")=="actual_cache_claim"]:
                experience.validate_cache_claim(row,claim)
                if reward_resource: require(claim["claim_output"]["resource"]==reward_resource,"requested native resource was not actually selected")
            continue
        require(row.get("scope")=="normally_scheduled_real_physics_fixture_not_formal_region","fixture scope cannot sign formal route")
        shots=[e for e in events if e.get("kind")=="shot"]
        committed=[e for e in events if e.get("kind")=="committed" and e.get("target")=="fixture_enemy"]
        receipts=row.get("receipts",[])
        inputs=[a for f in frames for a in f.get("requests",[])]
        require((bool(inputs) or any(f.get("axis")!=0 for f in frames)) and all(any(a.get("type")=="shoot_release" for a in frames[e["tick"]-1]["requests"]) for e in shots),"accepted shot without actual Router input")
        ids={s.get("event_id") for s in shots}
        require(len(ids)==len(shots) and all(e.get("event_id") in ids for e in committed),"damage not bound to actual accepted projectile")
        policy=row.get("shot_policy",{})
        free=policy.get("path")=="res://game/player/resources/demo_ui_01/time_energy_v2.tres"
        if free:
            require(policy.get("sha256")==formal.file_hash(ROOT/policy["path"][6:]) and policy.get("shooting_consumes_energy") is False and type(policy.get("max_air_shots")) is int and policy.get("max_air_shots")==read(ROOT/"config/player_tuning.json")["max_air_shots"] and policy.get("initial_energy")==read(ROOT/"config/player_tuning.json")["focus_stamina_capacity"],"wrong current free-policy provenance")
            require(not any(r["event_id"].startswith("shot/") for r in receipts),"free shot created paid energy receipt")
            require(all(f.get("focus_active") is False and f["energy"]==policy["initial_energy"] and type(f.get("charges")) is int and 0<=f["charges"]<=policy["max_air_shots"] for f in frames),"free fixture time energy or charge bounds drift")
        else:
            require(all(any(r["event_id"]==f"shot/{row['session']}/{s['shot_id']}" and r["status"]==0 and r["operation"]=="consume" and r["amount_applied"]==-r["requested_amount"] for r in receipts) for s in shots),"missing APPLIED actual shot consumption")
        if row["id"].startswith("kill_and_dead_"):
            require(row.get("enemy_terminal") is True and row.get("enemy_health")==0 and len(committed)==3 and committed[-1].get("lethal") is True,"metadata-only enemy kill")
            require(len(shots)>len(committed) and shots[-1]["tick"]>committed[-1]["tick"],"missing actual post-death shot")
            require(not any(r["event_id"]==f"hit/{row['session']}/{shots[-1]['shot_id']}" for r in receipts),"dead target gave refund")
            require(row.get("initial_engagement_ineligible") is True and frames[0].get("actor_processing") is True,"inactive fixture was engine-disabled")
        elif row["id"]=="solid_occlusion":
            require(len(shots)==1 and not committed and row["enemy_health"]>0,"real blocker failed to block damage")
        elif row["id"]=="cooldown_rejected":
            require(len(shots)==1 and any(e.get("kind")=="rejected" and e.get("reason")=="cooldown" for e in events),"real cooldown did not reject")
        elif row["id"]=="air_energy_rejected":
            if free:
                require(len(shots)==6 and all(frames[e["tick"]-1]["grounded"] for e in shots[:5]) and not frames[shots[-1]["tick"]-1]["grounded"] and frames[shots[-1]["tick"]-1]["charges"]==0 and not frames[-1]["grounded"] and frames[-1]["charges"]==0 and any(e.get("kind")=="rejected" and e.get("reason")=="empty" and e["tick"]>shots[-1]["tick"] for e in events),"current one-air-shot cause ledger missing")
            else:
                require(len(shots)==5 and frames[-1]["energy"]==0 and not frames[-1]["grounded"] and any(e.get("kind")=="rejected" and e.get("reason")=="energy" for e in events),"no actual zero-energy air rejection")
        else:
            states={e.get("state") for e in events if e.get("kind")=="enemy_state"}
            require({"telegraph","attack","recovery"}<=states and row.get("enemy_health",0)>0 and row.get("observed_recovery") is True,"bait was not actual living AI phase")
            if not row["id"].endswith(("sentry","fan_sentry")):require(row.get("body_moved") is True,"moving-away label lacks body motion")
    return True




def validate_reward_map_identity(row):
    index=row.get("map_index")
    require(type(index) is int and index in [1,2],"invalid requested reward map")
    expected_seed=row["root_seed"]+("/plains/map_2" if index==2 else "")
    expected={"map_index":index,"manifest_seed":expected_seed,"manifest_difficulty":"intro" if index==1 else "advanced","region":"plains"}
    require(row.get("actual_stage_identity")==expected,"actual reward stage identity differs from request")
    manifest=row["manifest"]
    require(manifest.get("seed")==expected_seed and manifest.get("difficulty")==expected["manifest_difficulty"] and manifest.get("region")=="plains","actual reward Manifest identity differs from request")
    return True


def validate_reward_entry(data, sources):
    """Live reward content proof, distinct from terrain-only fixture admission."""
    require(data.get("artifact_kind")=="actual_encounter_policy_proof" and data.get("failures")==0 and data.get("assertions",0)>=5,"failed/empty reward entry process")
    require(len(data.get("cases",[]))==1,"ambiguous reward input run")
    row=data["cases"][0];state=row.get("state",{});frames=row.get("frames",[]);events=row.get("events",[])
    validate_reward_map_identity(row)
    require(row.get("id")=="formal_reward_entry" and row.get("scope")=="actual_live_CampaignFixture_normal_start_reward_entry_observer" and not row.get("restored_unsafe") and not row.get("restored_unsafe_return"),"wrong/physically broken reward consumer")
    require(row.get("driver_sha256")==sources.get("tests/level_formal_trace.gd") and row.get("observer_sha256")==sources.get("tests/plains_encounter_policy_runner.gd"),"wrong actual driver/observer bytes")
    require(all(state.get(k) is True for k in ["done","tutorial","approach","trial","camp"]) and not row.get("diagnostics"),"incomplete normal-spawn reward itinerary")
    require(frames and [f.get("tick") for f in frames]==list(range(1,len(frames)+1)),"missing actual physics observation")
    require(Counter(json.dumps(e,sort_keys=True) for e in events)==Counter(json.dumps(e,sort_keys=True) for f in frames for e in f["accepted_events"]),"actual journal/frame multiplicity differs")
    require(all(e["tick"]==f["tick"] for f in frames for e in f["accepted_events"]),"wrong event frame")
    require(not any(e["kind"] in ["segment_returned","died","run_ended"] for e in events),"failure/teleport cannot sign reward completion")
    cap=row["initial_capability"];energy=cap["shot_energy"];previous=energy["current"]
    free=energy.get("definition_path")=="res://game/player/resources/demo_ui_01/time_energy_v2.tres"
    if free:
        require(energy.get("shooting_consumes_energy") is False and energy.get("definition_sha256")==formal.file_hash(ROOT/energy["definition_path"][6:]) and cap["config_hashes"]["player_tuning"]==formal.file_hash(ROOT/"config/player_tuning.json"),"reward current policy/config identity missing")
    expected_air=read(ROOT/"config/player_tuning.json")["max_air_shots"] if free else 2
    require(cap["effective_max_jumps"]==1 and cap["air_shot_flight_cap"]==expected_air and cap["equipped_weapon"]["id"]=="pulse_gun" and cap["equipped_weapon"]["tier"]==1 and set(cap["granted_actions"])=={"jump","shot_recoil"},"unsupported reward ability")
    require(0<state["entry_tick"]<=state["trial_start_tick"]<state["trial_end_tick"]<=len(frames),"invalid entry/trial interval")
    require(math.dist(frames[state["entry_tick"]-1]["position"],state["entry_position"])<.01 and frames[state["entry_tick"]-1]["grounded"],"entry not an actual grounded frame")
    require(abs(frames[state["entry_tick"]-1]["shot_energy"]-state["entry_energy"])<.001,"entry energy invented")
    require(state.get("entry_guard")==frames[state["entry_tick"]-1].get("reward_guard",[]),"entry guard snapshot is not the actual observed body frame")
    # The observer's label is not the authority for whether a guard exists.
    # Bind it to the unique authored challenge entrance and its real area first;
    # otherwise an invented absent ID plus erased observations skips all proof.
    require(row["tier"] in ["high","region_top"],"unknown reward challenge tier")
    goal="deep_"+row["tier"]
    entrances=[e for e in row["manifest"]["connections"] if e["b"]==goal and e["kind"]=="challenge"]
    require(len(entrances)==1,"reward challenge needs one actual entrance")
    entry_areas=[a for a in row["manifest"]["areas"] if a["id"]==entrances[0]["a"]]
    require(len(entry_areas)==1,"reward entrance lacks unique actual area")
    entry_area=entry_areas[0];expected_guard_id="plains/enemy/"+entry_area["id"]
    require(row["guard_id"]==expected_guard_id,"reported guard identity differs from actual challenge entrance")
    require(math.dist(state["entry_position"],entry_area["position"])<3,"grounded entry frame is not on the actual challenge bank")
    declared_guards=[e for e in row["manifest"]["enemies"] if e["id"]==expected_guard_id]
    require(len(declared_guards)<=1 and all(e.get("area")==entry_area["id"] for e in declared_guards),"ambiguous or misplaced Manifest entrance guard")
    declared_guard=bool(declared_guards) # Some legal high/top entrances have no generic guard.
    for frame in frames:
        require(len(frame.get("reward_guard",[]))==(1 if declared_guard else 0),"declared live guard missing from actual body observation")
        require(frame["health"]==frames[0]["health"] and frame["recovery_count"]==0,"forced contact/damage or recovery")
        tick=frame["tick"];receipts=[r for r in row["resource_receipts"] if r["tick"]==tick]
        focus_transactions=[tx for tx in state.get("focus_setup",{}).get("transactions",[]) if tx["tick"]==tick] if free else []
        unexplained=frame["shot_energy"]-previous-sum(r["amount_applied"] for r in receipts)-sum(tx["amount"] for tx in focus_transactions)
        require(-.001<=unexplained<=energy["ground_energy_recovery"]/cap["physics_hz"]+.001,"resource injection or missing spend")
        if unexplained>.001:require(frame["grounded"] or (tick>1 and frames[tick-2]["grounded"]),"airborne regeneration invented")
        previous=frame["shot_energy"]
        require(all(sum(e["kind"]==kind for e in frame["accepted_events"])<=1 for kind in ["jump_accepted","landed"]),"duplicated accepted movement signal")
        for event in frame["accepted_events"]:
            if event["kind"] in ["shot_accepted","jump_accepted"]:
                action="shoot_release" if event["kind"]=="shot_accepted" else "jump"
                require(any(q["type"]==action for q in frame["input_requests"]),"accepted action without same-tick Router request")
            if event["kind"]=="landed":require(frame["grounded"] and frame["collisions"],"landing without actual floor collision")
        require(len(frame.get("reward_guard",[]))<=1,"duplicate guard observation")
        for guard in frame.get("reward_guard",[]):require(guard["id"]==row["guard_id"] and (guard["actor_physics_processing"] is True or guard["terminal"] is True),"wrong/disabled live enemy")
    for a,b in zip(frames,frames[1:]):
        if not a["grounded"] and b["grounded"]:
            require(any(e["kind"]=="landed" for e in b["accepted_events"]),"physical landing lacks accepted landing signal")
        if a["grounded"] and not b["grounded"] and b["velocity"][1]<-20:
            require(any(e["kind"] in ["jump_accepted","shot_accepted"] for e in b["accepted_events"]),"upward departure lacks accepted action")
    for observation in row["policy_observations"]:
        if observation.get("kind")!="actual_enemy_transition" or observation.get("enemy")!=row["guard_id"]:continue
        tick=observation["tick"]
        if tick==len(frames)+1:continue # Post-stop cleanup is never used as encounter proof.
        require(1<=tick<=len(frames) and len(frames[tick-1].get("reward_guard",[]))==1,"enemy transition lacks actual frame")
        guard=frames[tick-1]["reward_guard"][0]
        require(guard["attack_state"]==observation["state"] and guard["transition_serial"]==observation["transition_serial"] and math.dist(guard["position"],observation["position"])<.001,"enemy preview state/position/serial not causal to actual frame")
    # Reuse the existing projectile/resource/modal/ledger semantic checks. The
    # basis is the enclosing real subprocess inventory, not a new capture type.
    projected=dict(row,tick_count=len(frames),capture_contract_version=3,encounter_policy=row["policy"],policy_basis={"schema_version":1,"encounter_policy":row["policy"],"driver_sources":{"res://"+p:sources[p] for p in formal.driver_source_paths()},"core_invariants":{"res://"+p:sources[p] for p in formal.core_source_paths()}})
    experience.validate_policy_capture(projected)
    modules=row.get("modules",[])
    require([m["id"] for m in modules]==[goal+suffix for suffix in ["_entry","_ferry","_recoil","_landing"]],"missing two-module challenge")
    for module in modules:
        nodes=[n for n in row["manifest"]["nodes"] if n["id"]==module["id"]]
        require(len(nodes)==1 and nodes[0]["module_id"]==module["module_id"],"ports refer to a different authored module")
        if "geometry" not in nodes[0]:
            resource=ROOT/"resources/generation/modules"/(module["module_id"]+".tres")
            require(resource.is_file() and formal.file_hash(resource)==sources.get(str(resource.relative_to(ROOT))),"unbound actual module Definition")
            blocks=re.split(r"(?=\[sub_resource)",resource.read_text())
            for port in ["entry","exit"]:
                block=next((b for b in blocks if re.search(r'port_id\s*=\s*&"'+port+'"',b)),"")
                point=re.search(r'position\s*=\s*Vector2\(([^,]+),([^\)]+)\)',block)
                require(point is not None,"Definition port missing")
                expected=[nodes[0]["offset"][i]+float(point.group(i+1)) for i in range(2)]
                require(math.dist(expected,module[port])<.001,"reported port differs from real Definition/Manifest")
    cursor=state["trial_start_tick"]
    entry=state["entry_position"]
    for x,y in [(90,-100),(-90,-200),(-230,-300)]:
        matches=[f for f in frames[cursor:state["trial_end_tick"]] if f["grounded"] and math.dist(f["position"],[entry[0]+x,entry[1]+y])<3]
        require(matches,"missing actual ordered ascent receiver")
        landing=matches[0]["tick"]
        require(any(e["kind"]=="jump_accepted" and cursor<e["tick"]<=landing for e in events),"ascent receiver lacks real jump")
        cursor=landing
    # Relative whole-body sweep: protected anchors suppress attacks, never
    # contact damage. A patrol body may not sweep the first ascent receivers.
    def intersects(a,b,half):
        low,high=0.0,1.0
        for i in range(2):
            delta=b[i]-a[i]
            if abs(delta)<1e-9:
                if abs(a[i])>half[i]:return False
            else:
                t0,t1=sorted(((-half[i]-a[i])/delta,(half[i]-a[i])/delta))
                low=max(low,t0);high=min(high,t1)
                if low>high:return False
        return True
    for a,b in zip(frames[state["entry_tick"]-1:cursor-1],frames[state["entry_tick"]:cursor]):
        if not a.get("reward_guard") or not b.get("reward_guard"):continue
        ga,gb=a["reward_guard"][0],b["reward_guard"][0]
        if ga["terminal"] or gb["terminal"]:continue
        half=[12+ga["body_size"][0]/2,18+ga["body_size"][1]/2]
        require(not intersects([a["position"][i]-ga["position"][i] for i in range(2)],[b["position"][i]-gb["position"][i] for i in range(2)],half),"live guard body sweeps reserved first ascent")
    for module in modules[1:3]:
        module_start=cursor
        for port in ["entry","exit"]:
            matches=[f for f in frames[cursor:state["trial_end_tick"]] if f["grounded"] and math.dist(f["position"],module[port])<3]
            require(matches,"full high chain misses supported module "+port)
            cursor=matches[0]["tick"]
            if port=="entry":module_start=cursor
        accepted=[e for e in events if module_start<e["tick"]<=cursor]
        if "recoil" in module["module_id"] or "remote_sequence" in module["module_id"]:
            require(any(e["kind"]=="jump_accepted" for e in accepted) and any(e["kind"]=="shot_accepted" for e in accepted),"module endpoints lack actual recoil/observation actions")
        elif "windchime" in module["module_id"]:
            require(any(e["kind"]=="shot_accepted" for e in accepted),"bell module endpoints lack actual switch shot")
        elif "ferry" in module["module_id"]:
            require(any(e["kind"]=="jump_accepted" for e in accepted),"ferry module endpoints lack actual boarding")
    claims=[o for o in row["policy_observations"] if o["kind"]=="actual_cache_claim" and o["chest"]==row["chest_id"]]
    require(len(claims)==1 and cursor<claims[0]["tick"]<state["trial_end_tick"] and row.get("claimed") is True,"missing actual high claim after both modules")
    require(any(e["kind"]=="landed" and claims[0]["tick"]<e["tick"]<=state["trial_end_tick"] for e in events),"no actual different-bank return landing")
    exits=[e for e in row["manifest"]["connections"] if e["a"]==goal and e["kind"]=="drop"]
    require(len(exits)==len(entrances)==1 and exits[0]["b"]==state["return_area"]!=entrances[0]["a"],"return duplicates entrance")
    area=next(a for a in row["manifest"]["areas"] if a["id"]==state["return_area"])
    require(any(f["grounded"] and math.dist(f["position"],area["position"])<3 for f in frames[claims[0]["tick"]:state["trial_end_tick"]]),"declared return bank not physically reached")
    camp=next(a for a in row["manifest"]["areas"] if a["id"]==row["manifest"]["merchant_id"])
    require(frames[-1]["grounded"] and math.dist(frames[-1]["position"],camp["position"])<3,"actual itinerary never reaches camp")
    guards=[f["reward_guard"][0] for f in frames[state["entry_tick"]-1:] if f.get("reward_guard")]
    if row["policy"]=="bait_then_bypass_v1":
        require(guards and len(guards)==len(frames)-state["entry_tick"]+1 and all(g["health"]>0 and not g["terminal"] for g in guards),"high nonkill route killed/disabled/lost guard")
        require(any(o.get("enemy")==row["guard_id"] and o.get("kind")=="actual_enemy_transition" and o.get("state")=="telegraph" and state["entry_tick"]<=o["tick"]<cursor for o in row["policy_observations"]),"high bypass lacks actual living threat observation")
        require(not any(e.get("target")==row["guard_id"] and e["kind"]=="damage_committed" for e in events),"nonkill high entrance actually shot guard")
    elif guards:
        dead=[e for e in events if e["kind"]=="damage_committed" and e.get("target")==row["guard_id"] and e.get("lethal")]
        require(len(dead)==1 and 1<=dead[0]["tick"]<cursor,"guard not actually killed from the prepare bank")
        require(not any(e["kind"]=="damage_committed" and e.get("target")==row["guard_id"] and e["tick"]>dead[0]["tick"] for e in events),"dead target required for more refunds")
    if row["natural_low"]:
        low=state.get("low_tick",0);require(state["entry_tick"]<low<=state["trial_start_tick"] and frames[low-1]["shot_energy"]==state["low_energy"]<energy["shot_energy_cost"],"low-resource boundary fabricated")
        if state.get("focus_setup"):
            setup=state["focus_setup"];path="res://game/player/resources/demo_ui_01/time_energy_v2.tres"
            require(setup.get("policy_path")==path and setup.get("policy_sha256")==formal.file_hash(ROOT/path[6:]) and setup.get("input")=="actual_router_jumpheld_and_airborne_aim" and setup.get("released") is True,"low-focus actual policy/input/release evidence missing")
            balance=setup["initial"];consumes=[]
            for tx in setup.get("transactions",[]):
                require(state["entry_tick"]<tx["tick"]<=low and tx["operation"] in ("consume","grant") and math.isfinite(tx["amount"]) and abs(balance+tx["amount"]-tx["current"])<.001,"low-focus transaction sequence invented")
                if tx["amount"]<0:
                    tuning=read(ROOT/"config/player_tuning.json")
                    expected=min(balance,tuning["focus_stamina_drain"]*min(tx["real_delta"],max(0,tuning["focus_max_air_duration"]-tx["focus_air_before"])))
                    require(abs(-tx["amount"]-expected)<.001 and frames[tx["tick"]-1]["grounded"] is False,"low-focus drain differs from actual duration/config/frame")
                    require(tx["operation"]=="consume" and not tx["grounded"] and tx["aiming"] and tx["focus_active"],"low time energy spent outside actual airborne focus")
                    consumes.append(tx)
                else:require(tx["grounded"] and tx["operation"]=="grant","low-focus positive credit is not ground recovery")
                balance=tx["current"]
            require(consumes and abs(balance-state["low_energy"])<.001,"low-focus energy does not reconcile to real receipts")
        else:
            require(any(e["kind"]=="shot_accepted" and state["entry_tick"]<e["tick"]<=low for e in events),"no naturally accepted low-resource input")
    return True

def native_run(folder, recovery=False, reward_resource=""):
    output=folder/(("recovery_"+reward_resource+".json") if reward_resource else ("recovery.json" if recovery else "native.json")); log=output.with_suffix(".log")
    command=["bash","tools/godot.sh","--headless","--fixed-fps","60","--path",".","--script","tests/plains_encounter_policy_runner.gd","--","--output=res://"+output.relative_to(ROOT).as_posix()]
    if recovery:command.append("--recovery-only")
    if reward_resource:command.append("--reward-resource="+reward_resource)
    result=harness.run_check({"argv":command,"timeout_seconds":180,"success_pattern":MARKER},log,ROOT)
    require(result["status"]=="passed" and not re.search(ERRORS,log.read_text()),"actual native/recovery process failed")
    data=read(output);validate_native(data,recovery,reward_resource)
    return {"output":str(output.relative_to(ROOT)),"sha256":formal.file_hash(output),"log":str(log.relative_to(ROOT)),"log_sha256":formal.file_hash(log),"command":command,"process":result},data



def validate_early_entry_contact_conflict(row):
    """Recognize the same unsafe entrance when accepted hurt interrupts ascent early.

    This is only an entry counterexample, with an actual declared guard contact,
    matching accepted events and an exact adjacent-frame HP reduction.
    """
    state = row.get("state", {})
    require(row.get("restored_unsafe") is True and not row.get("restored_unsafe_return", False)
            and row.get("claimed") is False and state.get("approach") is True
            and state.get("trial") is False, "not an unclaimed failed unsafe entry")
    manifest = row.get("manifest", {})
    edges = [e for e in manifest.get("connections", [])
             if e.get("kind") == "challenge" and e.get("b") == "deep_" + str(row.get("tier", ""))]
    require(len(edges) == 1, "ambiguous unsafe entry route")
    area = edges[0].get("a")
    guard_id = "plains/enemy/" + str(area)
    guards = [e for e in manifest.get("enemies", []) if e.get("id") == guard_id]
    require(len(guards) == 1 and guards[0].get("area") == area
            and row.get("guard_id") == guard_id, "unsafe entry guard is absent/wrong/ambiguous")
    entry_guards = state.get("entry_guard", [])
    require(len(entry_guards) == 1 and entry_guards[0].get("id") == guard_id
            and entry_guards[0].get("health", 0) > 0 and entry_guards[0].get("terminal") is False,
            "unsafe entry lacks its observed live guard")
    frames = row.get("frames", [])
    require(frames and all(type(f.get("tick")) is int and f["tick"] > 0 for f in frames),
            "unsafe entry capture has invalid frame ticks")
    by_tick = {f.get("tick"): f for f in frames}
    require(len(frames) == len(by_tick), "ambiguous unsafe entry frame ticks")
    entry, start, end = (state.get(key) for key in ("entry_tick", "trial_start_tick", "trial_end_tick"))
    require(all(type(tick) is int and tick > 0 and tick in by_tick for tick in (entry, start, end))
            and min(by_tick) <= entry <= start < end <= max(by_tick), "invalid unsafe entry interval")
    entry_frame = by_tick[entry]
    require(state.get("entry_position") == entry_frame.get("position")
            and isinstance(state.get("entry_position"), list) and len(state["entry_position"]) == 2
            and state["entry_guard"] == entry_frame.get("reward_guard"),
            "unsafe entry position/guard does not match its actual entry frame")
    entry_areas = [a for a in manifest.get("areas", []) if a.get("id") == area]
    require(len(entry_areas) == 1 and entry_frame.get("grounded") is True
            and isinstance(entry_areas[0].get("position"), list) and len(entry_areas[0]["position"]) == 2
            and all(type(value) in (int, float) and math.isfinite(value)
                    for value in state["entry_position"] + entry_areas[0]["position"])
            and math.dist(state["entry_position"], entry_areas[0]["position"]) < 3,
            "unsafe entry is not the actual grounded authored entrance bank")
    contacts = [e for e in row.get("events", []) if e.get("kind") == "damage_committed"
                and e.get("source") == guard_id + "_contact" and e.get("target") == "player"
                and type(e.get("tick")) is int and start <= e["tick"] <= end]
    require(len(contacts) == 1, "missing/ambiguous declared guard contact")
    event = contacts[0]
    tick = event["tick"]
    require(tick - 1 in by_tick and tick in by_tick, "contact lacks adjacent actual frames")
    before, after = by_tick[tick - 1], by_tick[tick]
    accepted = after.get("accepted_events", [])
    require(accepted.count(event) == 1, "contact lacks its exact accepted frame event")
    amount, health = event.get("amount", 0), event.get("health_after", -1)
    require(type(amount) in (int, float) and math.isfinite(amount) and amount > 0
            and type(health) in (int, float) and math.isfinite(health) and health > 0
            and event.get("lethal") is False and after.get("health") == health
            and before.get("health", -1) - health == amount,
            "contact HP does not equal the actual adjacent-frame loss")
    health_events = [e for e in accepted if e.get("kind") == "player_health"
                     and e.get("tick") == tick and e.get("operation") == "damage"
                     and e.get("status") == 0 and e.get("amount") == -amount
                     and e.get("current") == health]
    require(len(health_events) == 1, "contact lacks its accepted health application")
    require(row.get("events", []).count(health_events[0]) == 1,
            "contact health application lacks its exact global accepted event")
    observed = after.get("reward_guard", [])
    require(len(observed) == 1 and observed[0].get("id") == guard_id
            and observed[0].get("health", 0) > 0 and observed[0].get("terminal") is False,
            "contact frame does not observe the declared live guard")
    jumps = [e for e in row.get("events", []) if e.get("kind") == "jump_accepted"
             and start <= e.get("tick", -1) <= tick]
    require(any(e in by_tick.get(e["tick"], {}).get("accepted_events", []) for e in jumps),
            "contact did not interrupt an accepted entry ascent")
    return True


def reward_entry_run(folder, name, args, broken=False):
    folder=folder.resolve();folder.mkdir(parents=True,exist_ok=True)
    output=folder/(name+".json");log=output.with_suffix(".log")
    command=["bash","tools/godot.sh","--headless","--fixed-fps","60","--path",".","--script","tests/plains_encounter_policy_runner.gd","--","--reward-entry","--output=res://"+output.relative_to(ROOT).as_posix()]+args
    before=formal.source_files();started=time.time()
    with log.open("w") as stream:process=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
    require(before==formal.source_files() and not re.search(ERRORS,log.read_text()),"reward process source drift or native diagnostic")
    data=read(output)
    cleanup = data.get("post_capture_cleanup", [])
    require(isinstance(cleanup,list) and len(cleanup)==1,"missing reward execution cleanup receipt")
    cleanup=cleanup[0]
    require(cleanup.get("ok") is True and cleanup.get("execution_done") is True and
            cleanup.get("requested") is True and cleanup.get("before") and
            cleanup["before"] == cleanup.get("after") and
            cleanup.get("audio_released") is True and cleanup.get("driver_released") is True and
            cleanup.get("observers_disconnected",0)>0 and
            re.fullmatch(r"[0-9a-f]{64}",str(cleanup.get("sealed_case_sha256",""))) and
            cleanup["sealed_case_sha256"] == cleanup.get("case_sha256_after_unwind"),
            "reward execution cleanup failed or changed sealed failure evidence")
    facts=cleanup["before"]
    require(facts.get("controller_valid") is True and facts.get("router_axis")==0 and
            facts.get("queued_actions")==0, "reward cancellation retained movement or queued actions")
    if broken:
        require(process.returncode==1 and data.get("failures",0)>0,"physical counterexample unexpectedly passed")
        row=data["cases"][0]
        require(row["state"]["approach"] and not row["state"]["trial"] and min(f["health"] for f in row["frames"])<row["frames"][0]["health"],"counterexample lacks actual failed contact")
        if broken=="return":require(row.get("restored_unsafe_return") and row["claimed"],"return counterexample never completes actual high claim first")
        else:require(row["restored_unsafe"] and not row["claimed"],"entry counterexample not at first ascent")
        intended = any("unsafe recoil bank" in d["message"] or "no safe non-kill" in d["message"] or (broken=="return" and "enemy bank unsafe/no damage progress" in d["message"]) for d in row["diagnostics"])
        if not intended and broken is True:
            try: validate_early_entry_contact_conflict(row)
            except ValueError: pass
            else: intended = True
        require(intended,"negative is not the intended physical conflict")
        try:validate_reward_entry(data,before)
        except ValueError:pass
        else:raise ValueError("bad physical encounter accepted")
    else:
        require(process.returncode==0 and re.search(MARKER,log.read_text(),re.M),"actual reward entry process failed")
        validate_reward_entry(data,before)
    result={"name":name,"expected_physical_failure":broken,"output":str(output.relative_to(ROOT)),"sha256":formal.file_hash(output),"log":str(log.relative_to(ROOT)),"log_sha256":formal.file_hash(log),"command":command,"exit_code":process.returncode,"started":started,"ended":time.time(),"source_before":before,"source_after":formal.source_files()}
    write(output.with_suffix(".receipt.json"),result)
    return result,data



def validate_dead_low_guard(row):
    """Bind the dead entrance actor to this actual route and accepted projectile."""
    manifest=row["manifest"]
    challenge=[edge for edge in manifest["connections"] if edge["kind"]=="challenge" and edge["b"]=="deep_region_top"]
    require(len(challenge)==1,"ambiguous dead/low reward entrance")
    area=challenge[0]["a"]
    guards=[enemy for enemy in manifest["enemies"] if enemy.get("area")==area and enemy.get("id")=="plains/enemy/"+area]
    require(len(guards)==1 and row.get("guard_id")==guards[0]["id"],"dead/low entrance actor identity is absent/wrong/ambiguous")
    guard_id=guards[0]["id"];state=row["state"];entry=state["entry_tick"]
    require(len(state.get("entry_guard",[]))==1 and state["entry_guard"][0].get("id")==guard_id and
            state["entry_guard"][0].get("terminal") is True and state["entry_guard"][0].get("health")==0,
            "dead/low matrix did not actually enter with a dead guard")
    accepted={event["event_id"]:event for event in row["events"] if event.get("kind")=="shot_accepted"}
    lethal=[event for event in row["events"] if event.get("kind")=="damage_committed" and event.get("target")==guard_id and event.get("lethal") is True]
    require(len(lethal)==1 and lethal[0].get("health_after")==0 and lethal[0]["tick"]<=entry and
            lethal[0].get("event_id") in accepted and accepted[lethal[0]["event_id"]]["tick"]<=lethal[0]["tick"] and
            str(lethal[0].get("source","")).startswith("player_projectile:"),
            "dead/low entrance lacks one accepted real projectile lethal before entry")
    return True


def reward_entry_checks(folder):
    # Bounded representative content matrix, not all player behaviour coverage.
    specifications=[("reward_kill0",[]), ("reward_kill100",["--entry-phase=100"]),
      ("reward_bypass0",["--entry-policy=bait_then_bypass_v1"]),
      ("reward_bypass100",["--entry-policy=bait_then_bypass_v1","--entry-phase=100"]),
      ("reward_low",["--entry-low"]),("reward_top1",["--entry-tier=region_top"]),
      ("reward_high2",["--entry-map=2"]),("reward_top2",["--entry-map=2","--entry-tier=region_top"]),
      ("reward_dead_low2",["--entry-map=2","--entry-tier=region_top","--entry-low"]),
      ("reward_worst_return",["--entry-seed=two-map-corpus/2"]),
      ("reward_worst_return_bypass",["--entry-seed=two-map-corpus/2","--entry-policy=bait_then_bypass_v1"])]
    runs=[];honest={}
    with ThreadPoolExecutor(max_workers=2) as workers:
        results=list(workers.map(lambda spec:reward_entry_run(folder,*spec),specifications))
    for (name,_),(proof,data) in zip(specifications,results):
        runs.append(proof);honest[name]=data
    dead_low=honest["reward_dead_low2"]["cases"][0]
    validate_dead_low_guard(dead_low)
    for name,args in [("reward_original_conflict_kill",["--restore-unsafe-entry"]),("reward_original_conflict_bypass",["--restore-unsafe-entry","--entry-policy=bait_then_bypass_v1"])]:
        proof,_=reward_entry_run(folder,name,args,True);runs.append(proof)
    def remove_events(row,kind):
        row["events"]=[e for e in row["events"] if e["kind"]!=kind]
        for frame in row["frames"]:frame["accepted_events"]=[e for e in frame["accepted_events"] if e["kind"]!=kind]
    def duplicate(row,kind):
        event=next(e for e in row["events"] if e["kind"]==kind)
        row["events"].append(copy.deepcopy(event));row["frames"][event["tick"]-1]["accepted_events"].append(copy.deepcopy(event))
    def erase_guard(row):
        row["state"]["entry_guard"]=[]
        for frame in row["frames"]:frame["reward_guard"]=[]
    def transition(row):return next(o for o in row["policy_observations"] if o.get("enemy")==row["guard_id"] and o.get("kind")=="actual_enemy_transition" and o.get("state")=="telegraph")
    proof,_=reward_entry_run(folder,"reward_original_return_conflict",["--entry-seed=two-map-corpus/2","--restore-unsafe-return"],"return");runs.append(proof)
    mutations={
      "coherent_erase_declared_guard":erase_guard,
      "duplicate_jump":lambda r:duplicate(r,"jump_accepted"),
      "duplicate_landing":lambda r:duplicate(r,"landed"),
      "wrong_preview_time":lambda r:transition(r).update(tick=1),
      "wrong_preview_position":lambda r:transition(r).update(position=[0,0]),
      "wrong_preview_serial":lambda r:transition(r).update(transition_serial=999),
      "fake_entry_guard_state":lambda r:r["state"]["entry_guard"][0].update(health=1),
      "coherent_missing_jump":lambda r:remove_events(r,"jump_accepted"),
      "coherent_missing_landing":lambda r:remove_events(r,"landed"),
      "fake_module_ports":lambda r:r["modules"][2].update(entry=r["modules"][1]["entry"],exit=r["modules"][1]["exit"]),
      "missing_ascent_jump":lambda r:r.update(events=[e for e in r["events"] if not(e["kind"]=="jump_accepted" and r["state"]["trial_start_tick"]<e["tick"]<r["state"]["trial_start_tick"]+200)]),
      "missing_landing_events":lambda r:r.update(events=[e for e in r["events"] if e["kind"]!="landed"]),
      "missing_reward_transaction":lambda r:next(o for o in r["policy_observations"] if o["kind"]=="actual_cache_claim").update(transaction={}),
      "wrong_reward_frame":lambda r:next(o for o in r["policy_observations"] if o["kind"]=="actual_cache_claim").update(tick=1),
      "empty_return":lambda r:r["state"].update(return_area="area_0_0"),
      "missing_second_module":lambda r:r["modules"].pop(2),
      "missing_guard_observations":lambda r:[f.update(reward_guard=[]) for f in r["frames"]],
      "guard_dead_in_bypass":lambda r:r["frames"][r["state"]["entry_tick"]]["reward_guard"][0].update(health=0,terminal=True),
      "unsupported_ability":lambda r:r["initial_capability"].update(effective_max_jumps=2),
      "invented_energy":lambda r:r["frames"][r["state"]["trial_start_tick"]].update(shot_energy=100),
      "missing_shot_consumption":lambda r:r.update(resource_receipts=[q for q in r["resource_receipts"] if q["operation"]!="consume"]),
      "missing_actual_modal_input":lambda r:r.update(events=[e for e in r["events"] if e["kind"]!="reward_modal_submission"])}
    rejected=[];sample=honest["reward_bypass0"];sources=formal.source_files()
    current_free=sample["cases"][0]["initial_capability"]["shot_energy"].get("shooting_consumes_energy") is False
    if current_free:
        def forged_paid_receipt(row):
            shot=next(e for e in row["events"] if e["kind"]=="shot_accepted")
            policy=row["initial_capability"]["shot_energy"];cost=policy["shot_energy_cost"]
            row["resource_receipts"].append({"event_id":f"shot/{shot['session_id']}/{shot['packet_id']}","operation":"consume","status":0,"amount_applied":-cost,"requested_amount":cost,"current":shot["energy_after"],"capacity":policy["capacity"],"tick":shot["tick"],"session_id":shot["session_id"],"epoch":shot["resource_epoch"]})
        mutations["missing_shot_consumption"]=forged_paid_receipt # Current violation: paid receipt where there must be none.
    for name,mutation in mutations.items():
        # Setting100 is a real unearned gain on this actual15-energy route;
        # on the free full-energy route that old mutation would be a no-op.
        positive=honest["reward_low"] if current_free and name=="invented_energy" else sample
        bad=copy.deepcopy(positive);mutation(bad["cases"][0])
        require(bad!=positive,"Causal counterexample did not actually change current evidence: "+name)
        try:validate_reward_entry(bad,sources)
        except (ValueError,KeyError,TypeError):rejected.append(name)
        else:raise ValueError("reward causal counterexample accepted: "+name)
    rejected.extend(reward_entry_identity_checks(honest["reward_kill0"],sources))
    write(folder/"reward_validator_refusals.json",rejected)
    return {"runs":runs,"validator_refusals":rejected,"scope":"live normal-spawn high/top input matrix, same enemy budget, real modal claim and different camp return; no device/fun/art acceptance"}

def reward_entry_identity_checks(capture,sources):
    """Independent REWARD-R1 escape and adjacent entrance-identity corruptions.

    This uses a real kill capture: an erased guard must not bypass conditional
    kill proof. Legal absent-guard positives remain in the native input matrix.
    These mutations test evidence refusal, not game physics.
    """
    validate_reward_entry(capture,sources)
    def entrance(row):
        return next(e for e in row["manifest"]["connections"] if e["kind"]=="challenge" and e["b"]=="deep_"+row["tier"])
    def erase_and_rename(row,identity):
        actual=row["guard_id"]
        row["state"]["entry_guard"]=[]
        for frame in row["frames"]:frame["reward_guard"]=[]
        row["policy_observations"]=[o for o in row["policy_observations"] if not(o.get("kind")=="actual_enemy_transition" and o.get("enemy")==actual)]
        row["guard_id"]=identity
    def rename_to_declared_other(row):
        other=next(e["id"] for e in row["manifest"]["enemies"] if e["id"]!=row["guard_id"])
        erase_and_rename(row,other)
    def wrong_bank(row):
        edge=entrance(row)
        edge["a"]=next(a["id"] for a in row["manifest"]["areas"] if a["id"]!=edge["a"])
        erase_and_rename(row,"plains/enemy/"+edge["a"])
    def move_grounded_entry(row):
        # Keep the state/frame agreement, but put both on another actual bank.
        edge=entrance(row)
        position=next(a["position"] for a in row["manifest"]["areas"] if a["id"]!=edge["a"])
        row["state"]["entry_position"]=copy.deepcopy(position)
        row["frames"][row["state"]["entry_tick"]-1]["position"]=copy.deepcopy(position)
    mutations={
      "unknown_guard_id_coherent_erasure":lambda r:erase_and_rename(r,"plains/enemy/not_the_declared_high_entrance"),
      "other_declared_guard_id_coherent_erasure":rename_to_declared_other,
      "wrong_entrance_bank_coherent_identity":wrong_bank,
      "duplicate_challenge_entrance":lambda r:r["manifest"]["connections"].append(copy.deepcopy(entrance(r))),
      "missing_challenge_entrance":lambda r:r["manifest"]["connections"].remove(entrance(r)),
      "missing_entrance_area":lambda r:r["manifest"].update(areas=[a for a in r["manifest"]["areas"] if a["id"]!=entrance(r)["a"]]),
      "duplicate_entrance_guard_declaration":lambda r:r["manifest"]["enemies"].append(copy.deepcopy(next(e for e in r["manifest"]["enemies"] if e["id"]==r["guard_id"]))),
      "wrong_entrance_guard_area":lambda r:next(e for e in r["manifest"]["enemies"] if e["id"]==r["guard_id"]).update(area="not_the_entrance"),
      "coherent_wrong_grounded_entry_bank":move_grounded_entry,
      "unknown_reward_tier":lambda r:r.update(tier="not_an_authored_reward")}
    rejected=[]
    for name,mutation in mutations.items():
        bad=copy.deepcopy(capture);mutation(bad["cases"][0])
        try:validate_reward_entry(bad,sources)
        except (ValueError,KeyError,TypeError):rejected.append(name)
        else:raise ValueError("reward entrance identity counterexample accepted: "+name)
    return rejected


def policy_tamper_checks(capture):
    # Same actual capture, deliberate mutations. These only test the verifier.
    mutations={"empty_frames":lambda d:d.update(frames=[]),
               "missing_shot_receipt":lambda d:d.update(resource_receipts=[r for r in d["resource_receipts"] if r["operation"]!="consume"]),
               "missing_shot_event":lambda d:d.update(events=[e for e in d["events"] if e["kind"]!="shot_accepted"]),
               "forged_damage_event":lambda d:next(e for e in d["events"] if e["kind"]=="damage_committed" and str(e.get("source","")).startswith("player_projectile:")).update(event_id="fake"),
               "missing_driver_dependency":lambda d:d["policy_basis"]["driver_sources"].pop(next(iter(d["policy_basis"]["driver_sources"]))),
               "missing_core_dependency":lambda d:d["policy_basis"]["core_invariants"].pop("res://game/player/player_motor.gd"),
               "unknown_mode":lambda d:d.update(encounter_policy="all_fun_pass")}
    if capture["initial_capability"]["shot_energy"].get("shooting_consumes_energy") is False:
        def forged_paid_receipt(data):
            shot=next(e for e in data["events"] if e["kind"]=="shot_accepted")
            policy=data["initial_capability"]["shot_energy"];cost=policy["shot_energy_cost"]
            data["resource_receipts"].append({"event_id":f"shot/{shot['session_id']}/{shot['packet_id']}","operation":"consume","status":0,"amount_applied":-cost,"requested_amount":cost,"current":shot["energy_after"],"capacity":policy["capacity"],"tick":shot["tick"],"session_id":shot["session_id"],"epoch":shot["resource_epoch"]})
        mutations["missing_shot_receipt"]=forged_paid_receipt # Free policy must reject any paid receipt.
    rejected=[]
    for name,mutate in mutations.items():
        bad=copy.deepcopy(capture);mutate(bad)
        require(bad!=capture,"Causal counterexample did not actually change current evidence: "+name)
        try:experience.validate_capture(bad)
        except (ValueError,KeyError):rejected.append(name)
        else:raise ValueError("causal tamper accepted: "+name)
    return rejected


def claim_tamper_checks(capture):
    """The independent R1 four mutations, plus adjacent actual-data corruption."""
    experience.validate_capture(capture)
    def claim(data): return next(o for o in data["policy_observations"] if o.get("kind")=="actual_cache_claim")
    def wrong_output(data):
        c=claim(data);stage=next(s for s in data["formal_run_manifest_final"]["stages"] if s["stage_index"]==data["map_index"])
        stage["outputs"]["cache/wrong_chest"]=stage["outputs"].pop("cache/"+c["chest"])
    def wrong_receipt(data):
        c=claim(data);tx=c["transaction"];key=tx["receipt_prefix"]+"/"+c["chest"]+"/resource"
        tx["after"]["wallet_grants"]["wrong_chest/resource"]=tx["after"]["wallet_grants"].pop(key)
    mutations={"missing_wallet_receipt":lambda d:claim(d).update(wallet_receipts={}),
      "missing_wallet_effect":lambda d:claim(d)["after"].update(coins=claim(d)["before"]["coins"]),
      "forged_reward_amount":lambda d:claim(d)["claim_output"].update(amount=999999),
      "forged_resource_type":lambda d:claim(d)["claim_output"].update(resource="imaginary_resource"),
      "wrong_cache_output":wrong_output,
      "wrong_stage":lambda d:claim(d)["transaction"].update(stage_index=d["map_index"]+1),
      "wrong_selected_offer":lambda d:next(c for c in claim(d)["transaction"]["offer"]["candidates"] if c["id"]==claim(d)["choice"]).update(amount=999),
      "wrong_transaction_receipt":wrong_receipt}
    rejected=[]
    for name,mutate in mutations.items():
        bad=copy.deepcopy(capture);mutate(bad)
        try:experience.validate_capture(bad)
        except (ValueError,KeyError,TypeError):rejected.append(name)
        else:raise ValueError("actual claim tamper accepted: "+name)
    return rejected


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    args=parser.parse_args()
    base=ROOT/"build/verification/plains-encounter";base.mkdir(parents=True,exist_ok=True)
    folder=Path(tempfile.mkdtemp(prefix="run_",dir=base));before=formal.source_files()
    verifier_paths=["tools/run_plains_encounter_policy_tests.py","tools/level_experience.py","tools/run_formal_trace_cancel_tests.py","tests/formal_trace_cancel_runner.gd"]
    verifier_sources={p:formal.file_hash(ROOT/p) for p in verifier_paths}
    receipt={"schema_version":1,"status":"failed","source_before":before,"source_commit":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"scope":"technical actual-input fixtures/live recovery/paired old-new observation; not all routes, device or subjective acceptance","runs":[],"verifier_sources":verifier_sources}
    try:
        # Local import: the immutable historical worker does not need or invoke
        # current-only cancellation fixtures in its separately overlaid tools.
        from run_formal_trace_cancel_tests import run as run_cancel_tests
        receipt["cancellation_consumers"]=run_cancel_tests(folder/"cancellation")
        receipt["reward_entry"]=reward_entry_checks(folder)
        native,native_data=native_run(folder);receipt["runs"].append(native)
        recovery,recovery_data=native_run(folder,True);receipt["runs"].append(recovery)
        for resource in ["heart","note"]:
            proof,_=native_run(folder,True,resource);receipt["runs"].append(proof)
        rejected=[]
        for name,data,mutate,recovery_flag in [
            ("remove_committed",native_data,lambda d:next(c for c in d["cases"] if c["id"].startswith("kill_and_dead_")).update(events=[]),False),
            ("remove_input",native_data,lambda d:[f.update(requests=[]) for c in d["cases"] for f in c["frames"]],False),
            ("remove_return",recovery_data,lambda d:d["cases"][0].update(events=[e for e in d["cases"][0]["events"] if e["kind"]!="segment_returned"]),True),
            ("fake_claim",recovery_data,lambda d:d["cases"][0].update(claimed_after=False),True),
            ("fake_ui_rejection",recovery_data,lambda d:next(o for o in d["cases"][0]["policy_observations"] if o.get("kind")=="actual_wrong_choice_rejected").update(rejected=False),True)]:
            bad=copy.deepcopy(data);mutate(bad)
            try:validate_native(bad,recovery_flag)
            except ValueError:rejected.append(name)
            else:raise ValueError("native tamper accepted "+name)
        receipt["native_tamper_rejected"]=rejected
        env=os.environ.copy()
        env["GUNMAN_TOOLCHAIN_ROOT"]=str(Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT",ROOT.parent/"toolchains")).resolve())
        # These six real producers have independent destinations and read-only
        # sources. Bound concurrency only; retain each original240s producer
        # deadline and the outer original600s specialty budget.
        current_jobs=[(seed,index,strategy,folder/"after"/f"case_{i}"/"capture.json",15000,"kill_from_bank_v1")
                      for i,(seed,index,strategy) in enumerate(CASES)]
        current_jobs.extend([(*CASES[0],folder/"current_repeat"/"capture.json",15000,"kill_from_bank_v1"),
                             ("level-design-v2-baseline",1,"fast",folder/"bait"/"capture.json",10000,"bait_then_bypass_v1")])
        require(len(current_jobs)==6 and len({job[3] for job in current_jobs})==6,
                "current capture matrix/unique destinations changed")
        with ThreadPoolExecutor(max_workers=2) as workers:
            current_futures=[workers.submit(formal.capture_one,seed,index,strategy,target,
                             max_ticks=max_ticks,encounter_policy=policy)
                             for seed,index,strategy,target,max_ticks,policy in current_jobs]
            receipt["current_capture_workers"]=2
            try:
                # Current full135-core consumers are separate from immutable history.
                cohorts={"after":[]}
                for i,(seed,map_index,strategy) in enumerate(CASES):
                    target=folder/"after"/f"case_{i}"/"capture.json"
                    result=current_futures[i].result()
                    require(result["captured"],"actual current formal capture rejected: "+str(result))
                    experience.validate_capture(read(target))
                    cohorts["after"].append(str(target.relative_to(ROOT)))
                receipt["current_cases"]=cohorts["after"]
                write(folder/"after_report.json",experience.report([ROOT/p for p in cohorts["after"]]))
                # An independent actual current-source replay is the comparable positive.
                # It is deliberately not a copy or self-comparison of the first cohort.
                seed,map_index,strategy=CASES[0]
                repeated_target=folder/"current_repeat"/"capture.json"
                repeated=current_futures[4].result()
                require(repeated["captured"],"same-source independent formal capture rejected: "+str(repeated))
                same_source_before=experience.report([ROOT/cohorts["after"][0]])
                same_source_after=experience.report([repeated_target])
                write(folder/"same_source_before_report.json",same_source_before)
                write(folder/"same_source_after_report.json",same_source_after)
                write(folder/"comparison.json",experience.compare(same_source_before,same_source_after))
                receipt["same_source_repeat"]=repeated
                receipt["comparison_scope"]="four current-source cases plus independent current-source return replay compared, not content improvement"
                capture=next(read(ROOT/p) for p in cohorts["after"] if any(e["kind"]=="shot_accepted" for e in read(ROOT/p)["events"]))
                receipt["causal_tamper_rejected"]=policy_tamper_checks(capture)
                growth=next(read(ROOT/p) for p in cohorts["after"] if read(ROOT/p)["strategy"]=="growth")
                receipt["claim_tamper_rejected"]=claim_tamper_checks(growth)
                # Additional explicit non-kill policy, retaining any later route failure.
                bait=current_futures[5].result()
                require(bait["captured"],"nonkill formal capture failed")
                bait_data=read(ROOT/bait["capture"]);experience.validate_capture(bait_data)
                require(any(o.get("kind")=="actual_nonkill_bypass" and o.get("enemy_health",0)>0 for o in bait_data["policy_observations"]),"no actual live non-kill bypass")
                receipt["bait_capture"]=bait
            finally:
                # Do not launch queued producers after an observed failure.
                # Already running producers retain their original bounded
                # process-group cleanup; the pool joins them before unwinding.
                for future in current_futures: future.cancel()
        require(before==formal.source_files(),"source drift during actual specialty")
        require(verifier_sources=={p:formal.file_hash(ROOT/p) for p in verifier_sources},"verifier source drift")
        receipt.update(status="passed",source_after=formal.source_files())
        print("PLAINS ENCOUNTER CURRENT POLICY: actual live input and causal counterexamples validated; historical comparison not_run")
        return 0
    finally:
        receipt.setdefault("source_after",formal.source_files());write(folder/"receipt.json",receipt)
        print("PLAINS ENCOUNTER RECEIPT: "+str((folder/"receipt.json").relative_to(ROOT)),flush=True)

if __name__=="__main__":
    raise SystemExit(main())
