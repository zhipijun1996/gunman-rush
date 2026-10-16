"""PREPARED ONLY: package completed final observations using curate_evidence.pack_files.

Future command, only after all ten recordings/queues are terminal:
  python3 build/plains_redesign/package_final_observations.py --execute

Never starts Godot, browser, OCR, ffmpeg or a model. Never edits original inputs.
Any failed preparation/pack leaves its created directory intact; never overwrite.
The destination is docs/evidence/plains_redesign/final_current (must not exist).
Successful packaging certifies bytes/restoration only, NEVER Q6 or content PASS.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
B = Path("build/plains_redesign")
DESTINATION = ROOT / "docs/evidence/plains_redesign/final_current"
MAX_BYTES = 95 * 1024 * 1024
DELIVERY = Path("build/verification/delivery/20261015T105103Z")
HARNESS = [Path("build/verification/harness/20261015T105150.413469Z"),
           Path("build/verification/harness/20261015T111159.550455Z")]
SCOPE = (
    "Portable original bytes of completed controlled160, analysis2/strict comparison, "
    "eight matched movies plus outer and worst movies, original GUI failure and GUIv2, "
    "C3 delivery/52 with C4 test-only bridge, six controlled map pairs, completed "
    "bounded design/visual reviews, alpha calibration and "
    "restored forest PLAN ONLY. Q6 remains failed; no content/fun/device/player PASS."
)


def need(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def safe_relative(value):
    path = Path(value)
    need(not path.is_absolute() and path.parts and ".." not in path.parts, "Unsafe relative path: " + str(value))
    return path


def source_path(value):
    path = Path(value)
    path = (ROOT / path).resolve() if not path.is_absolute() else path.resolve()
    need(path.is_relative_to(ROOT), "Input outside repository: " + str(path))
    need(path.is_file() and not path.is_symlink(), "Missing/nonregular input: " + str(path))
    return path


def read(value):
    path = source_path(value)
    return json.loads(path.read_text())


def evidence_reference(value):
    """Locate the root's exact copy of a recorded old-project artifact.

    Real old movie screenshots retain absolute frozen-project paths in raw JSON.
    The existing capture queue copies that identical relative subtree into ROOT.
    This mapping selects only that explicit sibling root, then checks the original
    recorded artifact SHA; it never changes raw JSON or admits arbitrary roots.
    """
    path = Path(value)
    if path.is_absolute() and not path.is_relative_to(ROOT):
        old = ROOT.parent / "plains-redesign-baseline"
        need(path.is_relative_to(old), "Unknown recorded artifact root: " + str(path))
        path = ROOT / path.relative_to(old)
    return source_path(path)


def recorded_file(directory, value):
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path if path.parts[0] in {"build", "docs", "tools", "tests", "scripts"} else ROOT / directory / path
    return source_path(path)


def terminal_commands(record, expected_status=None, expected_count=None):
    if expected_status is not None:
        need(record.get("status") == expected_status, "Queue/record not terminal: " + str(record.get("status")))
    need(record.get("finished_utc"), "No actual terminal timestamp")
    commands = record.get("commands")
    need(isinstance(commands, list) and commands, "No actual completed commands")
    if expected_count is not None:
        need(len(commands) == expected_count, "Missing actual completed commands")
    need(all(type(c.get("exit_code")) is int and c["exit_code"] == 0 for c in commands),
         "Missing/nonzero command exit; preserve incomplete evidence, do not package as final")


def bounded_review_finalization(directory):
    """Completed observation review is distinct from ACCEPT/REJECT/UNVERIFIED."""
    directory = Path(directory)
    marker_path = source_path(directory / "finalization.json")
    marker = read(marker_path)
    report_path = source_path(directory / "report.md")
    need(marker.get("status") == "completed_bounded_review",
         "Bounded review has not actually finalized: " + str(directory))
    need(marker.get("report_sha256") == sha(report_path),
         "Review finalization does not bind current report bytes: " + str(directory))
    # The actual independent reviewers write this marker only after observing
    # terminal new movies/maps. This packager never creates or edits markers,
    # and does NOT require a quality ACCEPT: REJECT/UNVERIFIED stay truthful.
    return {"marker": str(marker_path.relative_to(ROOT)), "marker_sha256": sha(marker_path),
            "status": marker["status"], "report": str(report_path.relative_to(ROOT)),
            "report_sha256": marker["report_sha256"]}


def controlled_map_outputs():
    directory = B / "controlled_maps"
    path = source_path(directory / "index.json")
    index = read(path)
    pairs = index.get("pairs")
    need(isinstance(pairs, list) and len(pairs) == 6, "Missing six actual controlled map pairs")
    need({(p.get("map_index"), p.get("after_family")) for p in pairs}
         == {(m, f) for m in (1, 2) for f in ("woven_layers", "crossroads", "linked_rings")},
         "Controlled maps lack actual map/family coverage")
    for pair in pairs:
        need(set(pair.get("sides", {})) == {"before", "after"}, "Unpaired controlled map")
        for row in pair["sides"].values():
            for field, hash_field in (("image", "sha256"), ("svg", "svg_sha256")):
                output = source_path(row[field])
                need(output.is_relative_to(ROOT / directory) and sha(output) == row.get(hash_field),
                     "Controlled PNG/SVG missing or stale")
    return {"index": str(path.relative_to(ROOT)), "index_sha256": sha(path), "actual_pairs": 6}


def formal_capture(folder, rendered=False):
    folder = Path(folder)
    raw = folder / "capture.json"
    data, receipt = read(raw), read(folder / "capture.invocation.json")
    need(receipt.get("schema_version") == 2 and receipt.get("status") == "accepted"
         and receipt.get("errors") == [] and receipt.get("exit_code") == 0, "Unaccepted actual capture: " + str(folder))
    need(receipt.get("capture_sha256") == sha(source_path(raw))
         and receipt.get("log_sha256") == sha(source_path(folder / "capture.log")), "Capture/log receipt SHA mismatch")
    need(receipt.get("source_before") and receipt["source_before"] == receipt.get("source_after")
         == receipt.get("source_files"), "Capture source drift")
    need(data.get("capture_errors") == [] and data.get("frames"), "Missing actual capture result")
    # A real route_policy_failed/run-ended outcome is valid observation, not an
    # integrity failure. Never filter those cases to manufacture route success.
    need(data.get("outcome") not in {None, "running"}, "Capture still running")
    if rendered:
        report = read(folder / "rendered_report.json")
        need(report.get("status") == "captured" and not report.get("error"), "Rendered evidence incomplete")
        for filename, expected in report.get("artifacts", {}).items():
            need(Path(filename).name == filename and sha(source_path(folder / filename)) == expected,
                 "Rendered artifact SHA mismatch: " + filename)
        need(report.get("artifacts", {}).get("gameplay.mp4") == sha(source_path(folder / "gameplay.mp4")),
             "No verified actual MP4")
        screenshots = data.get("screenshots")
        need(isinstance(screenshots, list) and screenshots, "Missing actual movie PNGs")
        for shot in screenshots:
            need(shot.get("error") == 0 and sha(evidence_reference(shot["path"])) == shot.get("sha256"),
                 "Movie screenshot missing/changed")
    return data


def validate_completion():
    q = read(B / "remaining_after_gui_fix_execution.json")
    need(q.get("status") == "recorded_all", "Actual main observation queue is still running/blocked")
    names = {s.get("name") for s in q.get("stages", [])}
    need(names == {"historical_lossless_archive", "controlled_160", "matched_8_movies", "outer_circuit_movie"},
         "Original resumed queue lacks required actual stages")
    need(all(s.get("status") == "passed" and s.get("exit_code") == 0 and s.get("finished_utc")
             for s in q["stages"]), "Original resumed queue has missing/nonterminal stage")
    worst = read(B / "worst_movie_execution.json")
    need(worst.get("status") == "recorded" and worst.get("exit_code") == 0 and worst.get("finished_utc"),
         "Worst movie is still waiting/running/blocked")
    comparison = B / "controlled_comparison"
    need(source_path(comparison / "exit_code.txt").read_text().strip() == "0", "Controlled160 not terminal exit0")
    terminal_commands(read(comparison / "execution.json"))
    keys = []
    for side in ("before", "after"):
        batch = read(comparison / side / "batch.json")
        cases = batch.get("cases")
        need(batch.get("requested_cases") == batch.get("captured_cases") == 80
             and isinstance(cases, list) and len(cases) == 80, "Missing actual primary80: " + side)
        ids = set()
        for row in cases:
            need(row.get("captured") is True and row.get("errors") == [], "Bad capture integrity in primary80")
            data = formal_capture(source_path(row["capture"]).parent)
            identity = (data.get("root_seed"), data.get("map_index"), data.get("strategy"), data.get("phase_wait_ticks"))
            need(identity not in ids, "Duplicate primary identity")
            need((row.get("seed"), row.get("map_index"), row.get("strategy"), row.get("phase_wait_ticks")) == identity,
                 "Batch/raw primary identity differs")
            ids.add(identity)
        need(len({i[0] for i in ids}) == 10, "Not ten actual roots")
        need(ids == {(seed, map_index, strategy, 0) for seed in {i[0] for i in ids}
                     for map_index in (1, 2) for strategy in ("fast", "growth", "deep", "return")},
             "Controlled80 is not the recorded complete root/map/strategy/phase grid")
        keys.append(ids)
    need(keys[0] == keys[1], "Before/after controlled identities differ")
    reports = [read(comparison / (s + "_experience.json")) for s in ("before", "after")]
    for report in reports:
        need(report.get("analysis_version") == 2 and len(report.get("cases", [])) == 80, "Missing analysis2 full80")
        payload = {k: v for k, v in report.items() if k != "fingerprint"}
        expected = hashlib.sha256(json.dumps(payload, sort_keys=True, allow_nan=False).encode()).hexdigest()
        need(report.get("fingerprint") == expected, "Analysis2 saved fingerprint mismatch")
        need(len(report.get("artifacts", [])) == 80, "Analysis2 lacks its exact raw/receipt artifacts")
        for artifact in report["artifacts"]:
            need(sha(evidence_reference(artifact["path"])) == artifact["sha256"]
                 and sha(evidence_reference(artifact["receipt"])) == artifact["receipt_sha256"],
                 "Analysis2 artifact/raw receipt provenance changed")
    strict = read(comparison / "comparison.json")
    need(strict.get("artifact_kind") == "level_experience_comparison"
         and strict.get("verdict") == "REVIEW" and len(strict.get("cases", [])) == 80
         and strict.get("before_fingerprint") == reports[0]["fingerprint"]
         and strict.get("after_fingerprint") == reports[1]["fingerprint"], "Missing original strict comparison result")
    need("EXPERIENCE REVIEW: 80 actual cases" in source_path(comparison / "compare.log").read_text(),
         "Missing original strict compare completion log")
    readout = read(comparison / "root_readout.json")
    for side in ("before", "after"):
        need(sha(source_path(readout["inputs"][side]["path"])) == readout["inputs"][side]["sha256"],
             "Root readout no longer binds actual analysis2 input bytes")
    read(comparison / "unresolved_locations.json")
    movies = B / "matched_movies"
    terminal_commands(read(movies / "execution.json"), "captured", 8)
    rendered = sorted((ROOT / movies).glob("*/*/rendered_report.json"))
    need(len(rendered) == 8, "Missing actual matched8 rendered reports")
    seen = set()
    for report in rendered:
        need(report.parent.parent.name in {"before", "after"}, "Unknown matched side")
        seen.add((report.parent.parent.name, report.parent.name))
        formal_capture(report.parent, rendered=True)
    cases = {"intro_fast", "creek_growth", "advanced_deep", "high_return"}
    need(seen == {(side, case) for side in ("before", "after") for case in cases}, "Matched8 roles incomplete")
    outer = B / "final_outer_movie"
    receipt = read(outer / "receipt.json")
    need(receipt.get("status") == "captured" and receipt.get("source_files") == receipt.get("source_after")
         and receipt.get("process", {}).get("status") == "passed"
         and receipt.get("movie_sha256") == sha(source_path(outer / "gameplay.mp4")), "Outer movie incomplete/drifting")
    data = read(outer / "capture.json")
    need(data.get("failures") == 0 and data.get("cases") and data["cases"][0].get("outcome") == "route_target_reached"
         and receipt.get("actual_circuit", {}).get("reached") is True, "Missing actual outer circuit result")
    for shot in data.get("screenshots", []):
        need(shot.get("error") == 0 and sha(evidence_reference(shot["path"])) == shot.get("sha256"), "Outer PNG changed")
    need(data.get("screenshots"), "Outer screenshots absent")
    formal_capture(B / "worst_movie", rendered=True)
    # Historical failure is intentionally terminal FAILED, never required to pass.
    old_queue = read(B / "remaining_observations_execution.json")
    need(str(old_queue.get("status", "")).startswith("blocked_"), "Original failed GUI queue is not terminal blocked")
    source_path(B / "final_gui/execution.json")
    gui = read(B / "final_gui_v2/execution.json")
    terminal_commands(gui, "passed", 2)
    for command in gui["commands"]:
        path = B / "final_gui_v2" / command["name"] / "browser-report.json"
        need(sha(source_path(path)) == command.get("report_sha256") and read(path).get("failed") == 0,
             "GUIv2 report changed/missing")
    bridge = read(B / "gui_locator_diagnosis/c3_to_current_bridge.json")
    need(bridge.get("runtime_changed_paths") == [], "C3-to-C4 runtime bridge no longer test-only")
    closure = read(B / "final_regression_review/c4/closure_provenance.json")
    need(closure.get("verdict") == "ACCEPT", "Missing completed scoped engineering closure")
    # Both reviewers must finish the bounded observation scope after terminal
    # new movies/maps. Marker status concerns completion, never artistic PASS.
    maps = controlled_map_outputs()
    finalizations = {name: bounded_review_finalization(B / name)
                     for name in ("final_design_review", "final_visual_review")}
    source_path(B / "final_design_review/report.md")
    design = read(B / "final_design_review/provenance.json")
    need(design.get("created_utc") and design.get("reviewed_head"), "Missing actual design-review provenance")
    forest = read(B / "restored_forest_dry_run/plan.log")
    need(forest.get("mode") == "plan_only", "Restored forest must remain honestly plan-only")
    need(read(B / "restored_forest_dry_run/mission.json").get("scope") == "offline_production_plan_not_executed",
         "Restored forest mission no longer plan-only")
    ledger = read(B / "execution_ledger.json")
    need(ledger.get("production_budget") == 33 and ledger.get("remaining_calls") == 0
         and sum(c.get("calls", 0) for c in ledger.get("calls", [])) == 31, "31/cap33 closed ledger differs")
    for name in ("q6-rework", "q6-cliff-asset"):
        need(read("build/verification/plains-redesign-" + name + "/state.json").get("status") == "blocked",
             "Do not relabel original Q6 content failure")
    return {"controlled_cases": 160, "matched_movies": 8, "outer_movies": 1, "worst_movies": 1,
            "controlled_maps": maps, "bounded_review_finalizations": finalizations,
            "Q6": "failed_blocked_preserved", "forest": "plan_only", "quality": "not_evaluated_by_packaging"}


def build_items():
    paths = set()
    excluded = []

    def add(value):
        path = source_path(value)
        if path.suffix.lower() == ".avi":
            excluded.append({"original_path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                             "reason": "Explicitly excluded rebuildable AVI; original MP4/trace/report retained"})
            return
        need(path.stat().st_size < MAX_BYTES, "Input >=95MiB, refuse entire package rather than skip: " + str(path))
        paths.add(path)

    def tree(value):
        directory = ROOT / value
        need(directory.is_dir() and not directory.is_symlink(), "Missing required complete tree: " + str(value))
        files = sorted(p for p in directory.rglob("*") if p.is_file())
        need(files, "Empty evidence tree: " + str(value))
        for path in files:
            need(not path.is_symlink(), "Symlink evidence rejected: " + str(path))
            add(path)

    # Entire trees include root_readout/unresolved_locations/intro_player_harm
    # and later actual same-tree diagnostics, rather than a summary-only list.
    for folder in ("controlled_comparison", "controlled_maps", "matched_movies", "final_outer_movie", "worst_movie",
                   "final_gui", "final_gui_v2", "gui_locator_diagnosis", "final_regression_review",
                   "final_design_review", "final_visual_review", "asset_contract_calibration", "restored_forest_dry_run"):
        tree(B / folder)
    optional_forest = ROOT / B / "final_forest_closure"
    if optional_forest.exists():
        for filename in ("execution.json", "finalization.json"):
            if (optional_forest / filename).is_file():
                status = str(read(optional_forest / filename).get("status", ""))
                need(not status.startswith(("running", "waiting", "pending")),
                     "Optional final_forest_closure is still active")
        tree(B / "final_forest_closure")
    delivery = read(DELIVERY / "report.json")
    need(delivery.get("status") == "passed" and len(delivery.get("steps", [])) == 12, "Original C3delivery not complete")
    add(DELIVERY / "report.json")
    for step in delivery["steps"]:
        need(step.get("status") == "passed" and step.get("exit_code") == 0, "Original C3delivery step failed")
        add(recorded_file(DELIVERY, step["log"]))
    check_sets = []
    for directory, count in zip(HARNESS, (49, 22)):
        report = read(directory / "report.json")
        need(report.get("status") == "passed" and report.get("release") is True
             and len(report.get("checks", [])) == count, "Missing actual original release report")
        add(directory / "report.json")
        for check in report["checks"]:
            need(check.get("status") == "passed" and check.get("exit_code") == 0
                 and check.get("reused") is False, "Original check not fresh passed")
            add(recorded_file(directory, check["log"]))
        check_sets.append({c["id"] for c in report["checks"]})
    need(len(check_sets[0] | check_sets[1]) == 52, "Original49/22 union differs")
    for name in ("restored_coverage.json", "restored_source_checkpoint.json", "execution_ledger.json",
                 "remaining_observations_execution.json", "remaining_after_gui_fix_execution.json",
                 "worst_movie_execution.json", "outer_cli_pre_execution_fix.json", "c2_action_movie_preservation.json",
                 "q6_final_delivery.log", "final_gui_v2.log", "remaining_gui.log", "remaining_after_gui_fix.log",
                 "worst_movie.log", "final_execution_notes.md"):
        add(B / name)
    add(B / "historical_raw_archive/manifest.json")
    for queue_name in ("remaining_observations_execution.json", "remaining_after_gui_fix_execution.json"):
        for stage in read(B / queue_name).get("stages", []):
            if stage.get("log"):
                add(stage["log"])
    for name in ("curate_evidence.py", "package_final_observations.py", "run_controlled_comparison.py",
                 "run_matched_movies.py", "record_outer_loop.py", "record_outer_loop.pre_call_cli.py",
                 "render_outer_loop.gd", "capture_worst_after_queue.py", "run_remaining_observations.py",
                 "run_remaining_after_gui_fix.py", "run_final_gui.py", "run_final_gui_v2.py",
                 "archive_historical_traces.py", "plot_controlled_maps.py", "update_final_quality_records.py",
                 "deduplicate_frozen_before_mirror.py", "frozen_mirror_storage.json", "frozen_mirror_storage.log",
                 "archive_portable_primary_raws.py", "apply_final_knowledge.py",
                 "run_post_capture_maps.py", "map_execution.json", "map_execution.log"):
        add(B / name)
    for value in ("tools/level_formal.py", "tools/level_formal_capture.gd", "tools/level_experience.py",
                  "tools/level_visual_capture.py", "tools/capture_actions.py", "tools/action_movie_capture.gd",
                  "tools/verify_plains_region_browser.py", "tools/verify_floating_touch_browser.py"):
        add(value)
    current_actions = Path("build/verification/actions-movie")
    actions = read(current_actions / "report.json")
    need(actions.get("status") == "passed" and actions.get("media_sha256")
         == sha(source_path(current_actions / "actions.mp4")), "Current capture_actions MP4/receipt mismatch")
    tree(current_actions)
    add("build/action_budget/movie_trace.json")
    preservation = read(B / "c2_action_movie_preservation.json")
    preserved = safe_relative(preservation["preserved"])
    # Preserve the C2 mapping/old receipt. Identical old/current MP4 bytes may
    # share one stored member, while both original paths remain restorable.
    for name, meta in preservation["files"].items():
        need(Path(name).name == name, "Unsafe C2action mapping")
        if Path(name).suffix.lower() == ".avi":
            excluded.append({"original_path": str(preserved / name), "bytes": meta["bytes"],
                             "reason": "C2 AVI excluded explicitly; SHA remains in original preservation mapping"})
            continue
        old = source_path(preserved / name)
        need(sha(old) == meta["sha256"], "Preserved C2 action member changed")
        add(old)
    info = source_path("build/web/build-info.json")
    need(sha(info) == delivery.get("build_info_sha256") and json.loads(info.read_text()) == delivery.get("build_info")
         and delivery["build_info"].get("build_id") == "eeeb0759998d", "Actual current Web build differs from C3 report")
    add(info)
    coverage = read(B / "restored_coverage.json")
    need(coverage.get("union_count") == 52 and coverage.get("active_q6_goal", "").startswith("failed"),
         "Coverage record lost truthful Q6failed boundary")
    for item in coverage.get("reports", []):
        need(sha(source_path(item["path"])) == item["sha256"], "Coverage report SHA mismatch")
    return sorted(paths), excluded


RESTORE_SOURCE = r'''"""Restore this bundle's original byte paths into a NEW isolated root; no engines."""
import argparse, gzip, hashlib, json
from pathlib import Path

MAX_BYTES = 95 * 1024 * 1024
def require(ok, reason):
    if not ok: raise ValueError(reason)
def digest(data): return hashlib.sha256(data).hexdigest()
def relative(value):
    p = Path(value)
    require(not p.is_absolute() and p.parts and '..' not in p.parts, 'Unsafe member path')
    return p
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--resume-identical', action='store_true', help='Only existing byte-identical targets may be skipped')
    args=parser.parse_args(); bundle=Path(__file__).resolve().parent
    index=json.loads((bundle/'index.json').read_text())
    require(index.get('status')=='portable_bytes_verified', 'Bundle incomplete, not restorable as final')
    require(digest(Path(__file__).read_bytes())==index['generated_files']['restore.py']['sha256'], 'Restore producer changed')
    root=args.root.resolve()
    require(root!=bundle and not root.is_relative_to(bundle) and not bundle.is_relative_to(root), 'Root overlaps bundle')
    require(not root.exists() or (args.resume_identical and root.is_dir()), 'Use a NEW isolated root or explicit identical-only resume')
    seen=set()
    # Check all archive bytes and target conflicts before writing any originals.
    for member in index['members']:
        rel=relative(member['original_path']); stored=(bundle/relative(member['stored'])).resolve()
        require(str(rel) not in seen, 'Duplicate original path'); seen.add(str(rel))
        require(stored.is_relative_to(bundle) and stored.is_file(), 'Missing/outside stored member')
        payload=stored.read_bytes()
        require(len(payload)<MAX_BYTES and digest(payload)==member['stored_sha256'], 'Stored SHA/size mismatch')
        require(member['compression'] in ('gzip','none'), 'Unknown compression')
        raw=gzip.decompress(payload) if member['compression']=='gzip' else payload
        require(len(raw)<MAX_BYTES and len(raw)==member['bytes'] and digest(raw)==member['sha256'], 'Restored raw SHA/size mismatch')
        target=(root/rel).resolve(); require(target.is_relative_to(root), 'Target escapes isolated root')
        if target.exists():
            require(target.is_file() and digest(target.read_bytes())==member['sha256'], 'Different existing file; never overwrite: '+str(rel))
    root.mkdir(parents=True, exist_ok=args.resume_identical)
    restored=skipped=0
    for member in index['members']:
        target=root/relative(member['original_path'])
        if target.exists():
            require(target.is_file() and digest(target.read_bytes())==member['sha256'], 'Existing file changed after preflight')
            skipped+=1; continue
        payload=(bundle/relative(member['stored'])).read_bytes()
        require(digest(payload)==member['stored_sha256'], 'Stored file changed after preflight')
        raw=gzip.decompress(payload) if member['compression']=='gzip' else payload
        require(digest(raw)==member['sha256'] and len(raw)==member['bytes'], 'Decode changed after preflight')
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb') as stream: stream.write(raw)
        require(digest(target.read_bytes())==member['sha256'], 'Written raw SHA mismatch')
        restored+=1
    print('Restored',restored,'original files; identical skipped',skipped,'Q6/fun/device remain unaccepted:',root)
if __name__=='__main__': main()
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--execute", action="store_true", help="Explicit future packaging after all real results are terminal")
    args = parser.parse_args()
    need(args.execute, "Preparation only; specify --execute only AFTER actual observations finish")
    need(not DESTINATION.exists(), "Retain existing/failed destination; never overwrite final_current")
    completed = validate_completion()
    sources, excluded = build_items()
    expected = {str(p.relative_to(ROOT)): {"sha256": sha(p), "bytes": p.stat().st_size} for p in sources}
    helper = source_path(B / "curate_evidence.py")
    spec = importlib.util.spec_from_file_location("existing_curate_evidence", helper)
    need(spec is not None and spec.loader is not None, "Cannot load existing pack_files")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    historical = []
    for path in ("docs/evidence/plains_redesign/scene_q6_rework/index.json",
                 "docs/evidence/plains_redesign/q6_cliff_asset/index.json",
                 "docs/evidence/plains_redesign/q6_before/index.json"):
        file = source_path(path)
        historical.append({"path": path, "sha256": sha(file), "copied": False,
                           "reason": "Already archived rejected Q6/C2 history, linked without duplicate tree"})
    # Input size refusal occurs before destination creation; missing/running
    # results above likewise create no misleading partial final index.
    items, aliases, first_by_sha = [], [], {}
    for path in sources:
        rel = path.relative_to(ROOT)
        raw_sha = expected[str(rel)]["sha256"]
        if rel.name == "actions.mp4" and raw_sha in first_by_sha:
            aliases.append((rel, first_by_sha[raw_sha]))
            continue
        stored = Path("raw") / rel
        if rel.suffix.lower() == ".md":
            stored = stored.with_name(stored.name + ".source")
        items.append((path, stored))
        first_by_sha.setdefault(raw_sha, rel)
    DESTINATION.mkdir(parents=True, exist_ok=False)
    try:
        members = module.pack_files(items, DESTINATION)
        mapped = {}
        for member in members:
            original = source_path(member.pop("source")).relative_to(ROOT)
            member["original_path"] = str(original)
            member["original_root"] = str(original)  # compatibility alias, always repository-relative
            member["source"] = str(original)  # no machine-specific absolute source in the index
            need(member["sha256"] == expected[str(original)]["sha256"]
                 and member["bytes"] == expected[str(original)]["bytes"], "Input changed while pack_files read it")
            stored = DESTINATION / safe_relative(member["stored"])
            need(stored.stat().st_size < MAX_BYTES, "Stored member >=95MiB; refuse entire final package")
            member["stored_bytes"] = stored.stat().st_size
            mapped[str(original)] = member
        for original, existing in aliases:
            alias = dict(mapped[str(existing)])
            alias.update(original_path=str(original), original_root=str(original), source=str(original),
                         stored_alias_of=str(existing))
            need(alias["sha256"] == expected[str(original)]["sha256"], "Alias does not preserve exact raw bytes")
            members.append(alias)
        for path in sources:
            need(sha(path) == expected[str(path.relative_to(ROOT))]["sha256"], "Source changed during packaging")
        rescanned_sources, rescanned_excluded = build_items()
        need(rescanned_sources == sources and rescanned_excluded == excluded,
             "Evidence tree membership changed during packaging; refuse incomplete whole-tree index")
        for name, original in completed["bounded_review_finalizations"].items():
            need(bounded_review_finalization(B / name) == original,
                 "Review report/marker changed after completion preflight")
        need(controlled_map_outputs() == completed["controlled_maps"], "Controlled maps changed during packaging")
        verified_stored = {}
        for member in members:
            if member["stored"] not in verified_stored:
                payload = (DESTINATION / safe_relative(member["stored"])).read_bytes()
                need(len(payload) < MAX_BYTES, "Stored member >=95MiB after packaging")
                recovered = gzip.decompress(payload) if member["compression"] == "gzip" else payload
                verified_stored[member["stored"]] = (
                    hashlib.sha256(payload).hexdigest(), hashlib.sha256(recovered).hexdigest(), len(recovered))
            need(verified_stored[member["stored"]] == (
                member["stored_sha256"], member["sha256"], member["bytes"]),
                "Stored/raw SHA or decoded length became stale; refuse final index")
        (DESTINATION / "restore.py").write_text(RESTORE_SOURCE)
        readme = (
            "Final observations portable byte bundle\n\n" + SCOPE + "\n\n"
            "index.members.original_path is the original repository-relative restore path. "
            "stored is relative to this bundle. sha256 hashes ORIGINAL bytes; stored_sha256 "
            "hashes the actual stored file (including gzip). Quality records referencing a "
            "stored .gz MUST use stored_sha256, never the original JSON SHA.\n"
            "Markdown source bytes use .md.source; restoration returns their exact .md names. "
            "AVI is explicitly excluded; each MP4, PNG and raw trace remains. Already archived "
            "rejected Q6/old baseline trees are referenced, not recopied. C2/current identical "
            "action MP4s may share stored bytes with separate restorable paths.\n\n"
            "Restore without engines: python3 restore.py --root /tmp/new-isolated-observation-root\n"
            "Never overwrites differing files. --resume-identical permits only identical skips. "
            "A PACKAGING_FAILED.json without the final index is incomplete; retain it.\n\n"
            "Consumer coverage inventory belongs separately, uncompressed, at "
            "docs/evidence/plains_redesign/acceptance/consumer_inventory.json; this packager "
            "does not create or alter that acceptance record.\n"
            "Embedded historical absolute paths inside original JSON remain unchanged by design; "
            "restore verifies original bytes at repository-relative paths, not a promise that "
            "every archived analyzer can replay without an explicit relocation adapter.\n"
        )
        (DESTINATION / "README.md.source").write_text(readme)
        index = {"schema_version": 1, "status": "portable_bytes_verified", "scope": SCOPE,
                 "created_utc": datetime.now(timezone.utc).isoformat(),
                 "packaged_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                 "Q6_content_status": "failed", "content_acceptance": "not_granted",
                 "completed_observations": completed, "members": members, "excluded": excluded,
                 "optional_forest_closure_included": any(
                     p.is_relative_to(ROOT / B / "final_forest_closure") for p in sources),
                 "historical_references_not_duplicated": historical,
                 "producer": {"original_path": str(Path(__file__).resolve().relative_to(ROOT)),
                              "sha256": sha(Path(__file__)), "pack_files_original_path": str(helper.relative_to(ROOT)),
                              "pack_files_sha256": sha(helper)},
                 "generated_files": {name: {"sha256": sha(DESTINATION / name)}
                                     for name in ("restore.py", "README.md.source")},
                 "quality_reference_rule": "Use actual stored member path + stored_sha256 for gzip evidence; sha256 is original raw bytes.",
                 "separate_uncompressed_consumer_inventory": "docs/evidence/plains_redesign/acceptance/consumer_inventory.json"}
        with (DESTINATION / "index.json").open("x") as stream:
            json.dump(index, stream, ensure_ascii=False, indent=2, allow_nan=False)
            stream.write("\n")
        print("Portable original bytes verified:", len(members), "members; ten recordings; Q6 remains failed:", DESTINATION)
    except Exception as error:
        failure = {"status": "incomplete_package_preserve_do_not_overwrite", "error": str(error), "Q6": "failed"}
        with (DESTINATION / "PACKAGING_FAILED.json").open("x") as stream:
            json.dump(failure, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        raise


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, AssertionError) as error:
        print("REFUSED; no original evidence edited:", error, file=sys.stderr)
        raise SystemExit(2)
