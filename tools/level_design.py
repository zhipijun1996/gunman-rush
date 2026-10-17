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
    version = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)-([a-zA-Z0-9]+) \(([a-zA-Z0-9_]+)\)", str(engine))
    if not version:
        return False
    expected = version.groups()
    banners = re.findall(r"^Godot Engine v(\d+)\.(\d+)\.(\d+)\.([a-zA-Z0-9]+)\.([a-zA-Z0-9_]+)\.[a-fA-F0-9]+(?:\s|$)", text, re.M)
    return bool(banners) and all(banner == expected for banner in banners)


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
    for folder in ("scripts", "scenes", "resources", "config", "tools", "tests"):
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
    """Deterministic request routing, shared with existing production_loop missions."""
    if not isinstance(request, str) or not request.strip():
        raise ValueError("A concrete region request is required")
    optimize = bool(re.search(r"优化|改善|改进|审计|无聊|重复|不好看|不流畅|optimi[sz]e|audit|improve", request, re.I))
    create = bool(re.search(r"制作|新地区|新区域|创建|create|new biome|new region", request, re.I))
    if mode is None:
        if optimize == create:
            raise ValueError("Ambiguous workflow; specify --mode optimize or new_region")
        mode = "optimize" if optimize else "new_region"
    if mode not in {"optimize", "new_region"}:
        raise ValueError("Unknown level workflow")
    if phase not in {"auto", "prototype", "production"}:
        raise ValueError("Unknown region production phase")
    if phase == "prototype" and mode != "new_region":
        raise ValueError("Prototype phase requires a new-region request")
    from level_region_context import build_region_context, resolve_region_id
    from level_experience import load_lessons
    region_id = resolve_region_id(request)
    region_context = (build_region_context(region_id) if region_id is not None else
                      {"region_id": None, "status": "unregistered", "request": request,
                       "implementation": {"runtime_available": None, "validation_status": "unverified"},
                       "required_next_step": "Identify or register the requested region and its authoritative design sources; do not inherit plains defaults."})
    preparation = {"region_context": region_context, "lessons": load_lessons(region_id),
                   "task_registration": {"source": "AGENTS.md",
                                         "paths": ["docs/tasks.md", "docs/quality/records/"],
                                         "phase": "design", "before_quality_profile": True,
                                         "requirement": "Register every new task ID in docs/tasks.md and create its quality record before running quality profiles."}}
    steps = (["读取正式实现与玩家反馈", "采集实际Manifest和多策略路线", "定位最严重问题", "设计有证据的改进", "制作少量黄金改进样板",
              "验证动作探索美术体验", "在准入后批量推广", "回归原消费者", "独立审查", "提供同条件前后对照"]
             if mode == "optimize" else
             ["确定世界观与难度定位", "明确合法基础装备能力", "设计独特核心玩法", "设计空间语法和视觉身份", "设计机关敌人挑战",
              "制作最小黄金样板", "验证新机制和连续动作", "建立可复用模块库", "生成多种非线性拓扑", "编排奖励能力锁及回程",
              "制作并组合美术", "验正式完整体验", "修复最差Seed与反馈", "正式消费者集成与独立质量审查"])
    groups = [
        ("audit", ["region-generator"], ["docs"], "读取权威实现、反馈与证据，完成现状/能力审计", True),
        ("design", ["region-generator", "challenge-choreographer", "encounter-director", "scene-composer"], ["level-design-contracts"], "先在docs/tasks.md注册所有新任务ID并建立质量记录，再执行quality profile；建立六层设计合同与可证伪验收，校验所有合法基础构筑", False),
        ("golden", ["level-module-creator", "challenge-choreographer", "art-director"], ["level-design-golden", "level-design-runtime"], "先完成真实Motor与构图黄金切片，注明技术/视觉/设备边界", False),
        ("integration", ["region-generator", "encounter-director", "scene-composer"], ["level-design-analysis", "region"], "仅推广已通过对应准入的切片；验证随机拓扑、能力锁、奖励和回程", False),
        ("review", ["gameplay-reviewer"], ["level-design-contracts", "level-design-analysis", "region"], "独立审查实际路线、失败反例与前后对照；未验维度不代签", True),
    ]
    if mode == "new_region":
        # These owners begin from the authoritative design, independently of a
        # different package's golden. No parallel writes are introduced.
        groups[1][1].extend(["enemy-creator", "boss-creator", "art-director", "animation-vfx", "visual-director"])
        groups[2:2] = [
            ("ecology", ["enemy-creator", "encounter-director", "region-generator"], ["level-design-contracts"],
             "前置设计地区机制生态、敌人操作压力/状态/反制与地形组合；制作隔离样板并以本地区真实输入/弹体验证，不复制平原敌人参数当新生态", False),
            ("boss", ["boss-creator", "encounter-director", "animation-vfx"], ["level-design-contracts"],
             "前置设计地区Boss、竞技场、阶段决策/预警/弱点/恢复/死亡奖励；制作逐阶段及连续战斗隔离样板，原Boss仅作契约回归", False),
            ("assets", ["visual-director", "art-director", "scene-composer"], ["level-design-contracts"],
             "前置制作地区资产家族与真实比例静态合屏黄金，记录来源/许可/语义尺度/根基/接合；独立实际像素G2准入后才推广同族", False),
            ("animation", ["animation-vfx", "art-director"], ["level-design-contracts"],
             "前置制作敌人/Boss/机关及环境动作状态表与过渡，真实已接受事件驱动正常速度连续音画；静态图与Hash不能代签动画", False),
        ]
        preparation["production_boundary"] = {
            "region_id": region_id, "formal_opening_authorized": False,
            "runtime_status": region_context["implementation"],
            "scope": "authoritative_design_and_isolated_prototypes_before_formal_admission",
            "shared_regression_is_region_proof": False,
            "requirement": "每个样板须本地区消费者/能力/实际进程与源绑定证据；现有平原/Foundry通过仅作共享回归。正式开放与能力授予不得由route或Studio推断。"}
    import harness
    final_checks = harness.resolve_checks(harness.load_manifest(), ["gameplay", "art", "web"])
    tasks = []
    previous = []
    for name, skills, checks, goal, readonly in groups:
        if name == "review":
            checks = final_checks
        if mode == "new_region" and name == "integration":
            skills = skills + ["enemy-creator", "boss-creator", "animation-vfx"]
        allowed = ["docs/", "tests/", "tools/"]
        if not readonly and name in {"golden", "integration", "ecology", "boss", "assets", "animation"}:
            allowed += ["scripts/generation/", "scripts/art/", "scripts/enemies/", "scripts/demo/",
                        "scripts/bosses/", "scripts/world/", "scripts/audio/", "scenes/",
                        "resources/generation/", "resources/enemies/", "resources/bosses/",
                        "resources/art/", "assets/"]
        task_id = f"level-{mode}-{name}"
        dependencies = previous
        if mode == "new_region":
            prefix = "level-new_region-"
            dependencies = ({"audit": [], "design": [prefix + "audit"],
                "ecology": [prefix + "design"], "boss": [prefix + "design"], "assets": [prefix + "design"],
                "animation": [prefix + n for n in ("ecology", "boss", "assets")],
                "golden": [prefix + n for n in ("design", "ecology", "boss", "assets", "animation")],
                "integration": [prefix + "golden"], "review": [prefix + "integration"]})[name]
        tasks.append({"id": task_id, "goal": f"{request}：{goal}", "skills": skills, "checks": checks,
                      "depends_on": dependencies, "read_only": readonly,
                      "allowed_paths": allowed,
                      "quality_record": "docs/quality/records/" + task_id + ".json"})
        if name == "audit":
            tasks[-1]["completion"] = "scope"
        elif name == "review":
            # Final read-only review cannot bypass the integrated content's G5.
            tasks[-1].update(completion="content", quality_task_id=previous[0],
                             quality_record="docs/quality/records/" + previous[0] + ".json")
        else:
            tasks[-1].update(completion="stage", required_gates={
                "design": ["G0"], "golden": ["G0", "G1"],
                "ecology": ["G0", "G1"], "boss": ["G0", "G1"],
                "assets": ["G0", "G1", "G2"], "animation": ["G0", "G1", "G2"],
                "integration": ["G0", "G1", "G2", "G3"]}[name])
        if mode == "new_region" and name not in {"audit", "design"}:
            tasks[-1]["region_proof"] = {"region_id": region_id, "kind": name if name != "review" else "integration",
                "scope": "formal" if name in {"integration", "review"} else "prototype",
                "capability_gate": region_context.get("design", {}).get("gate", {}),
                "shared_checks_only": [c for c in checks if c in {"region", "level-design-golden", "level-design-runtime"}]}
        previous = [task_id]
    mission = {"schema_version": 1, "objective": request, "workflow": mode, "steps": steps,
            "preparation": preparation,
            "max_calls": 30, "max_rounds": 3, "call_timeout_seconds": 1800, "tasks": tasks,
            "scope": "offline_production_plan_not_executed", "human_acceptance": "unverified",
            "constraints": ["No PlayerMotor/resource/RNG/save changes to fit content", "No future ability on required route",
                            "Existing quality policy and all applicable profiles remain authoritative",
                            "Golden technical success is not visual, fun, device or production admission"]}
    selected = ("prototype" if mode == "new_region" and region_id is not None
                and region_context["implementation"]["formal_region"] == "no_formal_consumer_observed"
                else "production") if phase == "auto" else phase
    mission["phase"] = selected
    if mode == "new_region":
        mission["production_plan"] = tasks
    if selected == "prototype":
        if region_id is None:
            raise ValueError("Prototype requires registered authoritative region input")
        gate = region_context["design"]["gate"]
        implemented_slice = region_id == "thorn_forest" and gate["alternatives"] == [["H"]]
        identifier = f"level-new_region-{region_id}-prototype"
        checks = ["level-design-contracts", "level-design-routing", "level-region-context"]
        if implemented_slice:
            checks.append("forest-h-slice")
        mission["tasks"] = [{"id": identifier, "goal": request + "：读取带来源设计与当前消费者，完成G0设计和一个隔离开发技术样板；"
            "使用本地区实际入口能力和真实Motor/Router/资源验证连续动作、落地和返回；保留实际删目标/无能力反例。"
            "无现成地区producer时先实现对应真实消费者/runner，不拿平原或Foundry证明本地区。技术灰盒不签正式开放或美术。",
            "skills": ["region-generator", "level-module-creator", "challenge-choreographer"], "checks": checks,
            "depends_on": [], "read_only": False, "allowed_paths": ["docs/", "tests/", "tools/", "scripts/demo/"],
            "quality_record": "docs/quality/records/" + identifier + ".json", "completion": "stage", "required_gates": ["G0", "G1"],
            "region_proof": {"region_id": region_id, "kind": "golden", "scope": "prototype", "capability_gate": gate,
                             **({"allowed_capabilities": ["H"]} if implemented_slice else {})}}]
        if implemented_slice:
            mission["tasks"][0]["allowed_paths"] += ["scripts/demo/thorn_forest_h_slice.gd.uid", "tests/forest_h_slice_runner.gd.uid"]
        mission["max_calls"] = 4
        mission["max_rounds"] = 2
        mission["preparation"]["task_registration"]["phase"] = "prototype"
        mission["preparation"]["production_boundary"].update(
            selected_phase="prototype", native_producer="forest-h-slice" if implemented_slice else None,
            production_plan_status="pending_all_nine_packages_not_executed",
            requirement="按原质量记录执行隔离G0/G1样板；production_plan仅为后续完整门槛，不能提前标通过。")
    return mission


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
        permitted = (name.startswith(('scripts/generation/', 'scripts/art/', 'resources/generation/', 'resources/art/',
                                      'scenes/', 'assets/', 'tests/', 'tools/', 'docs/evidence/'))
                     or name == 'scripts/demo/demo_app.gd')
        if (entry.is_absolute() or '..' in entry.parts or name.endswith('/') or any(c in name for c in '*?[')
                or not entry.suffix or not permitted or (Path(root)/name).is_dir()
                or re.search(r'(?:motor|rng|save|ability|weapon|resource)', entry.stem, re.I)
                or entry.stem == 'movement_capability_envelope'):
            raise ValueError('Spatial experiment cannot grant directories or protected core: ' + name)
        candidate = Path(root)/name
        if candidate.is_symlink() or not candidate.resolve().is_relative_to(Path(root).resolve()):
            raise ValueError('Spatial experiment write path escapes repository: ' + name)
    return data, {'path': relative.as_posix(), 'sha256': file_hash(target), 'region_id': region_id, 'allowed_paths': paths}


def route_request(request, mode=None, phase="auto", direction=None, spatial_experiment=None):
    """The public short-prompt entry starts creative work before content production."""
    from level_region_context import resolve_region_id
    from region_creative_direction import load_direction
    region_id = resolve_region_id(request)
    # A short art-only improvement should use the existing art execution loop,
    # not restart biome design or lose the actual image/consumer recipe.
    art_improvement = (region_id == "windchime_plains"
        and re.search(r"优化|改善|改进|制作|重做|绘制|improve|optimi[sz]e|create", request, re.I)
        and re.search(r"美术|画面|视觉|\bart\b|visual", request, re.I)
        and not re.search(r"玩法|碰撞|物理|解锁|新机制|武器规则|能力规则", request))
    if art_improvement and mode is None and phase == "auto" and direction is None and spatial_experiment is None:
        from visual_director import route as art_route
        task_id = "visual-windchime-plains-" + hashlib.sha256(request.encode()).hexdigest()[:8]
        quality_record = "docs/quality/records/" + task_id + "-golden.json"
        plan = art_route(request, task_id, quality_record,
            ["scripts/art/", "assets/visual_development/", "resources/visual_development/",
             "tools/visual_director.py", "tools/level_formal_capture.gd",
             "tools/plains_environment_preview.gd", "tools/plains_environment_capture.gd",
             "tests/plains_environment_trace.gd", "docs/quality/records/",
             "docs/evidence/p1_environment/", "docs/tasks.md"])
        _, binding = load_direction("docs/creative_direction/windchime_plains.json", region_id)
        plan["native_import_preflight"] = True
        plan["context_mode"] = "compact"
        # This is the existing art subtask loop, not a newly bound region
        # production golden. Carry its authority in the shared preparation;
        # explicit full-region requests retain all joint G2 requirements below.
        plan["preparation"]["creative_direction"] = binding
        for task in plan["tasks"]:
            task["feedback_context"] = "compact"
        return plan
    plan = content_plan(request, mode, "production" if phase in {"auto", "preproduction"} else phase)
    plan["native_import_preflight"] = True
    if spatial_experiment is not None and (direction is None or plan["phase"] != "production"):
        raise ValueError("Spatial experiment requires selected direction and full production plan")
    if direction is not None:
        if region_id is None:
            raise ValueError("Register the region before binding a creative direction")
        data, binding = load_direction(direction, region_id)
        if phase == "prototype" and region_id == "thorn_forest":
            for task in plan["tasks"]:
                task["checks"] = ["forest-current-slice" if c == "forest-h-slice" else c for c in task["checks"]]
                task["region_proof"]["kind"] = "technical_sample"
                task["goal"] += "；使用当前默认短钩索与真实反冲/落地恢复/返回，原历史长钩索仅用于复现；严格退出未过必须blocked。"
                task["allowed_paths"] += ["scripts/demo/thorn_forest_current_slice.gd", "scripts/demo/thorn_forest_current_slice.gd.uid", "tests/forest_current_slice_runner.gd", "tests/forest_current_slice_runner.gd.uid", "tools/run_forest_current_slice_tests.py"]
        for task in plan["tasks"]:
            task["creative_direction"] = binding.copy()
            task["feedback_context"] = "compact"
            task["goal"] += "；逐项交付总谱贡献、协作依赖、新行为/视觉、主题冲突和真实游戏验证；方向不成立RETHINK，不适合候选DISCARD，局部失败REWORK。"
        if plan["phase"] == "production":
            golden = next(task for task in plan["tasks"] if task["id"].endswith("-golden"))
            golden["skills"] = list(dict.fromkeys(golden["skills"] + ["visual-director", "scene-composer", "encounter-director", "animation-vfx"]))
            golden["required_gates"] = ["G0", "G1", "G2"]
            golden["requires_visual_admission"] = True
            golden["goal"] += "；只制作第一个统一可玩黄金空间，空间/挑战/遭遇/视觉/动画共同设计。G2截图与正常速度视频必须由独立视觉审查ACCEPT；复用质量卡independent_review证据，并以reviewed_evidence引用本卡G2全部媒体ID。未准入不得第二空间、多Seed或扩产。"
            integration = next(task for task in plan["tasks"] if task["id"].endswith("-integration"))
            integration["goal"] += "；仅在首黄金G2与独立视觉实机审查均ACCEPT后才允许第二空间和多Seed推广，不扩产失败母版。"
            if spatial_experiment is not None:
                experiment_data, experiment = load_spatial_experiment(spatial_experiment, region_id)
                if (experiment_data["design"].get("direction_path") != binding["path"]
                        or experiment_data["design"].get("direction_sha256") != binding["sha256"]):
                    raise ValueError("Spatial design direction path/hash differs from selected creative direction")
                plan["spatial_experiment"] = experiment
                for task in plan["tasks"]:
                    if task["id"].endswith(("-design", "-golden")):
                        task["spatial_experiment"] = experiment.copy()
                        task["allowed_paths"] = list(dict.fromkeys(experiment["allowed_paths"] + [task["quality_record"], "docs/tasks.md"]))
                        task["goal"] += "；按已冻结spatial_experiment真实消费设计并产出golden_manifest，仅改精确写集中的几何/镜头/表现；保留PlayerMotor/武器能力/资源/RNG/保存。"
        plan.update(creative_direction=binding, creative_phase="production", context_mode="compact")
        plan["preparation"]["creative_selection"] = {"direction_id": data["direction_id"], "acceptance": data["acceptance"]}
        return plan
    if phase == "prototype":
        plan["creative_phase"] = "engineering_prototype_only"
        return plan
    identifier = "creative-" + (region_id or "unregistered")
    target = "docs/creative_direction/" + (region_id or "unregistered") + ".json"
    task = {"id": identifier, "goal": request + "：先注册本任务/质量记录；读取最新地区设计与实际消费者；提出2–3个在体验、空间、生态/Boss、艺术情绪上实质不同的完整方向，比较原创性、可行性、玩家吸引力及商业展示假设，推荐一个。把版本总谱写入" + target + "，涵盖全屏大形/负空间/层深/动态音画、明确排除、真实可玩切片与跨专业接口。推荐不是用户最终认可；不生成正式地图/资产，不开放地区。",
            "skills": ["region-creative-director"], "checks": ["creative-direction"],
            "depends_on": [], "read_only": False, "allowed_paths": ["docs/creative_direction/", "docs/tasks.md", "docs/quality/records/"],
            "quality_record": "docs/quality/records/" + identifier + ".json", "completion": "stage", "required_gates": ["G0"], "max_calls": 4}
    plan.update(phase="preproduction", creative_phase="preproduction", tasks=[task],
                max_calls=4, max_rounds=2, context_mode="compact", production_plan=plan["tasks"],
                continuation={"condition": "selected direction passes independent G0 scope review; preserve user approval as unverified",
                              "command": ["python3", "tools/level_design.py", "route", "--request", request, "--direction", target, "--output", "build/creative_system/production.json"],
                              "execution": "active host advances this checkpoint using the existing harness; no unattended model service"})
    return plan


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
