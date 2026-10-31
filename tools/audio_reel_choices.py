"""Import V3 reel preferences without inventing choices for unselected events.

The reel manifest is trusted recording evidence, the bank is trusted waveform
evidence. This checks their bindings and the selected local WAV bytes; it does
not rate sounds or turn a preference into approval of an entire recording.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TASK = "AUDIO-DIRECTOR-03"
VERSION = "audio-director-v3"
EVENTS = (
    "coin", "heal", "chest_open", "item_get", "click", "confirm", "denied",
    "enemy_hit", "enemy_hurt", "hurt", "shot_pulse", "shot_shuriken",
    "shot_bomb", "bomb_explode",
)
TOP_FIELDS = {"schema_version", "task", "candidate_version", "source_commit", "exported_at", "choices"}
ROW_FIELDS = {
    "clip_id", "event_id", "candidate_id", "sound_candidate_id", "profile",
    "video_version", "event_ids", "source_ids", "start", "end", "version",
    "note", "updated_at",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def _bad_constant(value):
    raise ValueError("Non-finite JSON number: " + value)


def read_json(data: bytes):
    return json.loads(data.decode("utf-8"), object_pairs_hook=_unique_object,
                      parse_constant=_bad_constant)


def _finite_tree(value):
    if isinstance(value, float):
        require(math.isfinite(value), "Non-finite number")
    elif isinstance(value, dict):
        for item in value.values():
            _finite_tree(item)
    elif isinstance(value, list):
        for item in value:
            _finite_tree(item)


def _time(value, label):
    require(type(value) in (int, float) and math.isfinite(value), "Invalid finite " + label)
    return value


def _timestamp(value, label):
    require(isinstance(value, str), "Invalid " + label)
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError("Invalid " + label) from error
    require(parsed.tzinfo is not None, "Timestamp needs timezone: " + label)
    return parsed


def _index(items, key, label):
    require(isinstance(items, list), "Expected array: " + label)
    result = {}
    for item in items:
        require(isinstance(item, dict) and isinstance(item.get(key), str), "Invalid " + label)
        identifier = item[key]
        require(identifier and identifier not in result, "Duplicate/empty " + label + ": " + identifier)
        result[identifier] = item
    return result


def normalize(payload, reels, bank, *, root=ROOT):
    """Return deterministic mapping; arguments are already parsed trusted manifests.

    Missing/rejected events stay original with no user approval. Only the
    inseparable *original* bomb action carries its paired explosion choice.
    No other multi-event reel implies approval of its accompanying events.
    """
    for value in (payload, reels, bank):
        require(isinstance(value, dict), "Expected JSON object")
        _finite_tree(value)
    require(set(payload) == TOP_FIELDS, "Choice export schema fields differ")
    require(type(payload["schema_version"]) is int and payload["schema_version"] == 1,
            "Unsupported export schema_version")
    for evidence in (reels, bank):
        require(type(evidence.get("schema_version")) is int and evidence["schema_version"] == 1,
                "Unsupported evidence schema_version")
        require(evidence.get("task") == TASK and evidence.get("version") == VERSION,
                "Evidence task/version differs")
    require(payload["task"] == TASK and payload["candidate_version"] == VERSION,
            "Choice task/candidate_version differs")
    require(isinstance(reels.get("source_commit"), str)
            and re.fullmatch(r"[0-9a-f]{40}", reels["source_commit"]) is not None,
            "Invalid reel source commit")
    require(payload["source_commit"] == reels["source_commit"], "Choice source_commit differs")
    exported = _timestamp(payload["exported_at"], "exported_at")
    events = _index(bank.get("events"), "id", "bank event")
    require(set(events) == set(EVENTS), "Expected exactly the fourteen V3 events")
    sounds = {}
    for event_id, event in events.items():
        candidates = _index(event.get("candidates"), "id", "bank candidate")
        require(len(candidates) == 3 and {c.get("profile") for c in candidates.values()} == {"A", "B", "C"},
                "Bank requires ABC once per event")
        for candidate_id, candidate in candidates.items():
            profile = candidate["profile"]
            require(candidate_id == event_id + "_" + profile.lower() and candidate_id not in sounds,
                    "Invalid bank candidate route")
            require(candidate.get("version") == VERSION, "Bank candidate version differs")
            sounds[candidate_id] = candidate
    clips = _index(reels.get("clips"), "id", "reel clip")
    require(isinstance(payload["choices"], list), "choices must be an array")
    chosen = {}
    explicit = []
    for row_index, row in enumerate(payload["choices"]):
        require(isinstance(row, dict) and set(row) == ROW_FIELDS, "Choice row schema fields differ")
        event_id, clip_id = row["event_id"], row["clip_id"]
        require(isinstance(event_id, str) and event_id in events, "Unknown event_id")
        require(event_id not in chosen, "Duplicate event choice: " + event_id)
        require(isinstance(clip_id, str) and clip_id in clips, "Unknown clip_id")
        clip = clips[clip_id]
        segments = _index(clip.get("candidates"), "id", "reel candidate")
        require(any(event_id in c.get("event_ids", []) for c in segments.values()),
                "Event does not belong to clip")
        require(row["version"] == VERSION, "Choice row version differs")
        require(isinstance(row["note"], str), "Choice note must be text")
        require(_timestamp(row["updated_at"], "updated_at") <= exported,
                "Choice updated_at is later than export")
        versions = clip.get("versions", [{"id": "main", "video": clip.get("video"),
                                            "duration": clip.get("duration")}])
        version_index = _index(versions, "id", "video version")
        require(isinstance(row["video_version"], str) and row["video_version"] in version_index,
                "Unknown video_version")
        video = version_index[row["video_version"]]
        candidate_id = row["candidate_id"]
        evidence = {"input_row": row_index, "clip_id": clip_id,
                    "reel_candidate_id": candidate_id, "video_version": row["video_version"],
                    "video": video.get("video"), "movie_sha256": clip.get("movie_sha256"),
                    "trace_sha256": clip.get("trace_sha256"), "note": row["note"],
                    "updated_at": row["updated_at"]}
        if candidate_id in (None, "", "reject_all"):
            require(row["sound_candidate_id"] is None and row["profile"] is None
                    and row["start"] is None and row["end"] is None
                    and row["event_ids"] == [event_id] and row["source_ids"] == [],
                    "Abstention contains candidate metadata")
            result = _original(event_id, "rejected" if candidate_id == "reject_all" else "unknown")
            result["user_rejected_all"] = candidate_id == "reject_all"
            result["evidence"] = evidence
        else:
            require(isinstance(candidate_id, str) and candidate_id in segments, "Unknown candidate_id")
            segment = segments[candidate_id]
            profile = segment.get("profile")
            require(profile in ("original", "A", "B", "C") and row["profile"] == profile,
                    "Choice profile differs from reel")
            require(candidate_id == clip_id + "_" + profile.lower(), "Invalid reel candidate combination")
            event_ids = segment.get("event_ids")
            require(isinstance(event_ids, list) and len(event_ids) == len(set(event_ids))
                    and event_id in event_ids and set(event_ids) <= set(events), "Invalid reel event_ids")
            routes = segment.get("event_candidate_ids")
            require(isinstance(routes, dict) and set(routes) == set(event_ids), "Invalid reel event routes")
            for routed_event, routed_id in routes.items():
                require(routed_id == routed_event + "_" + profile.lower(), "Invalid reel sound route")
                if profile != "original":
                    require(routed_id in sounds, "Reel references nonexistent sound")
            require(row["event_ids"] == event_ids, "Choice event_ids differ from reel")
            require(row["sound_candidate_id"] == routes[event_id], "Choice sound_candidate_id differs")
            require(row["source_ids"] == segment.get("source_ids"), "Choice reel source_ids differ")
            start, end = _time(row["start"], "start"), _time(row["end"], "end")
            duration = _time(video.get("duration", clip.get("duration")), "video duration")
            require(0 <= start < end <= duration, "Choice time interval out of bounds")
            require(start == segment.get("start") and end == segment.get("end"),
                    "Choice time interval differs from reel")
            evidence.update(start=start, end=end, event_ids=list(event_ids),
                            reel_source_ids=list(row["source_ids"]))
            if profile == "original":
                result = _original(event_id, "explicit")
            else:
                sound = sounds[routes[event_id]]
                require(routes[event_id] in segment.get("audible_candidate_ids", []),
                        "Selected sound is not in recorded audible candidates")
                require(isinstance(sound.get("source_ids"), list) and sound["source_ids"]
                        and set(sound["source_ids"]) <= set(bank.get("sources", {}))
                        and set(sound["source_ids"]) <= set(row["source_ids"]),
                        "Selected sound sources are not supported by bank and reel")
                path = sound.get("path")
                require(path == "res://assets/audio/director_v3/" + routes[event_id] + ".wav",
                        "Invalid candidate playback path")
                local = (Path(root) / path.removeprefix("res://")).resolve()
                require(local.is_relative_to(Path(root).resolve()) and local.is_file(),
                        "Candidate audio is missing or outside repository")
                require(sound.get("variants") == [path], "Candidate variants differ from selected cue")
                require(re.fullmatch(r"[0-9a-f]{64}", sound.get("sha256", "")) is not None
                        and sha256(local.read_bytes()) == sound["sha256"], "Candidate audio SHA differs")
                result = {"event_id": event_id, "profile": profile, "candidate_id": routes[event_id],
                          "candidate_path": path, "candidate_sha256": sound["sha256"],
                          "runtime_mode": "candidate", "source_ids": list(sound["source_ids"]),
                          "selection_status": "explicit", "user_selected": True,
                          "derived_from": None}
            result["user_selected"] = True
            result["evidence"] = evidence
        chosen[event_id] = result
        explicit.append({"input_row": row_index, "event_id": event_id,
                         "candidate_id": row["sound_candidate_id"],
                         "reel_candidate_id": row["candidate_id"],
                         "profile": row["profile"], "selection_status": result["selection_status"]})
    # Original bomb launch/explosion is one existing weapon action. Propagate
    # only that exact recorded original pair, never ABC or unrelated ambience.
    for row in payload["choices"]:
        if (row["clip_id"] == "bomb_weapon" and row["profile"] == "original"
                and row["event_ids"] == ["shot_bomb", "bomb_explode"]):
            for paired in row["event_ids"]:
                if paired in chosen:
                    require(chosen[paired]["profile"] == "original", "Conflicting original compound bomb choice")
                    continue
                derived = _original(paired, "derived")
                derived["derived_from"] = {"event_id": row["event_id"],
                    "clip_id": "bomb_weapon", "reel_candidate_id": row["candidate_id"],
                    "rule": "recorded_original_bomb_is_one_compound_weapon_action"}
                derived["evidence"] = dict(chosen[row["event_id"]]["evidence"])
                chosen[paired] = derived
    normalized = [chosen.get(event_id, _original(event_id, "unknown")) for event_id in EVENTS]
    return {"schema_version": 1, "task": TASK, "candidate_version": VERSION,
            "source_commit": payload["source_commit"], "exported_at": payload["exported_at"],
            "selection_scope": "Per-event listening preferences; missing choices remain unapproved originals",
            "explicit_choices": explicit, "events": normalized,
            "event_profiles": {event["event_id"]: event["profile"] for event in normalized}}


def _original(event_id, status):
    return {"event_id": event_id, "profile": "original", "candidate_id": event_id + "_original",
            "candidate_path": None, "candidate_sha256": None, "runtime_mode": "original",
            "source_ids": [], "selection_status": status, "user_selected": False,
            "derived_from": None, "evidence": None}


def import_choices(input_path, reels_path, manifest_path, output_dir, *, root=ROOT, raw_name=None):
    """Validate everything before saving the original bytes and derived mapping."""
    input_path, reels_path, manifest_path, output_dir = map(Path, (input_path, reels_path, manifest_path, output_dir))
    raw, reel_bytes, manifest_bytes = input_path.read_bytes(), reels_path.read_bytes(), manifest_path.read_bytes()
    payload = read_json(raw)
    result = normalize(payload, read_json(reel_bytes), read_json(manifest_bytes), root=root)
    raw_name = raw_name or "user-" + _timestamp(payload["exported_at"], "exported_at").strftime("%Y%m%d") + ".json"
    require(Path(raw_name).name == raw_name and raw_name.startswith("user-") and raw_name.endswith(".json"),
            "Unsafe raw evidence filename")
    reel_name = "reels-" + raw_name
    result["provenance"] = {
        "input": {"path": raw_name, "sha256": sha256(raw), "choice_rows": len(payload["choices"])},
        "reels": {"path": reel_name, "sha256": sha256(reel_bytes), "imported_from": str(reels_path)},
        "candidate_manifest": {"path": _reference_path(manifest_path, root), "sha256": sha256(manifest_bytes)},
        "importer_sha256": sha256(Path(__file__).read_bytes()),
    }
    encoded = (json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
    # Retained user evidence is immutable. Re-importing identical bytes is safe.
    for name, data in ((raw_name, raw), (reel_name, reel_bytes)):
        destination = output_dir / name
        require(not destination.exists() or destination.read_bytes() == data, "Existing evidence differs: " + name)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / raw_name).write_bytes(raw)
    (output_dir / reel_name).write_bytes(reel_bytes)
    (output_dir / "selected.json").write_bytes(encoded)
    return result


def _reference_path(path, root):
    resolved, base = Path(path).resolve(), Path(root).resolve()
    return resolved.relative_to(base).as_posix() if resolved.is_relative_to(base) else str(path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--reels", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=ROOT / "assets/audio/director_v3/manifest.json")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "config/audio_director/selected")
    args = parser.parse_args(argv)
    try:
        result = import_choices(args.input, args.reels, args.manifest, args.output_dir)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, "Choice import rejected: " + str(error) + "\n")
    print(json.dumps({"events": len(result["events"]), "event_profiles": result["event_profiles"],
                      "input_sha256": result["provenance"]["input"]["sha256"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
