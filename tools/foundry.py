#!/usr/bin/env python3
"""Build, validate, publish development content, and prepare reference analysis jobs.

stdlib only for generation; reference fetching optionally needs yt-dlp + ffmpeg.
No paid API is invoked. Novel video interpretation is performed by an AI agent
reading analysis_jobs.jsonl and the contact sheets, never fabricated by this CLI.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

from run_tests import run_engine

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build/foundry"
MEDIA = ROOT / "build/reference_media"


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def build(args):
    BUILD.mkdir(parents=True, exist_ok=True)
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 120)
    reports = []
    for profile in args.profiles:
        target = BUILD / profile / "batch.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        n = args.count if profile == "base" else max(6, args.count // 4)
        out = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script",
                          "tools/foundry_validate.gd", "--", f"--count={n}",
                          f"--profile={profile}", f"--output=res://{target.relative_to(ROOT)}"], 300)
        (target.parent / "run.log").write_text(out)
        report = json.loads(target.read_text())
        if report["failures"] or len(report["accepted"]) != n:
            raise RuntimeError("Rejected or incomplete batch; retained evidence, not promoted")
        reports.append(report)
    if len({r["basis"] for r in reports}) != 1:
        raise RuntimeError("Mixed validation bases")
    combined = {"schema": 1, "basis": reports[0]["basis"], "engine": reports[0]["engine"],
                "accepted": [item for r in reports for item in r["accepted"]],
                "rejected": [item for r in reports for item in r["rejected"]],
                "itineraries": [m for r in reports for m in r["itineraries"]],
                "connection_proofs": [p for r in reports for p in r["connection_proofs"]],
                "design_status": "awaiting_playtest", "production_pool": False}
    write(BUILD / "batch.json", combined)
    if args.promote:
        dest = ROOT / "resources/foundry"
        staging = BUILD / "promote"
        if staging.exists(): shutil.rmtree(staging)
        staging.mkdir()
        (staging / "replays").mkdir()
        write(staging / "batch.json", combined)
        for report in reports:
            referenced = [entry["manifest"] for entry in report["accepted"]] + report["itineraries"]
            for manifest in referenced:
                replay = BUILD / report["profile"] / "replays" / (manifest["id"] + ".json")
                data = json.loads(replay.read_text())
                if data["basis"] != combined["basis"] or data["manifest_hash"] != manifest["hash"]:
                    raise RuntimeError("Stale or mismatched input replay; not promoted")
                shutil.copy2(replay, staging / "replays" / replay.name)
        if dest.exists(): shutil.rmtree(dest)
        shutil.copytree(staging, dest)
    print(f"Validated {len(combined['accepted'])} development phrases; "
          f"{len(combined['connection_proofs'])} continuous itineraries. Fun: awaiting playtest.")


def duration(path):
    value = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                            "-of", "json", str(path)], capture_output=True, text=True, timeout=15, check=True)
    return float(json.loads(value.stdout)["format"]["duration"])


def sources(args):
    config = json.loads((ROOT / "config/foundry_sources.json").read_text())
    MEDIA.mkdir(parents=True, exist_ok=True)
    jobs, results = [], []
    for source in config["sources"]:
        if "media_name" not in source: continue
        if args.only and source["id"] != args.only: continue
        path = MEDIA / source["media_name"]
        if args.fetch and not path.exists():
            command = [sys.executable, "-m", "yt_dlp", "--no-playlist", "-f", "worstvideo",
                       "--socket-timeout", "15", "--retries", "0", "--download-sections",
                       f"*{source['start']}-{source['end']}", "-o", str(path), source["url"]]
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=180)
                (MEDIA / (source["id"] + ".fetch.log")).write_text(result.stdout + result.stderr)
                if result.returncode: results.append({"id": source["id"], "status": "fetch_failed"})
            except subprocess.TimeoutExpired:
                results.append({"id": source["id"], "status": "fetch_timeout"})
        if not path.exists():
            results.append({"id": source["id"], "status": "media_unavailable"})
            continue
        try:
            seconds = duration(path)
            expected = source["end"] - source["start"]
            # ffprobe alone can accept a truncated file: actually decode it too.
            subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(path),
                            "-f", "null", "-"], capture_output=True, timeout=60, check=True)
            if seconds > expected + 5 or seconds < 1:
                results.append({"id": source["id"], "status": "duration_mismatch", "seconds": seconds, "expected": expected})
                continue
            partial = seconds < expected - 2
            sheets = MEDIA / "sheets"
            sheets.mkdir(exist_ok=True)
            for offset in range(0, int(seconds), 40):
                sheet = sheets / f"{source['id']}-{offset:03d}.jpg"
                subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", str(offset), "-i", str(path),
                                "-vf", "fps=1/2.5,scale=384:-1,tile=4x4", "-frames:v", "1", str(sheet)],
                               capture_output=True, timeout=30, check=True)
                if not sheet.exists(): continue
                jobs.append({"source_id": source["id"], "source_url": source["url"],
                             "start": source["start"] + offset,
                             "end": source["start"] + min(offset + 40, seconds),
                             "sampling_seconds": 2.5, "sheet": str(sheet.relative_to(ROOT)),
                             "timestamp_precision": "approximate_partial_stream" if partial else "decoded_clip_offset",
                             "status": "awaiting_ai_analysis",
                             "instruction": "逐格描述可见动作与空间变化。区分可见事实与推测。粗采样不能推断精确输入、重试或隐藏路线。输出动作依赖、玩家判断、节奏、迁移到一跳/反冲的设计假设；禁止将未看到的段落写为已验证。"})
            results.append({"id": source["id"], "status": "decoded_partial_clip" if partial else "decoded_clip", "seconds": seconds,
                            "requested_seconds": expected,
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError, KeyError) as error:
            results.append({"id": source["id"], "status": "decode_failed", "reason": type(error).__name__})
    target = BUILD / "reference_jobs.jsonl"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("".join(json.dumps(job, ensure_ascii=False) + "\n" for job in jobs))
    write(BUILD / "reference_fetch.json", results)
    print(f"Prepared {len(jobs)} analysis windows. Evidence: {target}")


def next_jobs(args):
    """An AI-readable bounded revision queue; no claim of autonomous model training."""
    templates = json.loads((ROOT / "config/platforming_foundry.json").read_text())["templates"]
    if args.feedback and Path(args.feedback).stat().st_size > 4 * 1024 * 1024: raise ValueError("Feedback file exceeds 4 MiB")
    votes = json.loads(Path(args.feedback).read_text()) if args.feedback else []
    if isinstance(votes, dict):
        if votes.get("schema") != 2 or votes.get("scope") != "foundry": raise ValueError("Unsupported feedback bundle")
        votes = votes.get("records")
    if not isinstance(votes, list) or len(votes) > 500: raise ValueError("Feedback must contain at most 500 records")
    valid_ratings = set(["keep", "boring", "hard", "unclear", "control", "note"])
    for vote in votes:
        if not isinstance(vote, dict) or vote.get("rating") not in valid_ratings or not isinstance(vote.get("template_id"), str):
            raise ValueError("Malformed feedback record")
        if not isinstance(vote.get("manifest", {}), dict): raise ValueError("Malformed reproduction manifest")
        if not isinstance(vote.get("note", ""), str) or len(vote.get("note", "")) > 1000:
            raise ValueError("Feedback note exceeds bounds")
    reasons = {"boring": "增加真实判断变化或动作依赖；不要只加刺/缩台/改名。",
               "hard": "在不改Motor的前提下调整观察区、接收空间或机关窗口，并重新验证。",
               "unclear": "检查镜头、落点可见性与提示；保持碰撞及机关语义一致。",
               "control": "复现手感问题并记录输入与轨迹，不能擅改基础移动参数。",
               "note": "读取player_notes与原始manifest复现玩家问题，按意见修改后重新验证。"}
    jobs = []
    for template in templates:
        relevant = [v for v in votes if isinstance(v, dict) and (v.get("template_id") == template["id"] or any(isinstance(p, dict) and p.get("template_id") == template["id"] for p in v.get("manifest", {}).get("phrases", []) if isinstance(v.get("manifest", {}), dict)))]
        counts = {r: sum(v.get("rating") == r for v in relevant) for r in reasons}
        issue = max(counts, key=counts.get) if any(counts.values()) else "keep"
        jobs.append({"feedback_records": relevant, "player_notes": [v["note"] for v in relevant if v.get("note")], "current_basis": json.loads((ROOT / "resources/foundry/batch.json").read_text()).get("basis"), "template_id": template["id"], "priority": sum(counts.values()),
                     "task": reasons.get(issue, "没有负面反馈；保留已验证结构，先观察再决定是否修改。"), "reference_ids": template["reference_ids"],
                     "acceptance": "修改后运行build与FoundryLab回归，保留否决；新模板至少含两个不同判断。没有模型服务时本队列由下一次AI代理会话执行。"})
    jobs.sort(key=lambda job: -job["priority"])
    write(BUILD / "revision_jobs.json", jobs)
    print(f"Prepared {len(jobs)} AI revision jobs at {BUILD / 'revision_jobs.json'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    builder = commands.add_parser("build")
    builder.add_argument("--count", type=int, default=24)
    builder.add_argument("--profiles", nargs="+", default=["base", "double_jump", "air_chain"])
    builder.add_argument("--promote", action="store_true", help="Install fully verified content in development Foundry; never formal pool")
    refs = commands.add_parser("sources")
    refs.add_argument("--fetch", action="store_true")
    refs.add_argument("--only", default="")
    jobs = commands.add_parser("next")
    jobs.add_argument("--feedback", default="", help="Exported foundry_feedback.json; optional")
    experience = commands.add_parser("experience", help="Fresh golden technical slices; never promote production content")
    experience.add_argument("--output", default="build/level_design_v2/golden")
    experience.add_argument("--count", type=int, default=24, choices=[6, 12, 24, 48])
    args = parser.parse_args()
    if args.command == "build": build(args)
    elif args.command == "sources": sources(args)
    elif args.command == "experience":
        from level_design_golden import run
        run(args)
    else: next_jobs(args)


if __name__ == "__main__":
    try: main()
    except (OSError, RuntimeError, subprocess.SubprocessError, KeyError, ValueError) as error:
        print(f"Foundry failed: {error}", file=sys.stderr)
        sys.exit(1)
