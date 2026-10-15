import datetime, hashlib, json, subprocess, sys
from pathlib import Path
R=Path.cwd();O=R/"build/plains_redesign/final_regression_review/c3"
H=lambda b:hashlib.sha256(b).hexdigest()
start=datetime.datetime.now(datetime.timezone.utc).isoformat()
argv=[sys.executable,str((O/"static_delta.py").relative_to(R))]
p=subprocess.run(argv,cwd=R,capture_output=True,text=True)
(O/"static_recheck.log").write_text(p.stdout+p.stderr)
commands=[dict(argv=argv,cwd=str(R),started_at=start,finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),exit_code=p.returncode,log=str((O/"static_recheck.log").relative_to(R)))]
assert p.returncode==0,p.stderr
r=json.loads((O/"static_delta.json").read_text())
sys.path.insert(0,str(R/"tools"));import level_formal
selected=["AGENTS.md","tools/check_quality_diff.py","tools/harness/profiles.json","docs/harness.md","docs/quality/plains_redesign_q6_rollback.md","docs/quality/plains_redesign_q6_rework.md","docs/quality/plains_redesign_q6_cliff_asset.md","build/plains_redesign/q6_rollback/execution.json","build/plains_redesign/scene/run_61gbwnn6/receipt.json","build/plains_redesign/final_diff_pre_review.log","build/plains_redesign/final_regression_review/report.md","build/plains_redesign/final_regression_review/provenance.json","build/plains_redesign/review_root_revisions/report.md"]
selected+=list(level_formal.core_source_paths())+list(level_formal.driver_source_paths())
selected+=[x["path"] for x in r["restored_exact_files"]]+[x["path"] for x in r["failed_archive_indices"]]+[x["path"] for x in r["frozen_v9"]]+r["committed_active_delta"]
inventory=[]
for name in sorted(set(selected)):
 b=(R/name).read_bytes();inventory.append(dict(path=name,bytes=len(b),sha256=H(b)))
(O/"read_inventory.json").write_text(json.dumps(inventory,indent=2))
(O/"commands.json").write_text(json.dumps(commands,indent=2))
provenance=dict(agent_id="/root/plains_spatial_audit",scope="Independent read-only C3 regression guard delta, static preparation only",verdict="UNVERIFIED",baseline=r["baseline"],c2=r["c2"],c3=r["c3"],commands=commands,read_inventory="read_inventory.json",archive_member_inventory="failed_member_hashes.json",foundry_bridge="foundry_c2_c3_actual_bridge.json",current_findings=[],limitations=["Final C3 native52-union/delivery/GUI/cohort not yet admitted; parent is running delivery.","No engine/browser/ffmpeg or recording process was started by this review.","Reuses prior independently inspected C2 semantic test/fixture/tooling analysis only where source bytes are exact; does not claim all native checks rerun here.","Failed candidate native receipts are provenance/history, not current C3 passes or aesthetic acceptance.","Whole Q6 remains failed. Human/device/fun/visual approval is outside this review."],artifact_hashes={n:H((O/n).read_bytes()) for n in ["static_delta.py","static_delta.json","static_recheck.log","failed_member_hashes.json","foundry_c2_c3_actual_bridge.json","read_inventory.json","commands.json"]})
(O/"provenance.json").write_text(json.dumps(provenance,indent=2));print("static C3 preparation recorded",len(inventory),"source/read hashes; UNVERIFIED")
