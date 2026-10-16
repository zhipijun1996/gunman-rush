"""Validate the proposed world design, not runtime generation or story delivery."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "docs/world_regions.json"


def validate_framework(data, contract):
    """Six chosen stages, sixteen designed regions, one implemented region."""
    errors = []
    formal = contract.get("formal_run", {})
    design = contract.get("world_design", {})
    if formal.get("regions_per_run") != 6 or data.get("regions_per_run") != 6 or design.get("stage_count") != 6:
        errors.append("Confirmed run has six stages, not sixteen sequential regions")
    if (design.get("region_pool_count") != 16 or data.get("region_pool_count") != 16
            or len(data.get("regions", [])) != 16):
        errors.append("Confirmed design pool must contain sixteen actual registry entries")
    if formal.get("implemented_regions") != ["plains"] or formal.get("profile_id") != "formal_plains_region":
        errors.append("Only plains has the formal runtime consumer; design does not open future regions")
    if "biome_count" in formal or "formal_region_count" in data:
        errors.append("Ambiguous legacy total-region fields must stay in historical provenance only")
    if design.get("framework_status") != "confirmed" or data.get("framework_status") != "confirmed":
        errors.append("Confirmed six-stage/sixteen-region framework cannot revert to an unspecified proposal")
    for legacy in [design.get("legacy_total_region_plan", {}), data.get("legacy_total_region_plan", {})]:
        if (legacy.get("region_count") != 6 or legacy.get("status") != "superseded_total_region_plan"
                or not re.fullmatch(r"[0-9a-f]{64}", str(legacy.get("prior_file_sha256", "")))):
            errors.append("Keep the old six-region total explicitly historical with its original file hash")
    authority = data.get("framework_authority", {})
    if authority != design.get("authority") or authority.get("path") != "docs/design/player_actions/regions_v0.3.md":
        errors.append("Framework authorities must agree on the current region design source")
    else:
        source = ROOT / authority["path"]
        if hashlib.sha256(source.read_bytes()).hexdigest() != authority.get("sha256"):
            errors.append("Region framework authority hash changed; review the source migration")
        matrix = []
        for line in source.read_text().splitlines():
            if re.match(r"\| S[1-6] \|", line):
                cells = [cell.strip().replace("**", "") for cell in line.strip().strip("|").split("|")]
                matrix.append((cells[1], int(cells[0][1:])))
        actual = [(row.get("working_name"), row.get("layer")) for row in data.get("regions", [])]
        if len(matrix) != 16 or sorted(matrix) != sorted(actual):
            errors.append("Registry names/stages must match the sixteen-region authority matrix")
    return errors


def validate(path=CATALOG, contract_path=None):
    errors = []
    try:
        data = json.loads(Path(path).read_text())
        if data.get("schema_version") != 1 or data.get("kind") != "design_catalog_not_runtime_configuration":
            return ["World catalog must be explicitly design-only, schema 1"]
        if data.get("world_plan_status") != "tentative" or data.get("title_status") != "working_name":
            errors.append("Candidate connections/content and working names must not be silently finalized")
        source = data["source"]
        source_path = ROOT / source["path"]
        if not source_path.resolve().is_relative_to((ROOT / "docs/references").resolve()):
            return ["World reference must be a repository-relative source document"]
        text = source_path.read_text()
        if hashlib.sha256(source_path.read_bytes()).hexdigest() != source["sha256"]:
            errors.append("Imported user handoff hash changed")
        if data.get("formal_stages_per_region") != 2 or data.get("formal_boss_stage") != 2 or data.get("formal_maps_per_region") != 2 or data.get("formal_map_structure") != "connected_region":
            errors.append("Each formal region has two connected maps, mini Boss first and region Boss second")
        contract = json.loads(Path(contract_path or ROOT / "docs/design_contract.json").read_text())
        errors.extend(validate_framework(data, contract))
        regions = data["regions"]
        by_id = {r["id"]: r for r in regions}
        by_name = {r["working_name"]: r for r in regions}
        if len(regions) != 16 or len(by_id) != 16 or len(by_name) != 16 or data.get("proposed_region_pool_count") != 16:
            return errors + ["Expected sixteen unique design regions; content remains unimplemented"]
        if data.get("proposed_layer_count") != 6:
            errors.append("Current proposed network has six layers")
        first, terminal = data["first_region_id"], data["terminal_region_id"]
        if first != "windchime_plains" or terminal != "world_clockheart":
            errors.append("World must begin in plains and converge on the proposed clockheart")
        expected = {}
        for line in text.split("### 3.1")[1].split("### 3.2")[0].splitlines():
            cells = [c.strip() for c in line.split("|")[1:-1]]
            if len(cells) == 3 and cells[1].isdigit():
                expected[cells[0]] = (int(cells[1]), [] if cells[0] == "世界钟心" else cells[2].split("、"))
        if set(expected) != set(by_name):
            errors.append("Region names differ from the imported proposed network")
        incoming = {key: 0 for key in by_id}
        for region in regions:
            layer = region["layer"]
            if type(layer) is not int or not 1 <= layer <= 6:
                errors.append("Invalid layer: " + region["id"])
            if region.get("runtime_available") is not False:
                errors.append("Unimplemented world regions must not become runtime-available")
            expected_status = "plains_demo_skin_only" if region["id"] == first else "planned"
            if region.get("content_status") != expected_status:
                errors.append("Do not confuse candidate skins with complete region content")
            for field in ("visual_anchor", "mechanic_ideas", "story_anchor"):
                if not isinstance(region.get(field), str) or not region[field].strip():
                    errors.append("Missing region anchor " + field)
            destinations = region["next_region_ids"]
            if len(destinations) != len(set(destinations)):
                errors.append("Duplicate region edge: " + region["id"])
            for target in destinations:
                if target not in by_id:
                    errors.append("Unknown region destination: " + str(target))
                else:
                    incoming[target] += 1
                    if by_id[target]["layer"] != layer + 1:
                        errors.append("Normal region edges cannot skip layers or cycle")
            if region["working_name"] in expected:
                expected_layer, next_names = expected[region["working_name"]]
                actual_names = [by_id[t]["working_name"] for t in destinations if t in by_id]
                if layer != expected_layer or actual_names != next_names:
                    errors.append("Region whitelist differs from original proposal: " + region["id"])
            if not destinations and region["id"] != terminal:
                errors.append("Proposed region is a dead end: " + region["id"])
        if by_id[terminal]["next_region_ids"] or by_id[first]["layer"] != 1 or by_id[terminal]["layer"] != 6:
            errors.append("Invalid start/terminal layer or terminal exits")
        if incoming[first] or any(not count for key, count in incoming.items() if key != first):
            errors.append("Every non-start region must have an incoming connection")
        def reaches_terminal(key, visiting):
            if key == terminal:
                return True
            if key not in by_id or key in visiting:
                return False
            targets = by_id[key]["next_region_ids"]
            return bool(targets) and all(reaches_terminal(t, visiting | {key}) for t in targets)
        if any(not reaches_terminal(key, set()) for key in by_id):
            errors.append("Every proposed path must lead to the terminal without cycles")
        beats = data["story_beats"]
        if len(beats) != 6 or [b["layer"] for b in beats] != list(range(1, 7)):
            errors.append("All six proposed layers need story coverage")
        if any(not b.get("required_information") or b.get("delivery_policy") != "mandatory_path_or_equivalent_fallback" for b in beats):
            errors.append("Core story cannot depend exclusively on rare rooms")
        for route in data["example_routes"]:
            if len(route) != 6 or route[0] != first or route[-1] != terminal:
                errors.append("Invalid complete example route")
            elif any(b not in by_id.get(a, {}).get("next_region_ids", []) for a, b in zip(route, route[1:])):
                errors.append("Example route violates whitelist")
    except (OSError, ValueError, KeyError, TypeError, IndexError, AttributeError) as error:
        errors.append("Invalid world design: " + str(error))
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    problems = validate(parser.parse_args().catalog)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)
    print("PASS: confirmed 16-region pool / six-stage framework, candidate 29 whitelist edges, source hashes and plains-only runtime boundary. Runtime not tested.")
