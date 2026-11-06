#!/usr/bin/env python3
"""Offline Level Design Harness V2; never grants abilities or promotes content."""
import argparse
import contextlib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"Duplicate JSON field: {key}")
            result[key] = value
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"Nonfinite JSON: {value}")))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def engine_log_matches(engine, text):
    """Godot's dictionary string and startup banner use different separators."""
    from godot_identity import expected_version
    selected = expected_version()
    core, _commit = selected.rsplit('.', 1)
    major, minor, patch, status, build = core.split('.', 4)
    selected_string = f"{major}.{minor}.{patch}-{status} ({build})"
    banners = re.findall(r"^Godot Engine v([^\s]+)(?:\s|$)", text, re.M)
    if str(engine) == selected_string:
        return bool(banners) and all(banner == selected for banner in banners)
    # Historical receipts retain their original single-component build format.
    version = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)-([a-zA-Z0-9]+) \(([a-zA-Z0-9_]+)\)", str(engine))
    if not version:
        return False
    expected = version.groups()
    parsed = [re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.([a-zA-Z0-9]+)\.([a-zA-Z0-9_]+)\.[a-fA-F0-9]+", banner)
              for banner in banners]
    return bool(parsed) and all(banner and banner.groups() == expected for banner in parsed)


def validate_receipt(source, data, receipt, log, current_sources):
    """Check local invocation consistency, not cryptographic producer identity."""
    problems = []
    if not isinstance(data, dict) or not isinstance(receipt, dict):
        return ["Capture and receipt must be objects"]
    source = Path(source).resolve()
    if not source.is_relative_to(ROOT / "build"):
        problems.append("Fresh execution receipts must refer to repository build outputs")
    relative = source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else str(source)
    if receipt.get("schema_version") != 1 or receipt.get("scope") != "actual_godot_process":
        problems.append("Wrong invocation schema/scope")
    if type(receipt.get("exit_code")) is not int or receipt["exit_code"] != 0:
        problems.append("Process did not exit zero")
    if receipt.get("capture") != relative or receipt.get("capture_sha256") != file_hash(source):
        problems.append("Capture path/content mismatch")
    if receipt.get("source_commit") != data.get("source_commit"):
        problems.append("Source commit mismatch")
    if not current_sources or receipt.get("source_files") != current_sources:
        problems.append("Source files changed or missing")
    if (data.get("scope") != "formal_manifest_and_assembler_shotlatch_traces_not_enemy_or_boss_completion"
            or not isinstance(data.get("formal_run_manifest"), dict)):
        problems.append("Not a formal consumer capture")
    traces = data.get("traces", [])
    strategies = [trace.get("strategy") for trace in traces if isinstance(trace, dict)]
    formal = data.get("formal_run_manifest")
    root_seed = formal.get("root_seed") if isinstance(formal, dict) else None
    if (not root_seed or len(strategies) != len(traces) or not strategies
            or len(set(strategies)) != len(strategies)
            or any(s not in {"fast", "growth", "deep"} for s in strategies)):
        problems.append("Invalid seed/strategy coverage")
    expected = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script",
                "tools/level_design_capture.gd", "--", "--source-commit=" + str(data.get("source_commit")),
                "--seed=" + str(root_seed), "--strategies=" + ",".join(str(s) for s in strategies),
                "--output=res://" + relative]
    if receipt.get("command") != expected:
        problems.append("Unexpected producer command/arguments")
    if not log.is_file() or receipt.get("log_sha256") != file_hash(log):
        problems.append("Log missing or content mismatch")
    else:
        text = log.read_text()
        marks = re.findall(r"^LEVEL DESIGN CAPTURE: ([1-9]\d*) assertions, (\d+) failures, ([1-9]\d*) traces$", text, re.M)
        assertions = data.get("assertions")
        if (type(assertions) is not int or assertions <= 0
                or marks != [(str(assertions), "0", str(len(traces)))] or data.get("failures") != []):
            problems.append("Missing or inconsistent nonempty completion")
        if not engine_log_matches(data.get("engine"), text):
            problems.append("Engine version missing from execution log")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text):
            problems.append("Engine script/shader failure")
    return problems


def source_files(root=ROOT):
    """Include new/untracked sources too; no build/cache or evidence dependency."""
    paths = [root / "project.godot"]
    for folder in ("scripts", "game", "experiments", "scenes", "resources", "config", "tools", "tests"):
        paths.extend(p for p in (root / folder).rglob("*") if p.is_file()
                     and p.suffix in {".gd", ".py", ".tres", ".tscn", ".json", ".sh"})
    return {p.relative_to(root).as_posix(): file_hash(p) for p in sorted(paths)}


def capture(args):
    from run_tests import run_engine
    target = Path(args.output).resolve()
    if not target.is_relative_to(ROOT / "build"):
        raise ValueError("Capture writes only under repository build/; archive reviewed evidence separately")
    target.parent.mkdir(parents=True, exist_ok=True)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    before = source_files()
    log = target.with_suffix(".log")
    invocation = {"schema_version": 1, "source_commit": commit, "source_files": before,
                  "scope": "actual_godot_process", "exit_code": None, "capture": str(target.relative_to(ROOT))}
    command = ["--headless", "--fixed-fps", "60", "--path", ".", "--script",
               "tools/level_design_capture.gd", "--", f"--source-commit={commit}",
               f"--seed={args.seed}", "--strategies=" + ",".join(args.strategies),
               "--output=res://" + str(target.relative_to(ROOT))]
    invocation["command"] = ["bash", "tools/godot.sh", *command]
    # Remove only this output, so an early engine exit cannot reuse old success.
    target.unlink(missing_ok=True)
    try:
        with log.open("w") as stream, contextlib.redirect_stdout(stream):
            run_engine(["--headless", "--path", ".", "--editor", "--quit"], 120)
            output = run_engine(command, 480)
        if not re.search(r"^LEVEL DESIGN CAPTURE: [1-9]\d* assertions, 0 failures, [1-9]\d* traces$", output, re.M):
            raise ValueError("Missing capture completion marker")
        data = read(target)
        if data.get("failures") or len(data.get("traces", [])) != len(args.strategies):
            raise ValueError("Failed or incomplete capture")
        if before != source_files():
            raise ValueError("Source changed during capture; retained evidence is not fresh")
        invocation["exit_code"] = 0
    except Exception as error:
        invocation.update(exit_code=1, error=str(error))
        raise
    finally:
        invocation["log_sha256"] = file_hash(log) if log.exists() else None
        invocation["capture_sha256"] = file_hash(target) if target.exists() else None
        write(target.with_suffix(".invocation.json"), invocation)
    print(f"PASS: level design capture ({len(data['traces'])} actual strategies); {target}")


def analyze(args):
    from level_design_analysis import analyze_capture, seal_report
    source = Path(args.capture)
    data = read(source)
    report = analyze_capture(data, read(args.policy) if args.policy else None)
    invocation_path = source.with_suffix(".invocation.json")
    # An arbitrary JSON or fixture is never promoted to a fresh Motor run by analysis.
    provenance = {"status": "unverified", "reason": "No matching process invocation receipt"}
    if invocation_path.exists():
        receipt = read(invocation_path)
        log = source.with_suffix(".log")
        problems = validate_receipt(source, data, receipt, log, source_files())
        valid = not problems
        provenance = {"status": "passed" if valid else "failed", "receipt": str(invocation_path),
                      "kind": "local_invocation_consistency_not_authentication", "problems": problems,
                      "reason": "Matched command, completion, content and current source; independent replay remains required" if valid else "Stale or mismatched invocation evidence"}
        if not valid:
            report["verdict"] = "REJECT"
            report.setdefault("findings", []).append({"code": "provenance_mismatch", "severity": "error",
                                                       "location": str(source), "evidence_kind": "process_receipt"})
    report["provenance"] = provenance
    report["artifacts"] = [{"path": str(source), "sha256": file_hash(source), "kind": "runtime_capture"}]
    for item in args.evidence:
        path = Path(item)
        report["artifacts"].append({"path": str(path), "sha256": file_hash(path), "kind": "linked_evidence_not_automatically_approved"})
    write(args.output, seal_report(report))
    print(f"Level experience report: {args.output}; {report.get('verdict')}; subjective/device unverified")
    return 1 if report.get("verdict") == "REJECT" else 0


def content_plan(request, mode=None, phase="auto"):
    raise ValueError("Random-region content planning retired; use fixed-world task handoff")


def load_spatial_experiment(path, region_id, root=ROOT):
    """A frozen design and exact experimental write lease, never core authorization."""
    relative = Path(path)
    target = Path(root) / relative
    if relative.is_absolute() or '..' in relative.parts or target.is_symlink() or not target.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('Spatial experiment must be a repository-relative regular design')
    data = read(target)
    if (not isinstance(data, dict) or type(data.get('schema_version')) is not int or data['schema_version'] != 1
            or data.get('region_id') != region_id or not isinstance(data.get('authorization_basis'), str)
            or not data['authorization_basis'].strip() or not isinstance(data.get('design'), dict) or not data['design']
            or not isinstance(data.get('validation'), list) or not data['validation']
            or any(not isinstance(item, str) or not item.strip() for item in data['validation'])):
        raise ValueError('Spatial experiment needs region, explicit authorization, design and validation')
    paths = data.get('allowed_paths')
    if not isinstance(paths, list) or not paths or any(not isinstance(item, str) or not item for item in paths) or len(set(paths)) != len(paths):
        raise ValueError('Spatial experiment needs a distinct exact-file write set')
    for name in paths:
        entry = Path(name)
        # Preserve the original generation/art/scene scope at its current homes.
        # World state and arbitrary experiments are not geometry permissions.
        permitted = (name.startswith(('scripts/generation/', 'scripts/art/', 'resources/generation/', 'resources/art/',
                                      'scenes/', 'assets/', 'tests/', 'tools/',
                                      'game/world/generation/', 'game/world/components/scenes/',
                                      'game/presentation/world/art/', 'game/presentation/actors/art/',
                                      'game/presentation/effects/art/', 'game/presentation/world/resources/art/',
                                      'game/presentation/actors/resources/art/',
                                      'game/enemies/species/scenes/', 'game/enemies/scenes/',
                                      'experiments/terrain/art/', 'experiments/terrain/entries/',
                                      'experiments/platform/entries/', 'experiments/audio/entries/',
                                      'experiments/motion/entries/', 'experiments/generation/entries/'))
                     or name in {'scripts/demo/demo_app.gd', 'game/application/demo_app.gd',
                                 'game/application/demo.tscn', 'game/player/player.tscn',
                                 'game/world/components/module_moving_platform.gd',
                                 'game/world/components/module_moving_platform.gd.uid',
                                 'game/world/components/module_saw_hazard.gd',
                                 'game/world/components/module_saw_hazard.gd.uid',
                                 'game/world/components/platforming_module.gd',
                                 'game/world/components/platforming_module.gd.uid'})
        if (entry.is_absolute() or '..' in entry.parts or name.endswith('/') or any(c in name for c in '*?[')
                or not entry.suffix or not permitted or (Path(root)/name).is_dir()
                or re.search(r'(?:motor|rng|save|ability|weapon|resource)', entry.stem, re.I)
                or entry.stem == 'movement_capability_envelope'):
            raise ValueError('Spatial experiment cannot grant directories or protected core: ' + name)
        candidate = Path(root)/name
        if candidate.is_symlink() or not candidate.resolve().is_relative_to(Path(root).resolve()):
            raise ValueError('Spatial experiment write path escapes repository: ' + name)
    return data, {'path': relative.as_posix(), 'sha256': file_hash(target), 'region_id': region_id, 'allowed_paths': paths}


def world_rebuild_request(request, region_id):
    """Explicit source-painting pilot only, never a whole-region default."""
    return bool(region_id == "windchime_plains"
        and re.search(r"源画|source.paint", request, re.I)
        and re.search(r"重建|重做|rebuild", request, re.I)
        and re.search(r"地貌|地形|landform|terrain", request, re.I)
        and re.search(r"美术|art", request, re.I)
        and not re.search(r"调色|贴图|palette|森林|forest|解锁|新机制|武器规则|能力规则|物理参数", request, re.I))


def art_language_request(request, region_id):
    """Explicit module/world art-language work; do not grant it for a palette edit."""
    return bool(region_id == "windchime_plains"
        and re.search(r"关卡|模块|地形|地貌|生成|level|module|generat", request, re.I)
        and re.search(r"美术语言|美术参数|尺寸规格|尺寸族|art.language|art.parameters|size.spec", request, re.I)
        and not re.search(r"调色|换纹理|更换纹理|贴图|palette|retexture|解锁|新机制|武器规则|能力规则|物理参数", request, re.I))


def joint_landform_request(request, region_id):
    """Explicit shared art/level intent; surface-only requests grant no geometry."""
    visual_words = re.search(r"美术|画面|视觉|调色|纹理|\bart\b|visual|palette|texture", request, re.I)
    joint_words = re.search(r"联合|共同|协同|joint|co.design", request, re.I)
    level_words = re.search(r"关卡|玩法|碰撞|地形|level|collision", request, re.I)
    surface_only = re.search(r"调色|换纹理|更换纹理|贴图|palette|retexture", request, re.I)
    landform_words = re.search(r"地貌|地形语言|模块语言|环境构造|landform|module.language", request, re.I)
    protected_change = re.search(r"解锁|新机制|武器规则|能力规则|物理参数", request, re.I)
    return (region_id == "windchime_plains" and not protected_change
        and ((joint_words and level_words and visual_words)
             or (landform_words and not surface_only)
             or art_language_request(request, region_id)
             or world_rebuild_request(request, region_id)))


def route_request(request, mode=None, phase="auto", direction=None, spatial_experiment=None):
    """Retired random-region production route; ordinary tasks use current handoff."""
    raise ValueError("Random-region production route retired by MV-MIGRATION-01. "
                     "Use docs/project/tasks.md and the current workline; "
                     "query tools/world/room_context.py for fixed rooms. "
                     "Historical capture/analyze commands remain explicit regression tools.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    validate = commands.add_parser("validate", help="Validate design intent, not physical traversal")
    validate.add_argument("designs", nargs="+")
    runner = commands.add_parser("capture", help="Run actual Godot formal Manifest and continuous terrain traces")
    runner.add_argument("--seed", default="level-design-v2-baseline")
    runner.add_argument("--strategies", nargs="+", choices=["fast", "growth", "deep"], default=["fast", "growth", "deep"])
    runner.add_argument("--output", default="build/level_design_v2/capture.json")
    analyzer = commands.add_parser("analyze")
    analyzer.add_argument("--capture", required=True)
    analyzer.add_argument("--output", required=True)
    analyzer.add_argument("--policy")
    analyzer.add_argument("--evidence", nargs="*", default=[])
    compare = commands.add_parser("compare")
    compare.add_argument("--before", required=True)
    compare.add_argument("--after", required=True)
    compare.add_argument("--output", required=True)
    route = commands.add_parser("route")
    route.add_argument("--request", required=True)
    route.add_argument("--mode", choices=["optimize", "new_region"])
    route.add_argument("--phase", choices=["auto", "preproduction", "prototype", "production"], default="auto")
    route.add_argument("--direction", help="Bind a selected versioned region creative direction")
    route.add_argument("--spatial-experiment", help="Frozen experimental design JSON with exact authorized file writes")
    route.add_argument("--output", required=True)
    experience = commands.add_parser("experience", help="Analyze live enemies, rewards, camera and Q1–Q8 evidence")
    experience.add_argument("parameters", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command == "validate":
        from level_design_contracts import validate_design
        errors = [{"file": name, **error} for name in args.designs for error in validate_design(read(name))]
        if errors:
            print(json.dumps(errors, ensure_ascii=False, indent=2)); return 1
        print(f"PASS: {len(args.designs)} level design intent contracts; physics/subjective not inferred")
    elif args.command == "capture":
        capture(args)
    elif args.command == "analyze":
        return analyze(args)
    elif args.command == "compare":
        from level_design_analysis import compare_reports
        result = compare_reports(read(args.before), read(args.after))
        write(args.output, result)
        print(f"Comparison: {args.output}")
        return 1 if result.get("verdict") == "REJECT" else 0
    elif args.command == "experience":
        from level_experience import main as experience_main
        return experience_main(args.parameters)
    else:
        from production_loop import validate as validate_mission
        mission = route_request(args.request, args.mode, args.phase, args.direction, args.spatial_experiment)
        validate_mission(mission)
        write(args.output, mission)
        print(f"PASS: {mission['workflow']} routed to existing harness --mission {args.output}; plan only")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"Level design failed: {error}", file=sys.stderr)
        sys.exit(1)
