"""Fresh, offline golden technical slices using the existing LEVEL FOUNDRY Motor runner.

No production resource is installed. A technical pass is not difficulty, art,
physical-device, or player acceptance. The validator's input strategy is bounded.
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import math
import re
import subprocess
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

from level_design import source_files
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
SCOPE = "continuous_input_only_real_motor_full_body_sweeps_and_input_replay"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def canonical(value):
    if isinstance(value, dict):
        return {key: canonical(item) for key, item in value.items()}
    if isinstance(value, list):
        return [canonical(item) for item in value]
    if isinstance(value, float):
        require(math.isfinite(value), "nonfinite manifest value")
        return int(value) if value.is_integer() else value
    return value


def manifest_hash(manifest):
    value = {key: item for key, item in manifest.items() if key != "hash"}
    data = json.dumps(canonical(value), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(data.encode()).hexdigest()


def artifact(path):
    return {"path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}


def number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def verify_manifest(manifest, basis, engine):
    require(isinstance(manifest, dict), "missing manifest")
    require(manifest.get("schema") == 1 and manifest.get("scope") == "development_only", "invalid manifest scope/schema")
    require(manifest.get("basis") == basis and manifest.get("engine") == engine, "manifest basis/engine mismatch")
    require(manifest.get("hash") == manifest_hash(manifest), "manifest checksum mismatch")
    require(isinstance(manifest.get("id"), str) and re.fullmatch(r"[A-Za-z0-9_-]+", manifest["id"]), "invalid manifest id")
    require(manifest.get("capability_profile") == "base", "golden scope must use unmodified base capability")
    require(isinstance(manifest.get("nodes"), list) and 0 < len(manifest["nodes"]) <= 24, "empty/oversized manifest nodes")
    if manifest.get("kind") == "itinerary":
        require(manifest["id"] == "route-" + hashlib.sha256(manifest.get("seed", "").encode()).hexdigest()[:10], "itinerary id/seed mismatch")
        require(isinstance(manifest.get("phrases"), list) and len(manifest["phrases"]) == 3, "golden itinerary needs three phrases")
        for phrase in manifest["phrases"]:
            verify_manifest(phrase, basis, engine)
    else:
        expected_id = f'{manifest.get("template_id")}-base-v{int(manifest.get("variant", -1))}-p{int(manifest.get("phase_index", -1))}'
        require(manifest["id"] == expected_id, "manifest id does not match template/variant/phase")


def verify_recording(path, manifest, proof):
    require(path.is_file(), f"missing replay: {path.name}")
    recording = json.loads(path.read_text())
    require(recording.get("schema") == 1, "unsupported replay schema")
    require(recording.get("basis") == manifest["basis"] and recording.get("manifest_hash") == manifest["hash"], "replay basis/hash mismatch")
    require(recording.get("capability_profile") == manifest["capability_profile"], "replay capability mismatch")
    frames = recording.get("frames")
    require(isinstance(frames, list) and 0 < len(frames) <= 5400, "empty/oversized replay frames")
    require(proof.get("ok") is True and proof.get("ticks") == len(frames), "replay did not complete every input frame")
    error = proof.get("max_position_error")
    require(number(error) and 0 <= error <= 0.05, "replay position divergence")
    action_counts = {}
    for index, frame in enumerate(frames):
        require(isinstance(frame, dict) and number(frame.get("axis")) and -1 <= frame["axis"] <= 1, f"invalid axis at {index}")
        require(isinstance(frame.get("position"), list) and len(frame["position"]) == 2 and all(number(n) for n in frame["position"]), f"invalid position at {index}")
        require(number(frame.get("shots")) and frame["shots"] >= 0, f"invalid shot resource at {index}")
        require(isinstance(frame.get("actions"), list), f"missing input actions at {index}")
        for action in frame["actions"]:
            require(isinstance(action, dict) and isinstance(action.get("type"), str) and action["type"], f"invalid action at {index}")
            require(isinstance(action.get("direction"), list) and len(action["direction"]) == 2 and all(number(n) for n in action["direction"]), f"invalid action direction at {index}")
            action_counts[action["type"]] = action_counts.get(action["type"], 0) + 1
    require(action_counts, "recording has no input actions")
    return {"replay": artifact(path), "frames": len(frames), "seconds_at_60hz": len(frames) / 60,
            "input_action_counts": action_counts, "entry_position": frames[0]["position"],
            "exit_position": frames[-1]["position"], "minimum_shot_charges_observed": min(f["shots"] for f in frames),
            "max_replay_position_error": error}


def inspect_batch(path, log, requested):
    """Inspect freshly generated evidence; this alone never claims a fresh run."""
    batch = json.loads(path.read_text())
    require(batch.get("schema") == 1 and batch.get("profile") == "base", "batch schema/profile mismatch")
    require(batch.get("requested") == requested and batch.get("failures") == 0, "batch incomplete or failed")
    require(batch.get("validation_scope") == SCOPE, "unexpected validation scope")
    require(isinstance(batch.get("basis"), str) and re.fullmatch(r"[0-9a-f]{64}", batch["basis"]), "missing validation basis")
    require(isinstance(batch.get("engine"), str) and batch["engine"], "missing engine version")
    require(isinstance(batch.get("assertions"), int) and batch["assertions"] > 0, "no Motor assertions")
    accepted, rejected = batch.get("accepted"), batch.get("rejected")
    require(isinstance(accepted, list) and len(accepted) == requested and isinstance(rejected, list), "accepted/rejected coverage mismatch")
    marker = f"FOUNDRY: accepted={requested} rejected_attempts={len(rejected)} failures=0"
    require(marker in log.splitlines(), "missing exact completion marker")
    require(not re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", log), "Godot script error")
    records, ids, accepted_manifests = [], set(), {}
    for item in accepted:
        manifest = item.get("manifest")
        verify_manifest(manifest, batch["basis"], batch["engine"])
        require(manifest["id"] not in ids, "duplicate accepted manifest id")
        ids.add(manifest["id"])
        accepted_manifests[manifest["id"]] = manifest
        info = verify_recording(path.parent / "replays" / (manifest["id"] + ".json"), manifest, item.get("replay", {}))
        require(item.get("ticks") == info["frames"], "trace and replay frame counts differ")
        require(any(line.startswith(f'FOUNDRY ACCEPT {manifest["id"]} ticks={info["frames"]} ') for line in log.splitlines()), "missing per-manifest acceptance log")
        records.append({"manifest_id": manifest["id"], "manifest_hash": manifest["hash"], "kind": "template", "phrase_count": 1, "template_id": manifest["template_id"],
                        "seed": manifest["seed"], "phase_index": manifest["phase_index"], "modules": manifest["nodes"], **info})
    routes, proofs = batch.get("itineraries"), batch.get("connection_proofs")
    require(isinstance(routes, list) and len(routes) == 6 and isinstance(proofs, list) and len(proofs) == len(routes), "missing complete itinerary proofs")
    for route, proof in zip(routes, proofs):
        verify_manifest(route, batch["basis"], batch["engine"])
        require(route["id"] not in ids, "duplicate itinerary id")
        ids.add(route["id"])
        phrase_ids = [phrase["id"] for phrase in route["phrases"]]
        require(proof.get("ok") is True and proof.get("phrase_ids") == phrase_ids and proof.get("nodes") == len(route["nodes"]), "itinerary proof binding mismatch")
        require(all(phrase_id in ids for phrase_id in phrase_ids), "itinerary uses unaccepted phrases")
        require(all(phrase == accepted_manifests.get(phrase["id"]) for phrase in route["phrases"]), "itinerary phrase differs from accepted manifest")
        info = verify_recording(path.parent / "replays" / (route["id"] + ".json"), route, proof.get("replay", {}))
        records.append({"manifest_id": route["id"], "manifest_hash": route["hash"], "kind": "itinerary", "template_id": "mixed", "phrase_count": len(route["phrases"]), "phrase_ids": phrase_ids,
                        "seed": route["seed"], "modules": route["nodes"], **info})
    require({"height_then_precision", "resource_then_rhythm"} <= {r.get("template_id") for r in records}, "golden templates absent")
    return {"basis": batch["basis"], "engine": batch["engine"], "assertions": batch["assertions"],
            "accepted_phrases": len(accepted), "continuous_itineraries": len(routes), "rejected_attempts": rejected,
            "batch": artifact(path), "records": records}


def bind_design_cards(path, report):
    from level_design_contracts import validate_design
    design = json.loads(path.read_text())
    errors = validate_design(design)
    require(not errors, f"invalid golden design cards: {errors}")
    cards = design.get("challenges", [])
    require({card.get("id") for card in cards} == {"ordinary", "advanced", "master"}, "missing three golden design cards")
    batch_path = ROOT / report["batch"]["path"]
    require(artifact(batch_path)["sha256"] == report["batch"]["sha256"], "golden batch artifact changed before design binding")
    batch = json.loads(batch_path.read_text())
    manifests = {m["id"]: m for m in [entry["manifest"] for entry in batch["accepted"]] + batch["itineraries"]}
    bindings = []
    for card in cards:
        foundry = card.get("foundry", {})
        kind, template, count = foundry.get("kind"), foundry.get("template_id"), foundry.get("phrase_count")
        require(kind in {"template", "itinerary"}, "unsupported golden Foundry kind")
        require(type(count) is int and count == (1 if kind == "template" else 3), "golden Foundry phrase_count does not match supported adapter")
        require(isinstance(template, str) and template and (kind != "itinerary" or template == "mixed"), "golden Foundry template does not match supported adapter")
        matches = [record for record in report["records"] if
                   record.get("kind") == kind and record.get("template_id") == template]
        require(matches, f'no fresh evidence for golden card {card["id"]}')
        for record in matches:
            manifest = manifests.get(record["manifest_id"])
            require(isinstance(manifest, dict), "bound golden record has no actual Manifest")
            verify_manifest(manifest, report["basis"], report["engine"])
            actual_kind = "itinerary" if manifest.get("kind") == "itinerary" else "template"
            actual_template = "mixed" if actual_kind == "itinerary" else manifest.get("template_id")
            actual_count = len(manifest["phrases"]) if actual_kind == "itinerary" else 1
            require((kind, template, count) == (actual_kind, actual_template, actual_count), "golden card kind/template/phrase_count differs from actual Manifest")
            require(record.get("phrase_count") == actual_count and record["manifest_hash"] == manifest["hash"], "golden record metadata differs from actual Manifest")
        bindings.append({"design_card_id": card["id"], "manifest_ids": [r["manifest_id"] for r in matches],
                         "binding_status": "passed", "motor_replay_status": "passed", "challenge_contract_status": "unverified",
                         "verified_scope": "Foundry kind/template/phrase_count and matching recorded Motor replay only",
                         "unverified_contract_fields": ["action_order_and_alternatives", "entry_position_velocity_range",
                                                        "exit_state_range", "energy_and_cooldown_budget", "timing_windows",
                                                        "resource_recovery_intent", "camera_readability", "failure_recovery_intent"],
                         "difficulty_status": "unverified", "visual_status": "unverified"})
    return {"design_cards": artifact(path), "golden_bindings": bindings}


def run(args):
    output = Path(args.output).resolve()
    require(output.is_relative_to(ROOT / "build"), "output must be inside repository build/")
    require(args.count in (6, 12, 24, 48), "count must be 6, 12, 24 or 48 (complete template cycles)")
    output.mkdir(parents=True, exist_ok=True)
    run_dir = output / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8])
    run_dir.mkdir()
    batch = run_dir / "batch.json"
    command = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", "tools/foundry_validate.gd", "--", f"--count={args.count}", "--profile=base", f"--output=res://{batch.relative_to(ROOT)}"]
    started = time.monotonic()
    report = {"schema": 2, "kind": "LevelExperienceReport", "scope": "golden_technical_slice", "status": "failed",
              "command": command, "fresh_execution": False, "production_pool": False,
              "limitations": ["Only the recorded base-capability input strategy is proven; not all weapons, strategies or phases.",
                              "Input replay checks collision and shot charges; it does not expose every energy/cooldown field.",
                              "Normal/advanced/master are design intents; the itinerary is not calibrated master difficulty."],
              "human_review": {"visual": "unverified", "difficulty": "unverified", "player_acceptance": "unverified",
                               "keyboard_mouse": "awaiting-device", "gamepad": "awaiting-device", "touch": "awaiting-device"},
              "screenshots": [], "videos": []}
    report["capability_scope"] = {"profile": "base", "equipped_weapon_source": "resources/weapons/pulse_gun.tres",
                                  "profile_source": "config/foundry_capabilities.json", "runtime_snapshot": "unverified",
                                  "note": "Existing Foundry applies base profile with no tuning overrides; default ShootAbility has one pulse gun. Other legal weapons need separate route evidence."}
    try:
        report["source_commit"] = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
        report["source_files"] = source_files()
        report["consumer_sources"] = [artifact(ROOT / name) for name in ["tools/level_design_golden.py", "tools/foundry.py", "tools/foundry_validate.gd"]]
        # Use the same fail-fast error detection and process-group cleanup as the
        # repository's Godot suite. Redirect its streaming output so even an
        # exception/timeout leaves the complete diagnostic log on disk.
        with (run_dir / "run.log").open("w") as stream, contextlib.redirect_stdout(stream):
            engine_output = run_engine(command[2:], 600)
        report["exit_code"] = 0
        report.update(inspect_batch(batch, engine_output, args.count))
        report.update(bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", report))
        after = source_files()
        report["source_changes"] = sorted(name for name in report["source_files"].keys() | after.keys()
                                          if report["source_files"].get(name) != after.get(name))
        require(not report["source_changes"], "Source changed during golden execution; retained evidence is not fresh")
        report.update({"status": "passed", "fresh_execution": True})
    except Exception as error:
        report["failure"] = str(error)
        # run_engine raises before returning on early errors and timeouts; do
        # not invent an exit code for a process terminated by the watchdog.
        match = re.fullmatch(r"Godot returned (-?\d+)", str(error))
        report.setdefault("exit_code", int(match.group(1)) if match else None)
        raise
    finally:
        report["elapsed_seconds"] = round(time.monotonic() - started, 3)
        if (run_dir / "run.log").is_file():
            report["log"] = artifact(run_dir / "run.log")
        report["report_path"] = str((run_dir / "report.json").relative_to(ROOT))
        text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        (run_dir / "report.json").write_text(text)
        (output / "report.json").write_text(text)
    print(f'GOLDEN EXPERIENCE: {report["accepted_phrases"]} phrases, {report["continuous_itineraries"]} continuous itineraries; technical only. {report["report_path"]}')
