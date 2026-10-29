"""Read-only analysis of formal A/B WAVs, event variants and capture coverage.

No browser/engine. Writes only the requested analysis JSON; raw reports/WAVs stay
untouched. Correlation over an unrelated mixed window cannot prove a cue played.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from math import gcd
from pathlib import Path
import subprocess

import numpy as np
import scipy
from scipy.io import wavfile
from scipy.signal import correlate, resample_poly

ROOT = Path(__file__).resolve().parents[2]
BASE = "1b29932c5333a9dad50759afc635762163ed79f5"
CASES = ["original", "bus_only", "pause_only", "ambience_off"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def reference(path: Path) -> dict:
    return {"path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
        "bytes": path.stat().st_size, "sha256": sha(path)}


def read_wav(path: Path) -> tuple[int, np.ndarray]:
    rate, raw = wavfile.read(path)
    if raw.dtype.kind == "i":
        audio = raw.astype(np.float64) / (2 ** (raw.dtype.itemsize * 8 - 1))
    elif raw.dtype.kind == "u":
        middle = 2 ** (raw.dtype.itemsize * 8 - 1)
        audio = (raw.astype(np.float64) - middle) / middle
    else:
        audio = raw.astype(np.float64)
    if audio.ndim == 2: audio = audio.mean(axis=1)
    return int(rate), audio


def matched_filter(signal: np.ndarray, template: np.ndarray, rate: int) -> dict:
    """Pearson correlation for every complete reference-sized moving window."""
    centered = template - template.mean()
    template_energy = float(centered @ centered)
    size = len(centered)
    if len(signal) < size or template_energy == 0:
        return {"status": "insufficient_complete_window"}
    dot = correlate(signal, centered, mode="valid", method="fft")
    sums = np.r_[0.0, np.cumsum(signal)]
    squares = np.r_[0.0, np.cumsum(signal * signal)]
    window_sum = sums[size:] - sums[:-size]
    energy = np.maximum(0.0, squares[size:] - squares[:-size] - window_sum * window_sum / size)
    denominator = np.sqrt(energy * template_energy)
    rho = np.divide(dot, denominator, out=np.zeros_like(dot), where=denominator > 1e-12)
    positive = int(np.argmax(rho))
    absolute = int(np.argmax(np.abs(rho)))
    def fit(index: int) -> dict:
        return {"offset_frames": index, "offset_seconds": index / rate,
            "rho": float(rho[index]), "least_squares_gain": float(dot[index] / template_energy),
            "explained_window_variance_fraction": float(rho[index] ** 2),
            "window_rms_centered": float(np.sqrt(energy[index] / size))}
    return {"status": "scanned_complete_template", "template_frames": size,
        "complete_window_count": len(dot), "best_positive_gain_match": fit(positive),
        "best_absolute_match": fit(absolute)}


def self_test() -> None:
    rng = np.random.default_rng(4214)
    template = rng.normal(size=1400)
    target = rng.normal(scale=0.001, size=9000)
    target[3100:4500] += template * .37
    fit = matched_filter(target, template, 44100)["best_positive_gain_match"]
    assert fit["offset_frames"] == 3100 and fit["rho"] > .999
    assert abs(fit["least_squares_gain"] - .37) < .001
    reverse = matched_filter(target, template[::-1], 44100)["best_absolute_match"]
    assert abs(reverse["rho"]) < .2


def template_path(kind: str, variant: int) -> Path:
    family = "feel_audio_v1" if kind == "jump" else "weapon_audio_v2"
    return ROOT / f"assets/player_presentation_01/{family}/{kind}_{variant}.wav"


def latest_action_event(action: dict, menu: dict, signal: str) -> dict:
    controller = action["before"]["state"]["action_observation"]["controller_id"]
    events = menu["after"]["state"]["action_observation"]["events"]
    return next(event for event in events if event["controller_id"] == controller and event["signal"] == signal)


def accepted_audio_event(action: dict, menu: dict, key: str, kind: str, tick: int) -> tuple[dict, str]:
    for observation, label in [(action["after"], "actions.after"), (menu["after"], "menu.after")]:
        matches = [row for row in observation["state"][key] if row["id"] == kind and row["tick"] == tick]
        if matches: return matches[0], label
    raise ValueError(f"No accepted audio event for {kind} at physical frame{tick}")


def analyze(folder: Path, output: Path, run_self_test: bool) -> dict:
    if run_self_test: self_test()
    aggregate_path = folder / "report.json"
    aggregate = json.loads(aggregate_path.read_bytes())
    watched = [aggregate_path, *[folder / case / "report.json" for case in CASES],
        *[folder / case / f"{scene}-actions.wav" for case in CASES for scene in ["home", "plains"]]]
    before_hashes = {str(path): sha(path) for path in watched}
    sources = {}
    rows = []
    final_actions = []
    for case in CASES:
        data = json.loads((folder / case / "report.json").read_bytes())
        for scene in ["home", "plains"]:
            action = next(row for row in data["results"] if row["scene"] == scene and row["phase"] == "native_touch_jump_shoot")
            menu = next(row for row in data["results"] if row["scene"] == scene and row["phase"] == "menu")
            wave_path = folder / case / f"{scene}-actions.wav"
            assert sha(wave_path) == action["pcm"]["wav_sha256"], wave_path
            rate, audio = read_wav(wave_path)
            pcm = action["pcm"]
            assert len(audio) == pcm["frames"] and rate == pcm["sample_rate"]
            end_frame = pcm["end_audio_frame"]
            begin_frame = end_frame - pcm["frames"]
            begin_seconds, end_seconds = begin_frame / rate, end_frame / rate
            row = {"case": case, "scene": scene, "wave": reference(wave_path),
                "pcm_frames": len(audio), "sample_rate": rate, "actual_recording_seconds": len(audio) / rate,
                "reported_begin_audio_frame": pcm.get("begin_audio_frame"),
                "derived_begin_audio_frame": begin_frame, "end_audio_frame": end_frame,
                "derived_audio_window_seconds": [begin_seconds, end_seconds],
                "window_derivation": "Copied worklet end_audio_frame=start_audio_frame+length; formal runner requested missing begin_audio_frame. Raw metadata unchanged.",
                "after_routes_are_post_ended_not_play_time": True,
                "graph_cycles_before_after": [action["before"]["graph"]["feedback_cycles"], action["after"]["graph"]["feedback_cycles"]],
                "action_after_counters": action["after"]["state"]["action_observation"],
                "menu_after_counters": menu["after"]["state"]["action_observation"], "matches": []}
            for kind, signal, key in [("jump", "jumped", "motion_events"), ("pulse", "shot_fired", "weapon_events")]:
                signal_event = latest_action_event(action, menu, signal)
                event, observed_at = accepted_audio_event(action, menu, key, kind, signal_event["physics_frame"])
                variant = int(event["variant"])
                scores = []
                expected_length = None
                for index in range(3):
                    path = template_path(kind, index)
                    if str(path) not in sources:
                        registered_blob = subprocess.check_output(["git", "rev-parse", f"{BASE}:{path.relative_to(ROOT)}"], cwd=ROOT, text=True).strip()
                        workspace_blob = subprocess.check_output(["git", "hash-object", str(path)], cwd=ROOT, text=True).strip()
                        assert registered_blob == workspace_blob, f"Source differs from main1b:{path}"
                        sources[str(path)] = {**reference(path), "matches_main1b_git_blob": True}
                    source_rate, source = read_wav(path)
                    divisor = gcd(rate, source_rate)
                    resampled = resample_poly(source, rate // divisor, source_rate // divisor)
                    if index == variant: expected_length = len(resampled)
                    scores.append({"variant": index, "source": str(path.relative_to(ROOT)),
                        "expected_variant": index == variant, "source_sample_rate": source_rate,
                        "source_frames": len(source), "full_template": matched_filter(audio, resampled, rate)})
                    if index == variant:
                        reverse = matched_filter(audio, resampled[::-1], rate)
                native = [entry for entry in action["after"]["audio"]["native_starts"]
                    if entry["sequence"] > action["before"]["audio"]["native_starts_total"] and entry.get("buffer")
                    and entry["buffer"]["frames"] == expected_length and entry["buffer"]["sample_rate"] == rate]
                coverage = []
                for entry in native:
                    start = entry["audio_seconds"]
                    duration = entry["buffer"]["duration_seconds"] / entry["playback_rate"]
                    overlap = max(0.0, min(end_seconds, start + duration) - max(begin_seconds, start))
                    coverage.append({"native_sequence": entry["sequence"], "native_source_id": entry["source_id"],
                        "audio_seconds": start, "native_buffer_duration": duration,
                        "onset_after_recording_end_seconds": start - end_seconds,
                        "overlap_seconds": overlap, "source_coverage_fraction": overlap / duration,
                        "signature_is_not_unique_asset_identity": True})
                expected = scores[variant]["full_template"]
                row["matches"].append({"kind": kind, "original_signal": signal_event,
                    "accepted_audio_event": event, "accepted_event_observed_at": observed_at,
                    "expected_source": str(template_path(kind, variant).relative_to(ROOT)),
                    "reference_variants": scores, "reversed_expected_template_control": reverse,
                    "native_candidate_timing": coverage,
                    "full_reference_in_recording": any(item["source_coverage_fraction"] > .99 for item in coverage),
                    "conclusion": "not_confirmed_in_this_WAV; native timing outside or incomplete capture, and global mixed-window correlation is not asset identification",
                    "best_expected_positive_rho": expected["best_positive_gain_match"]["rho"],
                    "best_expected_absolute_rho": expected["best_absolute_match"]["rho"]})
            rows.append(row)
        final = next(row for row in data["results"] if row["scene"] == "plains" and row["phase"] == "menu")["after"]["state"]["action_observation"]
        final_actions.append({"case": case, "jumped_total": final["jumped_total"], "shot_fired_total": final["shot_fired_total"], "by_controller": final["by_controller"]})
    watched_sources = [ROOT / "tools/mobile_web_perf/run_formal_audio_ab.py",
        ROOT / "build/mobile_web_perf_01/formal-main-02/minimal_pcm_worklet.js",
        ROOT / "build/mobile_web_perf_01/formal-main-02/build-receipt.json"]
    result = {"status": "analysis_completed_with_action_capture_limitation", "source_main": BASE,
        "scope": "Read-only formal demo A/B evidence. Actual accepted actions confirmed; these WAV windows do not establish jump/shot output restoration. No browser/Godot started.",
        "input_reports_and_WAVs": [reference(path) for path in watched],
        "producer_sources_read": [reference(path) for path in watched_sources if path.exists()],
        "reference_audio_sources": list(sources.values()), "rows": rows,
        "final_original_signal_counts": final_actions,
        "frame_observations": [{key: entry[key] for key in ["case", "scene", "phase"]} |
            {"frames": entry["summary"]["frames"], "fps": entry["summary"]["fps"],
             "p50_ms": entry["summary"]["p50_ms"], "p95_ms": entry["summary"]["p95_ms"]} for entry in aggregate["cases"]],
        "findings": [
            "Allfour cases final original signal counters show Home+Plains jumped2/shot_fired2, each controller1/1. Some immediate action snapshots are stale at1Hz; use later recorded originals without rewriting them.",
            "bus_only raw graph shows no cycles; original/pause_only/ambience_off retain the bad sample graph. Post-ended source_routes false reflect disconnect/GC/gain lifecycle and cannot determine play-time connectivity.",
            "Formal runner requests4seconds but copied minimal worklet caps recording at2seconds. It computes coordinates and performs slow browser roundtrips after arming capture; mostnative action sources start after the captured WAV ends.",
            "Metadata field mismatch: worklet emits start_audio_frame, formal runner reads begin_audio_frame, producingnull. Derive begin=end-frames only after verifying the exact copied worklet; leave raw metadata intact.",
            "bus_only Home native jump/pulse start after recording end; Plains jump overlaps only about9ms at recording tail, pulse starts later. Full-length reference matches cannot confirm these action sounds.",
            "Maximum normalized correlations in mixed windows are exploratory and must not override contradictory native timestamps or wrong-variant controls. Resample_poly is not a validated identical Godot importer resampler.",
            "Cloud SwiftShader frame measurements have cold-start and order variation. User reports actions nearly smooth and audio discontinuity; these samples do not establish physical-phone GPU bottleneck or that an audio fix improves visuals."
        ],
        "bounded_followup": [
            "Precompute all real touch coordinates and await engine/audio readiness before arming recording.",
            "Use separate fixed2s recordings for accepted jump and pulse, preferably armed with pre-roll and triggered by the matching native source start (record sourceID/buffer fingerprint) so slow command delivery cannot consume the window before the action.",
            "Record correct start_audio_frame/end_audio_frame, expected action event/variant, native start audioTime, and assert the entire source falls within the actual captured interval before declaring an audio positive.",
            "Capture graph snapshot synchronously in the bounded native-start action observer, before finished/disconnect; report zero-gain meter branches separately. Keep these extra audio observations separate from timing-performance samples.",
            "Re-run only the missing bounded audio positives for bus_only and matched original controls; preserve this incomplete recording attempt. Do not repair a baseline bus graph or modify engine bytes."
        ],
        "method": {"numpy_version": np.__version__, "scipy_version": scipy.__version__,
            "reference_resampling": "scipy.signal.resample_poly, rational sample-rate ratio",
            "matching": "Normalized centered full-template cross-correlation across all valid offsets of stereo-mean WAV; fitted gain; allthree actual variants and reversed expected control",
            "self_test": "passed_known_offset_gain_and_reversed_control" if run_self_test else "not_run",
            "limitations": "Mixed PCM, channel cancellation, importer resampler differences, search bias and incomplete source windows prevent absence/presence claims from a low global correlation alone."}}
    result["raw_inputs_unchanged_during_analysis"] = all(sha(Path(path)) == value for path, value in before_hashes.items())
    assert result["raw_inputs_unchanged_during_analysis"]
    if output.exists():
        previous = json.loads(output.read_bytes())
        for key in ["analysis_attempts", "formal_action_02"]:
            if key in previous: result[key] = previous[key]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


def supplement_action_capture(folder: Path, output: Path, run_self_test: bool) -> dict:
    """Append a separately identified, clock-checked action-only recording run."""
    if run_self_test: self_test()
    existing = json.loads(output.read_bytes())
    paths = [folder / "report.json", *[folder / case / "report.json" for case in CASES],
        *[folder / case / f"{scene}-actions.wav" for case in CASES for scene in ["home", "plains"]]]
    initial_hashes = {str(path): sha(path) for path in paths}
    templates = {}
    for kind in ["jump", "pulse"]:
        for variant in range(3):
            path = template_path(kind, variant)
            rate, signal = read_wav(path)
            templates[(kind, variant)] = (path, rate, signal)
    rows = []
    for case in CASES:
        report = json.loads((folder / case / "report.json").read_bytes())
        for action in report["results"]:
            scene = action["scene"]
            pcm = action["pcm"]
            path = folder / case / f"{scene}-actions.wav"
            assert sha(path) == pcm["wav_sha256"]
            rate, audio = read_wav(path)
            assert len(audio) == pcm["frames"] == rate * 8, "Supplement must actually capture8seconds"
            assert pcm["begin_audio_frame"] is not None
            assert pcm["end_audio_frame"] - pcm["begin_audio_frame"] == pcm["frames"]
            begin = pcm["begin_audio_frame"] / rate
            end = pcm["end_audio_frame"] / rate
            before, after = action["before"], action["after"]
            controller = before["state"]["action_observation"]["controller_id"]
            row = {"case": case, "scene": scene, "wave": reference(path),
                "frames": len(audio), "sample_rate": rate, "recording_seconds": len(audio) / rate,
                "audio_window_seconds": [begin, end],
                "explicit_start_end_frame_guard_passed": True,
                "original_action_counters": after["state"]["action_observation"],
                "cycles_before_after": [before["graph"]["feedback_cycles"], after["graph"]["feedback_cycles"]],
                "post_ended_routes_not_used_for_presence": True, "matches": []}
            for kind, signal_name, event_key in [("jump", "jumped", "motion_events"), ("pulse", "shot_fired", "weapon_events")]:
                signal_events = [event for event in after["state"]["action_observation"]["events"]
                    if event["controller_id"] == controller and event["signal"] == signal_name]
                if not signal_events:
                    row["matches"].append({"kind": kind, "original_signal": None,
                        "assessment": "not_triggered_no_original_gameplay_signal",
                        "presence_supported_in_mixed_PCM": False,
                        "limit": "Not a valid cue-absence control: no accepted action/audio event was recorded. Raw counts unchanged."})
                    continue
                signal_event = signal_events[0]
                accepted = next(event for event in after["state"][event_key]
                    if event["id"] == kind and event["tick"] == signal_event["physics_frame"])
                variant = accepted["variant"]
                expected_path, source_rate, source = templates[(kind, variant)]
                divisor = gcd(rate, source_rate)
                expected = resample_poly(source, rate // divisor, source_rate // divisor)
                native = [event for event in after["audio"]["native_starts"]
                    if event["sequence"] > before["audio"]["native_starts_total"] and event.get("buffer")
                    and event["buffer"]["frames"] == len(expected) and event["buffer"]["sample_rate"] == rate]
                assert len(native) == 1, "Expected exactly one action-length native buffer start in this bounded action fixture"
                start = native[0]
                native_time = start["audio_seconds"]
                source_end = native_time + start["buffer"]["duration_seconds"] / start["playback_rate"]
                coverage = begin <= native_time and source_end <= end
                assert coverage, f"Action source not fully covered: {case}/{scene}/{kind}"
                expected_offset = round((native_time - begin) * rate)
                search_begin = max(0, expected_offset - 256)
                search_end = min(len(audio), expected_offset + len(expected) + 256)
                scores = []
                for index in range(3):
                    other_path, other_rate, other = templates[(kind, index)]
                    divisor = gcd(rate, other_rate)
                    resampled = resample_poly(other, rate // divisor, other_rate // divisor)
                    global_match = matched_filter(audio, resampled, rate)
                    anchored = matched_filter(audio[search_begin:search_end], resampled, rate)
                    fit = dict(anchored["best_positive_gain_match"])
                    fit["offset_frames"] += search_begin
                    fit["offset_seconds"] = fit["offset_frames"] / rate
                    fit["native_clock_difference_frames"] = fit["offset_frames"] - expected_offset
                    scores.append({"variant": index, "source": str(other_path.relative_to(ROOT)),
                        "expected_variant": index == variant, "global_match": global_match,
                        "native_clock_anchored_fit": fit})
                correct = scores[variant]["native_clock_anchored_fit"]
                wrong_max = max(item["native_clock_anchored_fit"]["rho"] for item in scores if not item["expected_variant"])
                reverse = matched_filter(audio[search_begin:search_end], expected[::-1], rate)
                strong = correct["rho"] >= .95 and abs(correct["native_clock_difference_frames"]) <= 128 and correct["least_squares_gain"] > 0
                supported = correct["rho"] >= .65 and correct["rho"] - wrong_max >= .1 and abs(correct["native_clock_difference_frames"]) <= 128 and correct["least_squares_gain"] > 0
                assessment = "strong_clock_aligned_whole_waveform_match" if strong else (
                    "presence_supported_by_correct_variant_clock_gain_despite_mixture" if supported else "not_identified_by_this_match")
                row["matches"].append({"kind": kind, "original_signal": signal_event,
                    "accepted_audio_event": accepted, "reference": reference(expected_path),
                    "native_start": start, "native_signature_not_unique_asset_identity": True,
                    "entire_native_source_inside_recording": coverage,
                    "native_onset_seconds_relative_to_capture": native_time - begin,
                    "reference_variants": scores, "reversed_expected_control": reverse,
                    "expected_rho": correct["rho"], "wrong_variant_max_rho": wrong_max,
                    "correct_variant_margin": correct["rho"] - wrong_max,
                    "native_clock_difference_frames": correct["native_clock_difference_frames"],
                    "fitted_gain": correct["least_squares_gain"], "assessment": assessment,
                    "presence_supported_in_mixed_PCM": strong or supported})
            rows.append(row)
    result = {"status": "completed_clock_checked_action_supplement", "inputs": [reference(path) for path in paths],
        "analyzer_source": reference(Path(__file__).resolve()),
        "scope": "New separately recorded8second actual destination WAVs. Original2second failed coverage remains above in this JSON. No browser/engine run by analyzer.",
        "rows": rows, "raw_inputs_unchanged": all(sha(Path(path)) == value for path, value in initial_hashes.items()),
        "summary": {
            "all8_WAVs_actually8seconds": all(row["recording_seconds"] == 8 for row in rows),
            "original_gameplay_actions_recorded": sum(match["original_signal"] is not None for row in rows for match in row["matches"]),
            "all_recorded_native_action_sources_fully_covered": all(match.get("entire_native_source_inside_recording", True) for row in rows for match in row["matches"]),
            "missing_original_gameplay_actions": [{"case": row["case"], "scene": row["scene"], "kind": match["kind"]} for row in rows for match in row["matches"] if match["original_signal"] is None],
            "bus_only_action_presence_supported": all(match["presence_supported_in_mixed_PCM"] for row in rows if row["case"] == "bus_only" for match in row["matches"]),
            "other_cases_supported_matches": [{"case": row["case"], "scene": row["scene"], "kind": match["kind"], "rho": match["expected_rho"]} for row in rows if row["case"] != "bus_only" for match in row["matches"] if match["presence_supported_in_mixed_PCM"]],
            "limits": "Bus-only confirms these actual Home/Plains jump/pulse cues reached mixed output. Does not establish complete BGM/ambience continuity, all cues, listening approval, physical-device behavior or improved graphics/FPS."
        },
        "heuristics_not_an_acceptance_gate": "Clock tolerance128frames; strong correlation>=.95, or mixed presence>=.65 with>.1correct-variant margin and positive fitted gain. Report numeric evidence and controls; these are analytic labels, not user acceptance.",
        "self_test": "passed_known_offset_gain_and_reversed_control" if run_self_test else "not_run"}
    assert result["raw_inputs_unchanged"]
    existing["formal_action_02"] = result
    output.write_text(json.dumps(existing, ensure_ascii=False, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "build/mobile_web_perf_01/formal-ab-01")
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/mobile_web_perf_01/formal-audio-analysis.json")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--supplement-action", action="store_true", help="Append a clock-checked8second action-only follow-up while preserving initial analysis")
    args = parser.parse_args()
    if args.supplement_action:
        result = supplement_action_capture(args.input.resolve(), args.output.resolve(), args.self_test)
        print(json.dumps(result["summary"], ensure_ascii=False))
        for row in result["rows"]:
            for match in row["matches"]:
                print(json.dumps({"case": row["case"], "scene": row["scene"], "kind": match["kind"],
                    "rho": match.get("expected_rho"), "gain": match.get("fitted_gain"),
                    "clock_delta_frames": match.get("native_clock_difference_frames"), "assessment": match["assessment"]}))
        raise SystemExit(0)
    result = analyze(args.input.resolve(), args.output.resolve(), args.self_test)
    print(json.dumps({"status": result["status"], "output": str(args.output), "WAVs": len(result["rows"]),
        "raw_unchanged": result["raw_inputs_unchanged_during_analysis"]}))
    for row in result["rows"]:
        for match in row["matches"]:
            print(json.dumps({"case": row["case"], "scene": row["scene"], "source": match["expected_source"],
                "rho": match["best_expected_positive_rho"], "full_coverage": match["full_reference_in_recording"],
                "native_timing": match["native_candidate_timing"]}))
