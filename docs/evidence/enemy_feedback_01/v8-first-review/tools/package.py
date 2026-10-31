#!/usr/bin/env python3
"""Package real v7/v8 engine movies without running or modifying the game.

The selected intervals are consecutive, normal-speed source frames and audio.
Only factual footer labels are drawn. All raw inputs remain unchanged.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time


DEFAULT_REPO = Path("/workspace/gunman-rush-work")
FONT = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")


def sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(path: Path) -> dict:
    return {"bytes": path.stat().st_size, "sha256": sha(path)}


def save_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def full_commit(value: str) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{40}", value):
        raise argparse.ArgumentTypeError("Runtime SHA must be a complete 40-character Git commit")
    return value.lower()


def invoke(command: list[str], output: Path, receipt: dict, *, capture: bool = False) -> str:
    started = time.monotonic()
    result = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, check=False, timeout=180)
    log = {"command": command, "exit_code": result.returncode,
           "seconds": time.monotonic()-started, "stdout": result.stdout, "stderr": result.stderr}
    receipt["executions"].append(log)
    # Keep the recipe/failed command recoverable even if encoding fails.
    save_json(output / "recipe.json", receipt)
    if result.returncode:
        raise RuntimeError(f"Command failed with exit {result.returncode}: {shlex.join(command)}")
    return result.stdout if capture else ""


def probe(path: Path, output: Path, receipt: dict) -> dict:
    command = ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]
    return json.loads(invoke(command, output, receipt, capture=True))


def validate_media(media: dict, minimum: float, maximum: float, *, expected_frames: int | None = None) -> None:
    video = next(stream for stream in media["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in media["streams"] if stream["codec_type"] == "audio")
    duration = float(media["format"]["duration"])
    if not (video["width"] == 1280 and video["height"] == 720 and video["avg_frame_rate"] == "60/1"
            and audio["sample_rate"] == "48000" and audio["channels"] == 2
            and minimum <= duration <= maximum):
        raise RuntimeError(f"Unexpected movie geometry, timing or stereo audio: {duration}s")
    if expected_frames is not None and int(video.get("nb_frames", -1)) != expected_frames:
        raise RuntimeError(f"Expected exactly {expected_frames} original frames; got {video.get('nb_frames')}")


def footer(version: str, runtime: str) -> str:
    # Full runtime SHA comes only from the validated CLI and provenance check.
    text = f"ENEMY-FEEDBACK-01 | {version} | runtime {runtime}"
    return ("drawbox=x=38:y=630:w=1200:h=34:color=0x0d141c:t=fill,"
            f"drawtext=fontfile={FONT}:text={text}:x=54:y=641:fontsize=19:fontcolor=white")


def encode_command(inputs: list[Path], filters: list[str], destination: Path) -> list[str]:
    command = ["ffmpeg", "-nostdin", "-n", "-v", "error"]
    for path in inputs:
        command.extend(["-i", str(path)])
    command.extend(["-filter_complex", ";".join(filters), "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-threads", "2",
                    "-r", "60", "-fps_mode", "cfr", "-enc_time_base", "1:60",
                    "-c:a", "aac", str(destination)])
    return command


def matching_report(path: Path, movie: Path, runtime: str) -> dict:
    data = json.loads(path.read_text())
    source = data.get("source", {})
    if data.get("status") != "passed" or data.get("source_stable") is not True:
        raise RuntimeError(f"Capture has not passed its own source guard: {path}")
    if source.get("commit") != runtime:
        raise RuntimeError(f"CLI runtime does not match actual capture provenance: {path}")
    if source.get("working_files") or source.get("git_status", "").strip():
        raise RuntimeError(f"Capture source was dirty; full runtime SHA alone would be misleading: {path}")
    if data.get("mp4_sha256") != sha(movie):
        raise RuntimeError(f"Capture report/movie SHA mismatch: {path}")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-v8", required=True, type=full_commit)
    parser.add_argument("--runtime-v7", required=True, type=full_commit)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--raw-dir", type=Path,
                        help="Default: REPO/build/enemy-feedback-01/v8/movie")
    parser.add_argument("--v7-dir", type=Path,
                        help="Default: REPO/docs/evidence/enemy_feedback_01/v7/movies")
    parser.add_argument("--output", type=Path,
                        help="Must not exist. Default: REPO/docs/evidence/enemy_feedback_01/v8/movies")
    parser.add_argument("--prior-failure", type=Path,
                        help="Preserved first rejected packaging directory; included as historical failure evidence")
    args = parser.parse_args()
    repo = args.repo.resolve()
    raw = (args.raw_dir or repo / "build/enemy-feedback-01/v8/movie").resolve()
    previous = (args.v7_dir or repo / "docs/evidence/enemy_feedback_01/v7/movies").resolve()
    output = (args.output or repo / "docs/evidence/enemy_feedback_01/v8/movies").resolve()
    prior_failure = (args.prior_failure or repo / "build/enemy-feedback-01/v8/package-first-rejected").resolve()
    raw_movie = raw / "after.mp4"
    previous_movie = previous / "after-raw.mp4"
    inputs = [raw_movie, raw / "after.json", raw / "report.json", raw / "after.log",
              previous_movie, previous / "after-report.json"]
    for path in inputs:
        if not path.is_file():
            raise FileNotFoundError(path)
    if not FONT.is_file():
        raise FileNotFoundError(FONT)
    if output.exists():
        raise FileExistsError(f"Use a fresh destination, never overwrite earlier evidence: {output}")
    current_report = matching_report(raw / "report.json", raw_movie, args.runtime_v8)
    matching_report(previous / "after-report.json", previous_movie, args.runtime_v7)
    trace_path = raw / "after.json"
    trace_sha = sha(trace_path)
    if current_report.get("trace_sha256") != trace_sha:
        raise RuntimeError("Current raw trace/report SHA mismatch")
    original_inputs = {str(path): inventory(path) for path in inputs}
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"task": "ENEMY-FEEDBACK-01", "status": "packaging", "source_runtime": args.runtime_v8,
               "before_runtime": args.runtime_v7, "before_immutable_path": str(previous_movie),
               "after_seconds": 14, "comparison_seconds": 20,
               "scope": "Actual consecutive MovieMaker frame/audio excerpts; factual footer only; no game redraw, interpolation, playback speed change, sound substitution or review/user claim.",
               "segments": {"after.mp4": [{"version": "V8", "source_seconds": [0, 7]}, {"version": "V8", "source_seconds": [13, 20]}],
                            "comparison.mp4": [{"version": "V7", "case": "ground", "source_seconds": [.5, 5.5]},
                                               {"version": "V8", "case": "ground", "source_seconds": [.5, 5.5]},
                                               {"version": "V7", "case": "aerial", "source_seconds": [13.5, 18.5]},
                                               {"version": "V8", "case": "aerial", "source_seconds": [13.5, 18.5]}]},
               "raw_inputs": original_inputs, "packager": {"path": str(Path(__file__).resolve()), "sha256": sha(Path(__file__))},
               "commands": [], "executions": [], "files": {}, "input_bytes_stable": False}
    started = time.monotonic()
    try:
        if (prior_failure / "recipe.json").is_file():
            failed_recipe = json.loads((prior_failure / "recipe.json").read_text())
            if failed_recipe.get("status") != "failed":
                raise RuntimeError("Prior-failure evidence is not an actual failed receipt")
            shutil.copy2(prior_failure / "recipe.json", output / "packaging-first-rejected-recipe.json")
            receipt["prior_failure"] = {"directory": str(prior_failure), "recipe": inventory(prior_failure / "recipe.json"),
                                        "error": failed_recipe.get("error"), "status": "failed; retained, not relabeled"}
            if (prior_failure / "after.mp4").is_file():
                failed_probe = probe(prior_failure / "after.mp4", output, receipt)
                receipt["prior_failure"]["actual_after_probe"] = failed_probe
                receipt["prior_failure"]["after_mp4"] = inventory(prior_failure / "after.mp4")
            (output / "packaging-notes.md").write_text(
                "# V8 packaging timing correction\n\n"
                "The first actual packaging attempt failed the existing strict 60/1 frame-rate guard. "
                "Its 14-second movie contained 840 frames, but concat timestamps produced "
                "avg_frame_rate=40000000/665873. The failed receipt is retained in "
                "packaging-first-rejected-recipe.json; the original rejected directory and actual probe are recorded in recipe.json.\n\n"
                "This retry sets the concatenated video time base to 1/60 and assigns each original "
                "frame PTS=N. Encoder time base is 1:60 with passthrough frame scheduling. "
                "No fps/interpolation filter, frame duplication or speed change is applied. "
                "The strict 60/1 guard remains and output frame counts must be exactly 840 and 1200. "
                "Audio is trimmed from the same intervals at its original speed.\n\n"
                "These are packaging observations only; no independent review, user approval or device claim is made.\n")
        second_failure = repo / "build/enemy-feedback-01/v8/package-second-rejected"
        if (second_failure / "recipe.json").is_file():
            failed_retry = json.loads((second_failure / "recipe.json").read_text())
            if failed_retry.get("status") != "failed":
                raise RuntimeError("Second packaging-failure receipt is not failed")
            shutil.copy2(second_failure / "recipe.json", output / "packaging-second-rejected-recipe.json")
            receipt["second_prior_failure"] = {"directory": str(second_failure), "recipe": inventory(second_failure / "recipe.json"),
                                               "error": failed_retry.get("error"), "status": "failed; retained, not relabeled"}
            with (output / "packaging-notes.md").open("a") as notes:
                notes.write("\nThe first timing-fix attempt also failed before encoding: this FFmpeg rejects "
                            "the combination of output -r 60 and passthrough scheduling (exit 234). "
                            "Its complete command/stderr/receipt is retained in packaging-second-rejected-recipe.json. "
                            "This retry removes -r, retaining explicit filter/encoder 1/60 time bases, PTS=N, "
                            "passthrough scheduling and the unchanged 60/1 plus exact-frame-count guards.\n")
        third_failure = repo / "build/enemy-feedback-01/v8/package-third-rejected"
        if (third_failure / "recipe.json").is_file():
            failed_timing = json.loads((third_failure / "recipe.json").read_text())
            if failed_timing.get("status") != "failed":
                raise RuntimeError("Third packaging-failure receipt is not failed")
            shutil.copy2(third_failure / "recipe.json", output / "packaging-third-rejected-recipe.json")
            receipt["third_prior_failure"] = {"directory": str(third_failure), "recipe": inventory(third_failure / "recipe.json"),
                                              "error": failed_timing.get("error"), "status": "failed; retained, not relabeled"}
            receipt["third_prior_failure"]["actual_after_probe"] = probe(third_failure / "after.mp4", output, receipt)
            with (output / "packaging-notes.md").open("a") as notes:
                notes.write("\nThe time-base-only passthrough retry produced 840 frames but a zero-duration "
                            "last video packet: video duration 13.983333s, avg_frame_rate=50400/839. "
                            "The unchanged strict guard rejected it; its complete receipt is retained in "
                            "packaging-third-rejected-recipe.json. The final retry retains exact "
                            "1/60 PTS=N and uses output -r 60 / -fps_mode cfr so the final packet receives "
                            "its normal 1/60-second duration. No interpolation filter is applied; "
                            "output must still contain exactly 840/1200 selected original frames at 60/1.\n")
            receipt["final_timing_contract"] = {"filter_time_base": "1/60", "filter_pts": "N", "encoder_time_base": "1:60",
                                                 "fps_mode": "cfr", "output_rate": "60/1", "expected_frame_counts": [840, 1200],
                                                 "interpolation_filter": False, "scope": "assign final packet duration on exact original 1/60 frame lattice"}
        archived_movie = output / "after-raw.mp4"
        shutil.copy2(raw_movie, archived_movie)
        shutil.copy2(raw / "report.json", output / "after-report.json")
        shutil.copy2(raw / "after.log", output / "native.log")
        with trace_path.open("rb") as source, (output / "after.json.gz").open("wb") as target:
            with gzip.GzipFile(filename="", fileobj=target, mode="wb", mtime=0) as compressed:
                shutil.copyfileobj(source, compressed)
        with gzip.open(output / "after.json.gz", "rb") as restored:
            restored_sha = hashlib.file_digest(restored, "sha256").hexdigest()
        if restored_sha != trace_sha or sha(archived_movie) != sha(raw_movie):
            raise RuntimeError("Raw archive byte preservation failed")
        receipt["trace_archive"] = {"gzip_mtime": 0, "restored_sha256": restored_sha, "matches_raw": True}
        for path in [previous_movie, archived_movie]:
            media = probe(path, output, receipt)
            validate_media(media, 26, 28)
            receipt.setdefault("input_probes", {})[str(path)] = media
        after_filters = ["[0:v]split=2[v0][v1]", "[0:a]asplit=2[a0][a1]"]
        for index, (start, end) in enumerate([(0, 7), (13, 20)]):
            after_filters.extend([f"[v{index}]trim=start={start}:end={end},setpts=PTS-STARTPTS,{footer('V8', args.runtime_v8)}[p{index}]",
                                  f"[a{index}]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[s{index}]"])
        after_filters.append("[p0][s0][p1][s1]concat=n=2:v=1:a=1[joined_v][a]")
        after_filters.append("[joined_v]settb=expr=1/60,setpts=N[v]")
        command = encode_command([archived_movie], after_filters, output / "after.mp4")
        receipt["commands"].append(command)
        invoke(command, output, receipt)
        comparison_filters = ["[0:v]split=2[b0][b1]", "[0:a]asplit=2[ba0][ba1]",
                              "[1:v]split=2[c0][c1]", "[1:a]asplit=2[ca0][ca1]"]
        pieces = [("b0", "ba0", .5, 5.5, "V7", args.runtime_v7),
                  ("c0", "ca0", .5, 5.5, "V8", args.runtime_v8),
                  ("b1", "ba1", 13.5, 18.5, "V7", args.runtime_v7),
                  ("c1", "ca1", 13.5, 18.5, "V8", args.runtime_v8)]
        for index, (video, audio, start, end, version, runtime) in enumerate(pieces):
            comparison_filters.extend([f"[{video}]trim=start={start}:end={end},setpts=PTS-STARTPTS,{footer(version, runtime)}[v{index}]",
                                       f"[{audio}]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[a{index}]"])
        comparison_filters.append("[v0][a0][v1][a1][v2][a2][v3][a3]concat=n=4:v=1:a=1[joined_v][a]")
        comparison_filters.append("[joined_v]settb=expr=1/60,setpts=N[v]")
        command = encode_command([previous_movie, archived_movie], comparison_filters, output / "comparison.mp4")
        receipt["commands"].append(command)
        invoke(command, output, receipt)
        for name, duration in [("after.mp4", 14), ("comparison.mp4", 20)]:
            media = probe(output / name, output, receipt)
            validate_media(media, duration, duration + .2, expected_frames=duration*60)
            receipt.setdefault("output_probes", {})[name] = media
        for path in inputs:
            if inventory(path) != original_inputs[str(path)]:
                raise RuntimeError(f"Raw input changed during packaging: {path}")
        receipt["input_bytes_stable"] = True
        for path in sorted(output.iterdir()):
            if path.is_file() and path.name != "recipe.json":
                receipt["files"][path.name] = inventory(path)
        receipt["status"] = "packaged"
        print(f"Packaged actual 14s after / 20s comparison and full raw archive: {output}")
        return 0
    except BaseException as exc:
        receipt.update(status="failed", error=str(exc))
        raise
    finally:
        receipt["seconds"] = time.monotonic() - started
        save_json(output / "recipe.json", receipt)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
