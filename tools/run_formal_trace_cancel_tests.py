"""Actual test-driver cancellation and negative acknowledgement consumers."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import level_formal as formal
from level_design import ROOT, read, write

CASES = {"budget_move", "nested_deep_trial", "nested_branch_helper", "invalid_motor_entry", "nested_claim_wait", "real_fatal_default_cleanup", "noncooperative_ack"}
ERRORS = r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit"

def validate(data):
    if data.get("artifact_kind") != "formal_trace_cancellation_proof" or data.get("schema_version") != 1 or data.get("failures") != 0 or data.get("assertions",0)<14:
        raise ValueError("failed/empty actual cancellation proof")
    rows=data.get("cases",[])
    if len(rows)!=len(CASES) or {r.get("id") for r in rows}!=CASES:
        raise ValueError("incomplete cancellation consumer matrix")
    for row in rows:
        receipt=row.get("unwind",{})
        if not (row.get("driver_released") is True and row.get("helper_released") is True and row.get("audio_released") is True and row.get("observers_disconnected",0)>0 and receipt.get("ok") is True and receipt.get("execution_done") is True and receipt.get("requested") is True and receipt.get("before") and receipt["before"]==receipt.get("after") and receipt["before"].get("terminated") is True and receipt["before"].get("post_seal_accepted_events")==[] and re.fullmatch(r"[0-9a-f]{64}",str(row.get("sealed_case_sha256",""))) and row["sealed_case_sha256"]==row.get("post_unwind_sha256")):
            raise ValueError("cancellation changed sealed evidence/counters or failed actual release: "+str(row.get("id")))
        facts=receipt["before"]
        if row["id"] == "real_fatal_default_cleanup":
            if not (facts.get("controller_valid") is False and facts.get("motor_valid") is False and facts.get("queued_actions")==-1 and facts.get("router_sequence")==-1 and facts.get("controller_tick")==-1 and facts.get("router_axis")==0 and facts.get("health") is None and facts.get("shot_energy") is None):
                raise ValueError("fatal cleanup retained actor/router state")
        elif not (facts.get("controller_valid") is True and facts.get("router_axis")==0 and facts.get("queued_actions")==0):
            raise ValueError("live cancellation retained movement or queued actions")
        if row.get("cancel_site") != row["id"]:
            raise ValueError("declared cancellation site was never reached")
        if row["id"]=="real_fatal_default_cleanup":
            events=row.get("first_terminal_observation",{}).get("events",[])
            if not (row.get("production_cleanup_done_before_unwind") is True and any(e.get("kind")=="player_health" and e.get("current")==0 for e in events) and any(e.get("kind")=="damage_committed" and e.get("target")=="player" and e.get("lethal") is True for e in events) and any(e.get("kind")=="died" for e in events) and any(e.get("kind")=="run_ended" for e in events) and receipt["before"].get("controller_valid") is False):
                raise ValueError("real default fatal cleanup was not observed")
        if row["id"]=="noncooperative_ack":
            refusal=receipt.get("expected_timeout_refusal",{})
            if not (row.get("expected_timeout_refused") is True and refusal.get("ok") is False and refusal.get("execution_done") is False and refusal.get("deadline_msec")==1000 and refusal.get("elapsed_msec",0)>=1000):
                raise ValueError("noncooperative acknowledgement was not actually refused")
    return True

def run(output_dir):
    folder=Path(output_dir).resolve();folder.mkdir(parents=True,exist_ok=True)
    before=formal.source_files();verifiers={n:formal.file_hash(ROOT/n) for n in ["tools/run_formal_trace_cancel_tests.py","tools/run_plains_encounter_policy_tests.py"]}
    output=folder/"capture.json";log=folder/"native.log"
    argv=["bash","tools/godot.sh","--headless","--fixed-fps","60","--path",".","--script","tests/formal_trace_cancel_runner.gd","--","--output=res://"+output.relative_to(ROOT).as_posix()]
    receipt={"schema_version":1,"status":"failed","scope":"real bounded test-driver cancellation fixtures, not formal traversal or gameplay combat","argv":argv,"source_before":before,"verifier_before":verifiers,"timeout_seconds":180}
    started=time.monotonic()
    try:
        with log.open("w") as stream:process=subprocess.run(argv,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
        receipt["exit_code"]=process.returncode
        text=log.read_text()
        if process.returncode!=0 or re.search(ERRORS,text) or not re.search(r"^FORMAL TRACE CANCEL: [1-9]\d* assertions, 0 failures, 7 cases$",text,re.M):
            raise ValueError("actual cancellation process failed or leaked")
        validate(read(output))
        receipt.update(source_after=formal.source_files(),verifier_after={n:formal.file_hash(ROOT/n) for n in verifiers})
        if receipt["source_before"]!=receipt["source_after"] or receipt["verifier_before"]!=receipt["verifier_after"]:
            raise ValueError("source drift during actual cancellation specialty")
        receipt.update(status="passed",capture_sha256=formal.file_hash(output),log_sha256=formal.file_hash(log))
        return receipt
    finally:
        receipt["elapsed_seconds"]=time.monotonic()-started
        receipt.setdefault("source_after",formal.source_files())
        write(folder/"receipt.json",receipt)

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--output-dir",type=Path,required=True);args=parser.parse_args()
    result=run(args.output_dir);print("FORMAL TRACE CANCELLATION: actual strict consumers passed;",result["elapsed_seconds"],"seconds")
