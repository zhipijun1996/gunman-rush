"""Future controlled primary160 projections; preparation only, never quality PASS.

Run from the repository only AFTER both real controlled batches have completed:
  python3 build/plains_redesign/plot_controlled_maps.py \
    --before-project /workspace/plains-redesign-baseline \
    --after-project /workspace/gunman-rush [--trajectories]

Defaults: controlled_comparison/{before,after}/batch.json -> controlled_maps/.
No engine, gameplay mutation, invented geometry, outcome-based selection, or
overwrite. Requires the existing plot_final_geometry.py and matplotlib.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
BASE_PATH = ROOT / "build/plains_redesign/plot_final_geometry.py"
FAMILIES = {"woven_layers", "crossroads", "linked_rings"}
STRATEGIES = {"fast", "growth", "deep", "return"}
VERSIONS = {"before": "plains-region-v9", "after": "plains-region-v10"}
SCOPE = (
    "Recorded static engineering projection: platform geometry, logical links, "
    "moving-deck endpoint ranges, enemy SPAWN and reward locations. Omits "
    "textures, fog, GUI, hazard geometry/phases and live enemy motion. Optional "
    "line is recorded actor positions, including failed/partial routes. Not a "
    "gameplay screenshot, physical/reachability review, fun or art acceptance."
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def object_digest(value):
    return digest(json.dumps(value, sort_keys=True, separators=(",", ":"),
                             ensure_ascii=False, allow_nan=False).encode())


def reference(path):
    path = Path(path).resolve()
    return str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)


def repo_file(value):
    require(isinstance(value, str) and bool(value), "Missing file reference")
    path = Path(value)
    path = (ROOT / path).resolve() if not path.is_absolute() else path.resolve()
    require(path.is_relative_to(ROOT / "build"), "Evidence outside repository build: " + str(path))
    require(path.is_file(), "Missing actual evidence: " + str(path))
    return path


def numbers(value, length, label):
    require(isinstance(value, list) and len(value) == length, "Malformed " + label)
    require(all(type(v) in (int, float) and math.isfinite(v) for v in value),
            "Nonfinite/nonnumeric " + label)
    return value


def rectangle(value, label):
    numbers(value, 4, label)
    require(value[2] > 0 and value[3] > 0, "Nonpositive " + label)
    return value


def sha_field(value, label):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value),
            "Missing/invalid SHA256: " + label)
    return value


def load_base():
    require(BASE_PATH.is_file(), "Missing existing plot_final_geometry.py")
    spec = importlib.util.spec_from_file_location("recorded_static_geometry", BASE_PATH)
    require(spec is not None and spec.loader is not None, "Cannot load existing plotting producer")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = ROOT
    return module


def load_batch(base, path, side):
    path = repo_file(str(path))
    batch = base.read(path)
    require(batch.get("schema_version") == 1 and batch.get("artifact_kind") == "formal_capture_batch",
            side + ": unsupported actual batch schema")
    cases = batch.get("cases")
    require(isinstance(cases, list) and len(cases) == 80,
            side + ": expected complete primary80 cases, not a smoke/cohort subset")
    require(batch.get("requested_cases") == batch.get("captured_cases") == 80,
            side + ": primary80 has missing/rejected captures")
    rows = {}
    for row in cases:
        require(row.get("captured") is True and row.get("errors") == [],
                side + ": batch retains a failed integrity capture")
        require(row.get("strategy") in STRATEGIES and row.get("map_index") in (1, 2)
                and type(row.get("map_index")) is int, side + ": unknown strategy/map")
        require(isinstance(row.get("seed"), str) and row["seed"], side + ": absent root seed")
        require(row.get("phase_wait_ticks") == 0 and type(row.get("phase_wait_ticks")) is int,
                side + ": unsupported phase-wait cohort")
        key = (row["seed"], row["map_index"], row["strategy"])
        require(key not in rows, side + ": duplicate seed/map/strategy")
        require(repo_file(row.get("capture")).is_relative_to(path.parent),
                side + ": capture pointer escapes its actual batch directory")
        rows[key] = row
    roots = {key[0] for key in rows}
    expected = {(seed, map_index, strategy) for seed in roots
                for map_index in (1, 2) for strategy in STRATEGIES}
    require(len(roots) == 10 and set(rows) == expected,
            side + ": incomplete ten-root/two-map/four-strategy identity grid")
    return {"path": path, "sha256": digest(path.read_bytes()), "rows": rows}


def load_capture(base, row, side, expected_policy):
    raw = repo_file(row["capture"])
    # Actual batch schema stores capture only; the existing formal producer
    # writes precisely these .invocation.json/.log companions (not guessed cases).
    receipt_path = repo_file(row.get("receipt", str(raw.with_suffix(".invocation.json"))))
    log_path = repo_file(row.get("log", str(raw.with_suffix(".log"))))
    receipt = base.read(receipt_path)
    require(receipt.get("schema_version") == 2 and receipt.get("status") == "accepted"
            and receipt.get("errors") == [] and type(receipt.get("exit_code")) is int
            and receipt["exit_code"] == 0
            and receipt.get("scope") == "actual_live_demo_app_capture",
            side + ": receipt is not an accepted actual formal capture")
    raw_sha = digest(raw.read_bytes())
    require(receipt.get("capture_sha256") == raw_sha, side + ": raw capture SHA mismatch")
    require(repo_file(receipt.get("capture")) == raw, side + ": receipt/raw identity mismatch")
    require(receipt.get("log_sha256") == digest(log_path.read_bytes()), side + ": log SHA mismatch")
    sources = receipt.get("source_before")
    require(isinstance(sources, dict) and sources and sources == receipt.get("source_after")
            == receipt.get("source_files"), side + ": absent or drifting receipt source snapshots")
    for rel, sha in sources.items():
        require(isinstance(rel, str) and not Path(rel).is_absolute()
                and ".." not in Path(rel).parts, side + ": malformed receipt source path")
        sha_field(sha, rel)
    data = base.read(raw)
    require(data.get("schema_version") == 1 and data.get("capture_contract_version") == 3
            and data.get("artifact_kind") == "formal_level_capture"
            and data.get("capture_errors") == [] and data.get("physics_hz") == 60,
            side + ": unsupported/incomplete actual capture version")
    require(data.get("source_commit") == receipt.get("source_commit")
            and isinstance(data.get("source_commit"), str) and data["source_commit"],
            side + ": missing or inconsistent source commit")
    request = receipt.get("request", {})
    for key in ("root_seed", "map_index", "strategy", "phase_wait_ticks"):
        require(request.get(key) == data.get(key), side + ": receipt request mismatch/" + key)
    require((data.get("root_seed"), data.get("map_index"), data.get("strategy"))
            == (row["seed"], row["map_index"], row["strategy"]), side + ": wrong batch identity")
    require(data.get("encounter_policy") == row.get("encounter_policy")
            == request.get("encounter_policy") == expected_policy,
            side + ": policy differs from controlled request")
    require(data.get("outcome") == row.get("outcome")
            and data.get("route_reached") == row.get("route_reached"), side + ": batch outcome mismatch")
    require(data.get("frames") and len(data["frames"]) == row.get("frames"),
            side + ": missing/truncated actual frames")
    for collection in ("runtime_source_hashes", "capture_source_hashes"):
        actual = data.get(collection)
        require(isinstance(actual, dict) and actual, side + ": absent " + collection)
        require(all(sources.get(rel.removeprefix("res://")) == sha for rel, sha in actual.items()),
                side + ": recorded runtime/observer SHA mismatch")
    manifest = data.get("manifest")
    require(isinstance(manifest, dict) and manifest.get("version") == VERSIONS[side],
            side + ": unknown/unsupported layout version")
    require(data.get("manifest_hash") == manifest.get("manifest_hash"), side + ": Manifest identity mismatch")
    sha_field(manifest.get("manifest_hash"), "ManifestHash")
    require(manifest.get("family") in FAMILIES and manifest.get("seed") == data.get("seed"),
            side + ": unsupported family/seed")
    for name in ("formal_run_manifest_initial", "formal_run_manifest_final"):
        run = data.get(name)
        require(isinstance(run, dict) and run.get("schema_version") == 1
                and run.get("root_seed") == data["root_seed"], side + ": missing/unknown RunManifest")
        require(run.get("versions", {}).get("generated_layout") == manifest["version"],
                side + ": RunManifest version differs from recorded layout")
        stages = run.get("stages")
        require(isinstance(stages, list), side + ": absent RunManifest stages")
        matches = [s for s in stages if s.get("outputs", {}).get("region_map", {}).get("map_index")
                   == data["map_index"]]
        require(len(matches) == 1 and matches[0].get("outputs", {}).get("generated_layout") == manifest,
                side + ": actual RunManifest stage does not contain exact recorded layout")
    log = log_path.read_text()
    marks = re.findall(r"^LEVEL FORMAL CAPTURE: (\d+) frames, (\d+) edges, outcome=(\S+), capture_errors=(\d+)$",
                       log, re.M)
    require(marks == [(str(len(data["frames"])), str(len(data.get("edges", []))), str(data["outcome"]), "0")],
            side + ": actual formal completion marker mismatch")
    require(not re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", log),
            side + ": actual capture log contains script/shader error")
    return data, receipt, {"raw": reference(raw), "raw_sha256": raw_sha,
        "receipt": reference(receipt_path), "receipt_sha256": digest(receipt_path.read_bytes()),
        "log": reference(log_path), "log_sha256": digest(log_path.read_bytes()),
        "source_commit": receipt["source_commit"], "source_before_sha256": object_digest(sources),
        "manifest_hash": manifest["manifest_hash"], "run_manifest_initial_sha256":
        object_digest(data["formal_run_manifest_initial"])}


def verify_project_resources(project, sources):
    require(project.is_dir() and (project / "project.godot").is_file(), "Missing actual project: " + str(project))
    resource_sources = {p: sha for p, sha in sources.items() if p.startswith("resources/")}
    require(resource_sources, "Receipt has no actual resource sources")
    # Include runtime geometry interpretation, not only parameter .tres bytes.
    for rel in ("scripts/generation/plains_region_generator.gd",
                "scripts/generation/platforming_module_definition.gd",
                "scripts/generation/module_moving_platform_definition.gd"):
        require(rel in sources, "Missing geometry interpreter provenance: " + rel)
        resource_sources[rel] = sources[rel]
    for rel, expected in resource_sources.items():
        path = (project / rel).resolve()
        require(path.is_relative_to(project) and path.is_file()
                and digest(path.read_bytes()) == expected,
                "Actual project resource/interpreter drift: " + str(path))
    return resource_sources


def assignment(section, key):
    values = re.findall(r"^" + re.escape(key) + r"\s*=\s*([^\n]+)$", section, re.M)
    require(len(values) <= 1, "Unsupported duplicate resource assignment: " + key)
    return values[0].strip() if values else None


def checked_geometry(base, node, sources, project, used):
    require(node.get("mirrored") is False and node.get("reverse_traversal") is False,
            "Unsupported mirrored/reverse node; refuse misleading projection")
    require(not any(k in node for k in ("rotation", "scale", "transform", "flip_h", "flip_v")),
            "Unsupported transformed node")
    numbers(node.get("offset"), 2, "node offset")
    module_id = node.get("module_id")
    require(isinstance(module_id, str) and re.fullmatch(r"[a-z0-9_]+", module_id), "Unsupported module ID")
    if "geometry" in node:
        require(isinstance(node["geometry"], dict), "Malformed inline geometry")
        rectangle(node["geometry"].get("bounds"), "inline module bounds")
        require(all(k in node["geometry"] for k in ("platforms", "one_way", "ferries")),
                "Incomplete recorded inline geometry")
    geom = copy.deepcopy(base.get_geometry(node, sources, project, used))
    if "geometry" not in node:
        rel = "resources/generation/modules/" + module_id + ".tres"
        path = project / rel
        require(sources.get(rel) == digest(path.read_bytes()), "Actual Definition SHA mismatch: " + rel)
        text = path.read_text()
        require(text.count("[resource]") == 1 and '[gd_resource type="Resource"' in text,
                "Unsupported inherited/external geometry resource: " + rel)
        section = text.split("[resource]", 1)[1]
        declared = assignment(section, "module_id")
        require(declared in ('&"' + module_id + '"', '"' + module_id + '"'), "Definition module ID mismatch")
        version = assignment(section, "definition_version")
        if version is None:
            script = (project / "scripts/generation/platforming_module_definition.gd").read_text()
            require(re.search(r"^@export var definition_version := 1$", script, re.M),
                    "Unknown omitted Definition version default")
            version = "1"
        require(re.fullmatch(r"[1-9][0-9]*", version) and int(version) == node.get("definition_version"),
                "Unknown/mismatched Definition version: " + rel)
        sha_field(node.get("definition_hash"), "recorded Definition content hash")
        require(assignment(section, "mirrored_horizontal") in (None, "false"), "Unsupported resource mirror")
        slabs = assignment(section, "platforms")
        require(slabs is not None and re.fullmatch(r"Array\[Rect2\]\(\[.*\]\)", slabs),
                "Unsupported Definition platform representation: " + rel)
        residue = re.sub(r"Rect2\([^()]+\)", "", slabs[len("Array[Rect2](["): -2])
        require(not residue.replace(",", "").strip(), "Unknown platform geometry expression: " + rel)
        require(len(re.findall(r"Rect2\(", slabs)) == len(geom["platforms"]), "Dropped Definition platform")
        # Existing get_geometry only recognizes PackedInt32Array. Actual Godot
        # sources also use Array[int]; normalize this verified field explicitly.
        one = assignment(section, "one_way_platform_indices")
        indices = []
        if one is not None:
            match = re.fullmatch(r"(?:PackedInt32Array\(([^()]*)\)|Array\[int\]\(\[([^\[\]]*)\]\))", one)
            require(match is not None, "Unsupported one-way platform syntax: " + rel)
            values = match.group(1) if match.group(1) is not None else match.group(2)
            require(re.fullmatch(r"\s*(?:[0-9]+\s*(?:,\s*[0-9]+\s*)*)?", values), "Invalid one-way indices")
            indices = [int(v.strip()) for v in values.split(",") if v.strip()]
        geom["one_way"] = indices
        ferry = assignment(section, "ferries")
        if ferry is not None:
            require(re.fullmatch(r'Array\[ExtResource\("[^"\n]+"\)\]\(\[(?:SubResource\("[^"\n]+"\)(?:,\s*)?)*\]\)', ferry),
                    "Unsupported ferry resource references: " + rel)
            require(len(re.findall(r"SubResource\(", ferry)) == len(geom["ferries"]),
                    "Missing/extra parsed ferry geometry: " + rel)
        else:
            require(not geom["ferries"], "Undeclared ferry geometry")
    require(isinstance(geom.get("platforms"), list) and geom["platforms"], "Missing actual platform geometry")
    for slab in geom["platforms"]:
        rectangle(slab, "platform")
    require(isinstance(geom.get("one_way"), list)
            and len(set(geom["one_way"])) == len(geom["one_way"])
            and all(type(i) is int and 0 <= i < len(geom["platforms"]) for i in geom["one_way"]),
            "Invalid actual one-way indices")
    require(isinstance(geom.get("ferries"), list), "Missing ferries geometry")
    for ferry in geom["ferries"]:
        numbers(ferry.get("start"), 2, "ferry start")
        numbers(ferry.get("finish"), 2, "ferry finish")
        require(ferry["start"] != ferry["finish"], "Degenerate ferry endpoint range")
        if "geometry" in node:
            size = numbers(ferry.get("size"), 2, "inline ferry size")
            require(all(v > 0 for v in size), "Nonpositive inline ferry size")
    return geom


def prepare_projection(base, data, sources, project, trajectories):
    actual = data["manifest"]
    require(actual.get("nodes") and isinstance(actual.get("ground_supports"), list), "Missing actual geometry")
    rectangle(actual.get("world_bounds"), "world bounds")
    projected = copy.deepcopy(actual)
    used = {}
    for node in projected["nodes"]:
        # This is a derived plotting copy only: raw Manifest/RunManifest stay
        # unchanged, their recorded hash is never recomputed or relabelled.
        node["geometry"] = checked_geometry(base, node, sources, project, used)
    for slab in actual["ground_supports"]:
        rectangle(slab, "ground support")
    require(isinstance(actual.get("areas"), list) and actual["areas"], "Missing actual areas")
    ids = {a["id"] for a in actual["areas"]}
    require(len(ids) == len(actual["areas"]), "Duplicate actual area IDs")
    for area in actual["areas"]:
        numbers(area.get("position"), 2, "area position")
    for edge in actual["connections"]:
        require(edge.get("a") in ids and edge.get("b") in ids and "condition" in edge, "Unknown logical edge")
        if "path" in edge:
            require(isinstance(edge["path"], list) and len(edge["path"]) >= 2, "Malformed recorded edge path")
            for point in edge["path"]:
                numbers(point, 2, "recorded edge path point")
    for group in ("enemies", "rewards"):
        require(isinstance(actual.get(group), list), "Missing actual " + group)
        for item in actual[group]:
            numbers(item.get("position"), 2, group + " position")
    path = []
    if trajectories:
        frames = data["frames"]
        require(all(isinstance(f, dict) and "position" in f and type(f.get("tick")) is int for f in frames),
                "Requested trajectory lacks exact tick/position fields; no inferred path")
        require(all(a["tick"] + 1 == b["tick"] for a, b in zip(frames, frames[1:])),
                "Trajectory has missing/nonconsecutive recorded ticks")
        path = [numbers(frame["position"], 2, "actual frame position") for frame in frames]
    return projected, used, path


def union_bounds(a, b):
    x, y = min(a[0], b[0]), min(a[1], b[1])
    return [x, y, max(a[0] + a[2], b[0] + b[2]) - x,
            max(a[1] + a[3], b[1] + b[3]) - y]


def render(base, manifest, data, receipt, project, folder, origin, bounds, used, trajectory):
    # Retain the actual figure object while reusing the existing draw in full.
    # A closed matplotlib figure can be annotated and saved; no pixel editing.
    captured = []
    original_subplots = base.plt.subplots

    def remember(*args, **kwargs):
        fig, ax = original_subplots(*args, **kwargs)
        captured.append((fig, ax))
        return fig, ax

    base.plt.subplots = remember
    try:
        row = base.draw(manifest, {"map_index": data["map_index"]},
                        receipt["source_before"], project, folder, origin, bounds=bounds)
    finally:
        base.plt.subplots = original_subplots
    require(len(captured) == 1, "Existing draw no longer creates one figure")
    fig, ax = captured[0]
    if trajectory:
        ax.plot([p[0] for p in trajectory], [p[1] for p in trajectory],
                color="#b6d6f5", linewidth=0.8, alpha=0.8, zorder=3)
    ax.set_title(f"{origin['side'].upper()} | {manifest['version']} | map {data['map_index']} | "
                 f"{manifest['family']}\nroot {data['root_seed']} | Manifest {manifest['manifest_hash'][:16]}",
                 color="#eee1bd", fontsize=10)
    fig.text(.05, .012,
             f"raw {origin['raw']} | SHA {origin['raw_sha256'][:16]}\n"
             f"receipt SHA {origin['receipt_sha256'][:16]} | source_before {origin['source_before_sha256'][:16]} | "
             f"producer {origin['producer_sha256'][:16]} | exact full provenance: pair/index.json",
             color="#b1c3b8", fontsize=5.5)
    image_path = ROOT / row["image"]
    svg_path = image_path.with_suffix(".svg")
    fig.savefig(image_path, facecolor=fig.get_facecolor())
    fig.savefig(svg_path, facecolor=fig.get_facecolor())
    base.plt.close(fig)
    row.update(sha256=digest(image_path.read_bytes()), svg=reference(svg_path),
               svg_sha256=digest(svg_path.read_bytes()), used_definition_sources=used,
               projected_geometry_sha256=object_digest(manifest["nodes"]),
               trajectory={"included": bool(trajectory), "points": len(trajectory),
                           "source": "capture.frames[].position at consecutive tick" if trajectory else None},
               outcome=data["outcome"], route_reached=data["route_reached"])
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    comparison = ROOT / "build/plains_redesign/controlled_comparison"
    parser.add_argument("--before-batch", type=Path, default=comparison / "before/batch.json")
    parser.add_argument("--after-batch", type=Path, default=comparison / "after/batch.json")
    parser.add_argument("--before-project", type=Path, required=True)
    parser.add_argument("--after-project", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build/plains_redesign/controlled_maps")
    parser.add_argument("--encounter-policy", default="kill_from_bank_v1",
                        choices=("kill_from_bank_v1", "bait_then_bypass_v1"))
    parser.add_argument("--trajectories", action="store_true", help="Add exact recorded tick/position traces; never infer routes")
    args = parser.parse_args()
    output = args.output.resolve()
    require(output.is_relative_to(ROOT / "build") and not output.exists(),
            "Output must be a never-existing repository build directory")
    require(args.before_batch.is_file() and args.after_batch.is_file(),
            "Real controlled before/after batches do not yet exist; no plots produced")
    base = load_base()
    batches = {side: load_batch(base, getattr(args, side + "_batch"), side) for side in ("before", "after")}
    require(set(batches["before"]["rows"]) == set(batches["after"]["rows"]), "Before/after primary identities differ")
    projects = {side: getattr(args, side + "_project").resolve() for side in batches}
    # Selection uses the lexicographically first observed root for each AFTER
    # map/family. No route outcome or aesthetic criterion enters the ordering.
    selections = {}
    frozen_sources = {}
    for key, row in sorted(batches["after"]["rows"].items()):
        if key[2] != "fast":
            continue
        data, receipt, _ = load_capture(base, row, "after", args.encounter_policy)
        frozen_sources.setdefault("after", receipt["source_before"])
        require(receipt["source_before"] == frozen_sources["after"], "After fast captures mix source freezes")
        selections.setdefault((key[1], data["manifest"]["family"]), key)
    require(set(selections) == {(m, f) for m in (1, 2) for f in FAMILIES},
            "Actual after cohort does not cover six map/family representatives")
    prepared = []
    for (map_index, family), key in sorted(selections.items()):
        pair = {"key": key, "after_family": family, "map_index": map_index, "sides": {}}
        for side in ("before", "after"):
            data, receipt, origin = load_capture(base, batches[side]["rows"][key], side, args.encounter_policy)
            frozen_sources.setdefault(side, receipt["source_before"])
            require(receipt["source_before"] == frozen_sources[side], side + ": selected maps mix source freezes")
            projected, used, trajectory = prepare_projection(base, data, receipt["source_before"], projects[side], args.trajectories)
            pair["sides"][side] = (data, receipt, origin, projected, used, trajectory)
        left, right = (pair["sides"][side][0] for side in ("before", "after"))
        require(left["root_seed"] == right["root_seed"] and left["map_index"] == right["map_index"]
                and left["initial_capability"] == right["initial_capability"], "Paired seed/map/initial capability differs")
        for field in ("driver_sources", "core_invariants", "reward_policy", "encounter_policy"):
            require(left.get("policy_basis", {}).get(field) is not None
                    and left["policy_basis"][field] == right.get("policy_basis", {}).get(field),
                    "Paired observer/core/policy basis differs: " + field)
        pair["bounds"] = union_bounds(left["manifest"]["world_bounds"], right["manifest"]["world_bounds"])
        prepared.append(pair)
    verified = {side: verify_project_resources(projects[side], frozen_sources[side]) for side in batches}
    producer_sha = digest(Path(__file__).read_bytes())
    base_sha = digest(BASE_PATH.read_bytes())
    # Nothing is written until every selected source and geometry preflight passes.
    output.mkdir(parents=True)
    index = {"schema_version": 1, "scope": SCOPE, "quality_acceptance": "unverified",
             "selection": "First lexicographic actual root among fast captures per after map/family; outcome-independent",
             "producer": reference(Path(__file__)), "producer_sha256": producer_sha,
             "reused_producer": reference(BASE_PATH), "reused_producer_sha256": base_sha,
             "batches": {side: {"path": reference(batches[side]["path"]), "sha256": batches[side]["sha256"]}
                         for side in batches}, "projects": {s: str(p) for s, p in projects.items()},
             "verified_project_resource_sources": verified, "pairs": []}
    for pair in prepared:
        pair_dir = output / f"map_{pair['map_index']}_{pair['after_family']}"
        pair_dir.mkdir()
        entry = {"root_seed": pair["key"][0], "map_index": pair["map_index"],
                 "after_family": pair["after_family"], "shared_plot_bounds": pair["bounds"], "sides": {}}
        for side, (data, receipt, origin, projected, used, trajectory) in pair["sides"].items():
            folder = pair_dir / side
            folder.mkdir()
            origin.update(side=side, scope=SCOPE, source_project=str(projects[side]),
                          producer_sha256=producer_sha, reused_producer_sha256=base_sha)
            entry["sides"][side] = render(base, projected, data, receipt, projects[side],
                                         folder, origin, pair["bounds"], used, trajectory)
        (pair_dir / "index.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
        index["pairs"].append(entry)
    require(digest(Path(__file__).read_bytes()) == producer_sha and digest(BASE_PATH.read_bytes()) == base_sha,
            "Plotting producer changed during execution")
    for side in batches:
        require(digest(batches[side]["path"].read_bytes()) == batches[side]["sha256"], "Batch changed during execution")
        verify_project_resources(projects[side], frozen_sources[side])
    for pair in index["pairs"]:
        for row in pair["sides"].values():
            for key in ("raw", "receipt", "log"):
                require(digest(repo_file(row["origin"][key]).read_bytes()) == row["origin"][key + "_sha256"],
                        "Selected capture/receipt/log changed during projection")
    (output / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    print("Derived six source-bound static map pairs (12 PNG + 12 SVG); not quality PASS:", output)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, AssertionError, OSError) as error:
        print("REFUSED:", error, file=sys.stderr)
        raise SystemExit(2)
