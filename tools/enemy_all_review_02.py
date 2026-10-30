#!/usr/bin/env python3
"""Record existing enemy chains with genuine Godot input, AI and stereo audio.

Source must be quiescent for a recording. Incomplete gameplay is retained as
reviewable MP4 plus honest coverage gaps; engine/source failures remain failures.
"""
import argparse
from array import array
import hashlib
import json
import math
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import time
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import harness


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def original_audio_statistics(avi, folder):
    """Measure the original MovieMaker PCM, never a replacement soundtrack."""
    original_probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(avi)], timeout=30))
    (folder / "original_avi_ffprobe.json").write_text(json.dumps(original_probe, indent=2) + "\n")
    wav = folder / "original_engine_pcm.wav"
    with (folder / "extract_pcm.log").open("wb") as log:
        subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-map", "0:a:0", "-c:a", "pcm_s16le", str(wav)], check=True, stdout=subprocess.DEVNULL, stderr=log, timeout=90)
    total_samples = total_square = active_samples = peak = 0
    second_rows = []
    with wave.open(str(wav), "rb") as sound:
        channels, width, rate, count = sound.getnchannels(), sound.getsampwidth(), sound.getframerate(), sound.getnframes()
        if width != 2:
            raise RuntimeError("Expected original 16-bit engine PCM")
        second = 0
        while chunk := sound.readframes(rate):
            samples = array("h", chunk)
            if sys.byteorder != "little":
                samples.byteswap()
            local_peak = max((abs(sample) for sample in samples), default=0)
            square = sum(sample * sample for sample in samples)
            active = sum(sample != 0 for sample in samples)
            second_rows.append({"second": second, "samples": len(samples), "peak_s16": local_peak, "rms_normalized": math.sqrt(square / max(1, len(samples))) / 32768, "nonzero_samples": active})
            total_samples += len(samples)
            total_square += square
            active_samples += active
            peak = max(peak, local_peak)
            second += 1
    statistics = {"source": "original Godot MovieMaker AVI audio, losslessly extracted before AAC encoding", "sample_rate": rate, "channels": channels, "bits_per_sample": width * 8, "frames": count, "duration_seconds": count / rate, "samples": total_samples, "peak_s16": peak, "peak_normalized": peak / 32768, "rms_normalized": math.sqrt(total_square / max(1, total_samples)) / 32768, "nonzero_samples": active_samples, "nonzero_sample_ratio": active_samples / max(1, total_samples), "seconds_containing_nonzero_pcm": sum(row["nonzero_samples"] > 0 for row in second_rows), "pcm_sha256": digest(wav), "per_second": second_rows, "listening_acceptance": False, "interpretation": "Nonzero signal proves captured engine sound exists; timbre, loudness and mix approval require listening."}
    (folder / "original_engine_pcm_statistics.json").write_text(json.dumps(statistics, indent=2) + "\n")
    if peak <= 0 or active_samples <= 0:
        raise RuntimeError("Original engine PCM is silent; do not certify captured audio")
    return statistics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--group", choices=("plains", "forest", "prototypes", "boss", "route_plains", "route_forest", "formal_plains", "formal_forest", "formal_boss", "all"), default="plains", help="all combines ordinary species and development prototypes; Boss fights, original-stage routes and disclosed initial formal review stands use separate drivers.")
    parser.add_argument("--chains", choices=("primary", "all"), default="primary")
    parser.add_argument("--species", default="", help="Exact roster id; Boss group also accepts a comma-separated explicit subset. A subset is not whole-roster proof.")
    parser.add_argument("--seed", default="enemy-all-review-02", help="Provenance label, not an injected production RNG seed.")
    parser.add_argument("--require-remains", action="store_true", help="Apply only to species whose original terminal policy requires a persistent corpse.")
    parser.add_argument("--retain-avi", action="store_true", help="Retain uncompressed MovieMaker intermediate after verifying MP4 and SHA-256.")
    parser.add_argument("--seconds", type=int, default=45, help="Original formal-route gameplay bound, 15–120 seconds; not a campaign completion claim.")
    args = parser.parse_args()
    if "," in args.species and args.group != "boss":
        parser.error("Comma-separated subsets are supported only by the Boss driver")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    source = harness.git_metadata()
    formal = args.group.startswith("formal_")
    route = args.group.startswith("route_") or formal
    driver = "tools/enemy_all_review_02_formal_boss_capture.gd" if args.group == "formal_boss" else ("tools/enemy_all_review_02_formal_capture.gd" if formal else ("tools/enemy_all_review_02_route_capture.gd" if route else ("tools/enemy_all_review_02_boss_capture.gd" if args.group == "boss" else "tools/enemy_all_review_02_capture.gd")))
    report = {
        "task": "ENEMY-ALL-02", "group": args.group, "chains": args.chains,
        "species": args.species or None, "seed_label": args.seed, "status": "running",
        "source": source, "driver_sha256": digest(ROOT / driver),
        "scope": "Genuine Godot MovieMaker; explicit initial fixtures, real AI, InputRouter, projectiles, enemy and player FrameDamagePolicy. No natural-campaign claim.",
        "user_acceptance": "pending", "device_acceptance": "unverified", "listening_acceptance": False,
    }
    env = os.environ.copy()
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    display = None
    display_log = None
    started = time.monotonic()
    exit_code = 0
    try:
        if not env.get("DISPLAY"):
            candidate = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))) / "xvfb/usr/bin/Xvfb"
            binary = shutil.which("Xvfb") or (str(candidate) if candidate.is_file() else None)
            if not binary:
                raise RuntimeError("Xvfb is required for genuine Godot pixels")
            display_log = (folder / "display.log").open("wb")
            display = subprocess.Popen([binary, "-displayfd", "1", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"], stdout=subprocess.PIPE, stderr=display_log)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout, selectors.EVENT_READ)
                if not selector.select(30):
                    raise RuntimeError("Xvfb startup timeout")
                number = display.stdout.readline().decode().strip()
            if not number.isdigit():
                raise RuntimeError("Invalid Xvfb display response")
            env["DISPLAY"] = ":" + number
        avi, movie, trace_path = (folder / name for name in ("capture.avi", "review.mp4", "trace.json"))
        command = ["bash", "tools/godot.sh", "--path", ".", "--rendering-method", "gl_compatibility", "--write-movie", str(avi), "--fixed-fps", "60", "--script", driver, "--", "--trace=" + str(trace_path), "--group=" + args.group, "--chains=" + args.chains, "--seed=" + args.seed]
        if args.species:
            command.append("--species=" + args.species)
        if args.require_remains:
            command.append("--require-remains")
        if route:
            command.append("--seconds=" + str(args.seconds))
        report["command"] = command
        # Each chapter has a roster-dependent original bound. This is a new
        # recording budget, not a widened integration-test or lease timeout.
        count = {"plains": 15 if args.chains == "all" else 7, "forest": 7, "prototypes": 2, "boss": 9, "route_plains": 1, "route_forest": 1, "formal_plains": 1, "formal_forest": 1, "formal_boss": 1, "all": 24 if args.chains == "all" else 16}[args.group]
        if args.species:
            count = len(set(args.species.split(","))) if args.group == "boss" else (3 if args.species == "plains_root_bell" and args.chains == "all" else (2 if args.group in ("plains", "all") and args.species.startswith(("patrol_", "plains_")) and args.chains == "all" else 1))
        budget = max(600, min(120, args.seconds) * 8) if route else max(180, count * (240 if args.group == "boss" else 100))
        result = harness.run_check({"argv": command, "timeout_seconds": budget, "success_pattern": r"^ENEMY ALL REVIEW 02: complete; cases=\d+; frames=\d+; coverage_gaps=\d+$"}, folder / "capture.log", ROOT, env)
        report["execution"] = result
        # Preserve/encode a completed gameplay chapter even if one species
        # failed an action predicate. An engine failure is never reclassified.
        if result["status"] != "passed":
            raise RuntimeError("Actual Godot recording failed: " + result["status"])
        trace = json.loads(trace_path.read_text())
        if not trace.get("complete") or trace.get("failures") or len(trace.get("cases", [])) != count:
            raise RuntimeError("Incomplete roster, teardown or trace")
        frames = trace["frames"]
        if not frames or [row["frame"] for row in frames] != list(range(1, len(frames) + 1)):
            raise RuntimeError("Frame trace is not continuous")
        for case in trace["cases"]:
            if not case["fixture"]["production_AI_enabled"]:
                raise RuntimeError("AI disabled for " + case["id"])
            if any(event["amount"] >= 0 for event in case["events"]):
                raise RuntimeError("Non-damage event mislabelled as actual hit")
        report["original_engine_audio"] = original_audio_statistics(avi, folder)
        with (folder / "encode.log").open("wb") as encode_log:
            subprocess.run(["ffmpeg", "-y", "-i", str(avi), "-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", str(movie)], check=True, stdout=subprocess.DEVNULL, stderr=encode_log, timeout=max(90, count * 25))
        media = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)], timeout=30))
        video = next(stream for stream in media["streams"] if stream["codec_type"] == "video")
        sound = next(stream for stream in media["streams"] if stream["codec_type"] == "audio")
        trace_seconds = len(frames) / 60
        # Only inter-case spawn/free await frames are outside the active trace;
        # every active case has an uncut, frame-indexed run in the raw movie.
        duration = float(media["format"]["duration"])
        if not (video["width"] == 1280 and video["height"] == 720 and video["avg_frame_rate"] == "60/1" and sound["sample_rate"] == "48000" and sound["channels"] == 2 and trace_seconds <= duration <= trace_seconds + count * .15 + 1):
            raise RuntimeError("Normal-speed continuous pixels/stereo media mismatch")
        chapter_rows = []
        for case in trace["cases"]:
            chapter_rows.append({key: case[key] for key in ("case", "id", "chain", "renderer", "start_frame", "end_frame", "start_seconds", "end_seconds", "post_death_observation_frames", "coverage", "coverage_gaps", "terminal_policy_observation")})
        (folder / "chapters.json").write_text(json.dumps(chapter_rows, indent=2, ensure_ascii=False) + "\n")
        # Engine process-frame timestamps include the original inter-case
        # spawn/free await intervals. No frame interpolation, speed-up or cuts.
        chapter_text = ["# ENEMY-ALL-02 actual capture\n", "Original formal stage encounter with one disclosed initial player review stand; not a natural route. Human visual approval pending.\n" if formal else ("Original formal stage route. Human visual approval pending.\n" if route else "Initial arena fixtures; normal-speed AI/InputRouter/projectiles. Human visual approval pending.\n"), "| Case | Species / chain | Movie process-frame seconds | Accepted enemy hits | Coverage gaps |", "| --- | --- | --- | --- | --- |"]
        for case in trace["cases"]:
            chapter_text.append(f"| {case['case'] + 1} | {case['id']} / {case['chain']} | {case['start_seconds']:.2f}–{case['end_seconds']:.2f} | {len(case['events'])} | {', '.join(case['coverage_gaps']) or 'none recorded'} |")
        (folder / "chapters.md").write_text("\n".join(chapter_text) + "\n")
        report.update(media=media, trace_frame_count=len(frames), chapters=chapter_rows, coverage_gap_count=trace["coverage_gap_count"], mp4_sha256=digest(movie), avi_sha256=digest(avi), trace_sha256=digest(trace_path), raw_avi_retained=args.retain_avi)
        report["source_stable"] = source == harness.git_metadata()
        if not report["source_stable"]:
            raise RuntimeError("Source changed during recording; preserve this failed evidence")
        report["status"] = "recorded_with_coverage_gaps" if trace["coverage_gap_count"] else "recorded_complete_coverage"
        if not args.retain_avi:
            avi.unlink()
        print(f"ENEMY ALL REVIEW 02 MOVIE: {count} actual cases; {duration:.2f}s; {trace['coverage_gap_count']} coverage gaps; {movie}")
    except BaseException as exc:
        report.update(status="failed", error=str(exc))
        exit_code = 1
        print(str(exc), file=sys.stderr)
    finally:
        report["seconds"] = time.monotonic() - started
        (folder / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        if display:
            display.terminate()
            try:
                display.wait(timeout=5)
            except subprocess.TimeoutExpired:
                display.kill()
                display.wait()
        if display_log:
            display_log.close()
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
