#!/usr/bin/env python3
"""Extract cited region design inputs. Never grants abilities or runs a generator."""
import argparse
import hashlib
import itertools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGIONS = "docs/design/player_actions/regions_v0.3.md"
WEAPONS = "docs/design/player_actions/weapons_v0.8.md"
ENTRY = "docs/design/player_actions/README.md"
WORLD = "docs/world_regions.json"


class ContextError(ValueError):
    """The authority could not be extracted without guessing."""


class Source:
    def __init__(self, root, path):
        self.path = path
        raw = (Path(root) / path).read_bytes()
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.text = raw.decode("utf-8")
        self.lines = self.text.splitlines()
        version = re.search(r"^# .*?\b(V\d+(?:\.\d+)+)\b", self.text, re.M)
        self.version = version.group(1) if version else "content_sha256"

    def ref(self, first=1, last=None):
        return {"path": self.path, "version": self.version, "sha256": self.sha256,
                "line_start": first, "line_end": len(self.lines) if last is None else last}

    def section(self, prefix):
        found = [(i, line) for i, line in enumerate(self.lines) if line.startswith(prefix)]
        if len(found) != 1:
            raise ContextError(f"Expected one authority section {prefix!r} in {self.path}")
        start, heading = found[0]
        depth = len(heading) - len(heading.lstrip("#"))
        end = next((i for i in range(start + 1, len(self.lines))
                    if re.match(r"#{1," + str(depth) + r"} ", self.lines[i])), len(self.lines))
        return {"text": "\n".join(self.lines[start:end]).strip(),
                "source": self.ref(start + 1, end)}


def _clean(value):
    return value.replace("**", "").replace("`", "").strip()


def _matrix(source):
    rows = []
    for line_no, line in enumerate(source.lines, 1):
        if re.match(r"\| S[1-6] \|", line):
            cells = [_clean(cell) for cell in line.strip().strip("|").split("|")]
            if len(cells) != 5:
                raise ContextError(f"Malformed region row {source.path}:{line_no}")
            rows.append(dict(zip(["stage", "name", "hard_lock", "optional_lock", "identity"], cells),
                             source=source.ref(line_no, line_no)))
    if not rows or len({row["name"] for row in rows}) != len(rows):
        raise ContextError("Missing or duplicate region matrix rows")
    return rows


def parse_gate(expression):
    """Parse the document's limited boolean notation, rejecting unknown syntax."""
    expression = _clean(expression)
    if expression == "基础跳跃 + R":
        return [["base_jump", "base_recoil"]]
    if expression == "2/3移动":
        return [list(pair) for pair in itertools.combinations(["H", "W", "D"], 2)]
    alternatives = []
    for option in expression.split("/"):
        atoms = [atom.strip() for atom in option.split("+")]
        if any(atom not in {"H", "W", "D", "U1", "U2"} for atom in atoms) or len(set(atoms)) != len(atoms):
            raise ContextError(f"Unsupported/duplicate gate expression: {expression}")
        alternatives.append(atoms)
    if len({tuple(sorted(option)) for option in alternatives}) != len(alternatives):
        raise ContextError(f"Duplicate gate alternatives: {expression}")
    return alternatives


def _facts(section, status):
    return {"status": status, **section}


def _catalog_record_ref(source, region_id):
    match = re.search(r'"id"\s*:\s*' + re.escape(json.dumps(region_id)), source.text)
    if not match:
        raise ContextError(f"Missing catalog record: {region_id}")
    start = source.text.rfind("{", 0, match.start())
    record, length = json.JSONDecoder().raw_decode(source.text[start:])
    if record.get("id") != region_id:
        raise ContextError("Catalog record source location mismatch")
    return source.ref(source.text.count("\n", 0, start) + 1,
                      source.text.count("\n", 0, start + length) + 1)


def _properties(source):
    """Read scalar literals only; this is source inventory, never a Godot eval."""
    result = {}
    for line in source.lines:
        match = re.match(r'(?:@export\s+var\s+)?(\w+)(?:\s*:\s*\w+)?\s*:?=\s*(&?"[^"\n]*"|\d+(?:\.\d+)?|true|false)\s*$', line)
        if match:
            name, value = match.groups()
            result[name] = json.loads(value.removeprefix("&"))
    return result


def _weapon_inventory(root, sources):
    catalog = Source(root, "game/combat/weapons/weapon_catalog.gd")
    definition = Source(root, "scripts/combat/weapon_definition.gd")
    sources.extend([catalog.ref(), definition.ref()])
    ids_match = re.search(r"const IDS: Array\[String\] = \[([^\]]+)\]", catalog.text)
    if not ids_match:
        raise ContextError("WeaponCatalog IDS no longer matches source inventory adapter")
    ids = re.findall(r'"([a-z0-9_]+)"', ids_match.group(1))
    if not ids or len(ids) != len(set(ids)):
        raise ContextError("Empty or duplicate real weapon catalog")
    defaults = _properties(definition)
    inventory = []
    for weapon_id in ids:
        resource = Source(root, f"resources/weapons/{weapon_id}.tres")
        values = {**defaults, **_properties(resource)}
        if values.get("id") != weapon_id or values.get("tier") not in (1, 2, 3):
            raise ContextError(f"Weapon definition mismatch: {weapon_id}")
        inventory.append({key: values.get(key) for key in ("id", "display_name", "tier", "branch", "skill_name")})
        inventory[-1].update({"implementation_status": "source_present_not_execution_proof",
                              "source": resource.ref()})
        sources.append(resource.ref())
    return inventory


def region_registry(root=ROOT):
    """Known catalog names and unambiguous aliases, derived without a copied map."""
    rows = json.loads((Path(root) / WORLD).read_text(encoding="utf-8"))["regions"]
    candidates = {}
    for row in rows:
        for alias in [row["working_name"][-2:], *[part for part in row["id"].split("_") if len(part) >= 4]]:
            candidates.setdefault(alias, set()).add(row["id"])
    return [{"id": row["id"], "name": row["working_name"],
             "aliases": sorted({row["id"], row["working_name"],
                                *[alias for alias, owners in candidates.items() if owners == {row["id"]}]})}
            for row in rows]


def resolve_region_id(request, root=ROOT):
    """Return one explicit region, None if unknown; ambiguous requests fail closed."""
    if not isinstance(request, str) or not request.strip():
        return None
    matches = []
    for row in region_registry(root):
        if any((bool(re.search(r"(?<![A-Za-z0-9_])" + re.escape(alias) + r"(?![A-Za-z0-9_])", request, re.I))
                if alias.isascii() else alias in request) for alias in row["aliases"]):
            matches.append(row["id"])
    if len(matches) > 1:
        raise ContextError("Ambiguous region request: " + ", ".join(matches))
    return matches[0] if matches else None


def region_write_scope(paths, root=ROOT):
    """Classify repository write leases, independently of natural-language intent.

    Canonical catalog IDs cover future regions. Plains/Forest aliases correspond
    to the actual generator/stage/assembler and regional asset consumer families;
    shared directories/consumers require an explicit scope rather than a guess.
    This inventories declared paths only, never walks or hashes the source tree.
    """
    root = Path(root).resolve()
    catalog_path = root / WORLD
    catalog = json.loads(catalog_path.read_bytes()) if catalog_path.is_file() else {"regions": []}
    ids = {row["id"] for row in catalog["regions"]}
    families = {region: {region} for region in ids}
    # These are actual consumer naming families, not request-word aliases.
    for region, names in {"windchime_plains": {"plains", "pixel_plains", "underworld_plains"},
                          "thorn_forest": {"thorn_forest", "forest"}}.items():
        families.setdefault(region, set()).update(names)
    production = ("scripts/generation/", "scripts/demo/", "scripts/art/", "scripts/enemies/",
                  "scripts/bosses/", "scripts/world/", "scenes/", "resources/generation/",
                  "resources/art/", "resources/enemies/", "resources/bosses/", "assets/", "shaders/",
                  # Current homes of the same regional content and scene entry
                  # scopes. Shared player physics, persistence and loadout are
                  # deliberately not blanket regional write permissions.
                  "game/world/generation/", "game/world/components/", "game/world/levels/",
                  "game/presentation/actors/", "game/presentation/effects/", "game/presentation/world/",
                  "game/enemies/", "game/bosses/", "game/progression/home/",
                  "experiments/generation/", "experiments/terrain/art/",
                  "experiments/audio/entries/", "experiments/motion/entries/", "experiments/terrain/entries/", "experiments/platform/entries/",
                  "experiments/audio/audio_ambience_lab.gd", "experiments/audio/audio_home_lab.gd",
                  "experiments/motion/action_studio.gd", "game/application/demo.tscn",
                  "game/application/demo_app.gd", "game/player/player.tscn",
                  "game/player/presentation/demo_aim_guide.gd",
                  "game/world/state/world_context.gd", "game/world/state/world_definition.gd")
    regions, unresolved = set(), []
    for raw in paths:
        relative = Path(raw)
        if relative.is_absolute() or '..' in relative.parts:
            raise ContextError("Region write scope must be repository relative")
        name = relative.as_posix() + ("/" if raw.endswith("/") else "")
        # Ownership is checked across *all* runtime domains before the
        # shared/unknown production-prefix fallback. Regional presentation,
        # item Definitions or a new consumer directory cannot escape this map.
        runtime = name.startswith(("scripts/", "game/", "experiments/", "resources/", "scenes/", "assets/", "shaders/", "config/"))
        parts = [*relative.parts[:-1], relative.stem]
        owners = ({region for region, aliases in families.items()
                   if any(part == alias or part.startswith(alias + "_") for part in parts for alias in aliases)}
                  if runtime else set())
        relevant = [prefix for prefix in production if name.startswith(prefix) or prefix.startswith(name)]
        if not owners and not relevant:
            continue  # Exact shared Player/physics files are not region content.
        # Controller-only asset fixtures without a world catalog have no game
        # consumer identity. Known regional families and generation still bind.
        if not owners and not catalog_path.is_file() and not {"scripts/generation/", "game/world/generation/"}.intersection(relevant):
            continue
        target = root / relative
        if any(p.is_symlink() for p in [target, *target.parents] if p == root or p.is_relative_to(root)):
            raise ContextError("Regional production write path/ancestor cannot be a symlink")
        if owners:
            regions.update(owners)
        else:
            unresolved.append(name)  # Shared leases never guess one region.
    return {"region_ids": sorted(regions), "unresolved_production_paths": unresolved}


def build_region_context(region_id, root=ROOT):
    """Consumer API for route/mission prepare; region ID or exact catalog name."""
    root = Path(root)
    region_doc, weapon_doc, entry, world = (Source(root, path) for path in (REGIONS, WEAPONS, ENTRY, WORLD))
    catalog = json.loads(world.text)
    catalog_rows = catalog.get("regions", [])
    names = {item["working_name"]: item for item in catalog_rows}
    ids = {item["id"] for item in catalog_rows}
    if len(names) != len(catalog_rows) or len(ids) != len(catalog_rows):
        raise ContextError("Duplicate catalog IDs or names")
    rows = _matrix(region_doc)
    if {row["name"] for row in rows} != set(names):
        raise ContextError("Design matrix and world catalog names differ; reconcile authorities")
    selected = [row for row in rows if region_id in (row["name"], names[row["name"]]["id"])]
    if len(selected) != 1:
        raise ContextError(f"Unknown region: {region_id}")
    row = selected[0]
    item = names[row["name"]]
    region_id = item["id"]
    item_ref = _catalog_record_ref(world, region_id)
    if int(row["stage"][1:]) != item["layer"]:
        raise ContextError(f"Stage conflict for {region_id}: matrix vs world catalog")
    sources = [source.ref() for source in (region_doc, weapon_doc, entry, world)]
    detail = region_doc.section(f"### {row['stage']} {row['name']}｜")
    learning = []
    for offset, line in enumerate(detail["text"].splitlines()):
        match = re.match(r"- \*\*([^*]+)\*\*：(.*)", line)
        if match:
            label, text = match.groups()
            number = detail["source"]["line_start"] + offset
            learning.append({"label": label, "text": text, "status": "PROPOSED",
                             "source": region_doc.ref(number, number)})
    if not learning:
        raise ContextError(f"Missing authored learning/identity for {region_id}")
    capability_ids = dict(re.findall(r"\b(H|W|D|U1|U2)=([a-z_0-9]+)", region_doc.text))
    if set(capability_ids) != {"H", "W", "D", "U1", "U2"}:
        raise ContextError("Core ability ID authority incomplete")
    candidate_edges = [(a, b) for a, b in re.findall(r"`([a-z_]+) → ([a-z_]+)`", region_doc.section("### 2.4 ")["text"])]
    if any(a not in ids or b not in ids for a, b in candidate_edges):
        raise ContextError("Candidate edge references unknown region")
    incoming = [r["id"] for r in catalog_rows if region_id in r["next_region_ids"]]
    outgoing = item["next_region_ids"]
    if any(target not in ids for target in outgoing):
        raise ContextError("Catalog edge references unknown region")
    overrides = []
    for line in entry.lines:
        if line.startswith("## 最新"):
            overrides.append(_facts(entry.section(line), "LOCKED_DIRECTION_WITH_PROPOSED_PARAMETERS"))
    # Include linked revised contracts as references, not copied tuning values.
    for override in overrides:
        override["linked_sources"] = []
        for target in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", override["text"]):
            linked = (root / ENTRY).parent.joinpath(target).resolve()
            if not linked.is_relative_to(root.resolve()) or not linked.is_file():
                raise ContextError(f"Missing/unsafe latest authority link: {target}")
            revised = Source(root, linked.relative_to(root.resolve()).as_posix())
            override["linked_sources"].append(revised.ref())
            sources.append(revised.ref())
    inventory = _weapon_inventory(root, sources)
    traversal = Source(root, "game/player/actions/traversal_ability.gd")
    studio = Source(root, "experiments/motion/action_studio.gd")
    app = Source(root, "game/application/demo_app.gd")
    profile = Source(root, "game/world/state/run_profile.gd")
    current = Source(root, "docs/current_state.md")
    sources.extend(s.ref() for s in (traversal, studio, app, profile, current))
    ability_observations = {}
    for symbol, ability_id in capability_ids.items():
        supported = bool(re.search(r'\bid == &"' + re.escape(ability_id) + '"', traversal.text))
        studio_grant = f'traversal.grant(&"{ability_id}")' in studio.text
        ability_observations[symbol] = {"id": ability_id,
            "status": "grant_handler_present" if supported else "no_independent_grant_handler_observed",
            "studio_grant_call_present": studio_grant, "formal_grant": "not_inferred",
            "source": traversal.ref(), "studio_source": studio.ref()}
    resources = []
    for path in ("game/combat/resources/definitions/shot_energy_definition.gd", "game/combat/resources/definitions/combat_energy_definition.gd",
                 "game/combat/resources/state/combat_energy_state.gd", "game/combat/resources/shot_energy_policy.gd",
                 "game/player/actions/jump_ability.gd", "game/loadout/stats/build_state.gd", "game/player/resources/plains_shot_energy.tres",
                 "game/player/resources/combat_energy.tres", "resources/player/traversal.tres", "resources/weapons/motion.tres"):
        source = Source(root, path)
        resources.append({"status": "source_present_not_actor_snapshot", "source": source.ref()})
        sources.append(source.ref())
    consumer_sources = [app.ref(), profile.ref()]
    formal_observed = (region_id == "windchime_plains" and "func start_plains(" in app.text
                       and 'profile_id == &"formal_plains_region"' in profile.text)
    if region_id == "thorn_forest":
        chain = [Source(root, path) for path in (
            "game/world/generation/thorn_forest_region_generator.gd",
            "game/world/levels/providers/thorn_forest_region_stage.gd",
            "game/world/generation/thorn_forest_region_assembler.gd")]
        consumer_sources.extend(source.ref() for source in chain)
        sources.extend(source.ref() for source in chain)
        formal_observed = ("func _select_next_region(" in app.text and "func start_debug_region(" in app.text and "ThornForestRegionGenerator.new().generate(" in app.text
                           and "ThornForestRegionStage.new()" in app.text
                           and "ThornForestRegionAssembler" in chain[1].text)
    from region_creative_direction import bind_region_bible, MissingBible
    try:
        _, bible_binding = bind_region_bible(region_id, root)
        for name in (bible_binding["registry_path"], bible_binding["path"], bible_binding["selection_evidence_path"]):
            sources.append(Source(root, name).ref())
    except MissingBible:
        bible_binding = None
    return {"schema_version": 1, "kind": "extracted_design_input_not_runtime_configuration",
        "region_id": region_id, "name": row["name"], "region_bible": bible_binding,
        "authority_precedence": ["latest_user_instruction", ENTRY, "latest_revised_contracts", REGIONS, WEAPONS, WORLD],
        "design": {
            "stage": {"value": row["stage"], "status": "LOCKED_STAGE_PRINCIPLE", "source": row["source"]},
            "gate": {"expression": row["hard_lock"], "alternatives": parse_gate(row["hard_lock"]),
                     "status": "PROPOSED_MATRIX_SUBJECT_TO_LOCKED_PRINCIPLES", "source": row["source"]},
            "optional_gate": {"text": row["optional_lock"], "status": "PROPOSED_MATRIX_SUBJECT_TO_LOCKED_PRINCIPLES", "source": row["source"]},
            "identity": {"text": row["identity"], "status": "PROPOSED", "source": row["source"]},
            "learning": learning, "region_blueprint": _facts(detail, "PROPOSED"),
            "world_location": {"stage": row["stage"], "incoming": incoming, "outgoing": outgoing,
                               "additional_candidate_edges": [list(edge) for edge in candidate_edges if region_id in edge],
                               "status": "PROPOSED_TOPOLOGY_NOT_REACHABILITY", "sources": [world.ref(), region_doc.section("### 2.4 ")["source"]]},
            "art": {"status": "PROPOSED", "source": item_ref, **{key: item[key] for key in (
                "visual_anchor", "story_anchor", "scene_introduction", "scene_mood", "material_and_light", "module_art_notes", "art_brief_status")}},
        },
        "locked_principles": [_facts(region_doc.section("### 0.1 "), "LOCKED"),
                              _facts(region_doc.section("### 2.1 "), "LOCKED_DIRECTION"),
                              _facts(region_doc.section("### 5.1 "), "REQUIRED_VALIDATION_NOT_PROOF")],
        "capability_ids": {"values": capability_ids, "status": "PROPOSED_PERSISTENCE_IDS_RUNTIME_CHECK_REQUIRED", "source": region_doc.section("## 1. ")["source"]},
        "overrides": overrides,
        "weapon_context": {"source_inventory": inventory,
            "selection": "one_current_weapon_no_combined_branch_capabilities",
            "evolution_tree": _facts(weapon_doc.section("## 1. "), "LOCKED_EVOLUTION_DIRECTION_LV3_DETAILS_PROPOSED"),
            "rules": [_facts(weapon_doc.section("### 0.1 "), "LOCKED_DIRECTION"),
                      _facts(weapon_doc.section("### 0.2 "), "LOCKED_DIRECTION"),
                      _facts(weapon_doc.section("### 0.3 "), "OPEN"),
                      _facts(weapon_doc.section("## 5. "), "PROPOSED_ENCOUNTERS_REQUIRE_PHYSICS_PROOF")]},
        "implementation": {"formal_region": "consumer_present_in_source" if formal_observed else "no_formal_consumer_observed",
            "runtime_available": None, "runtime_available_reason": "static_extraction_does_not_run_or_grant_anything",
            "catalog_runtime_available": item.get("runtime_available"), "catalog_flag_is_authoritative": False,
            "formal_consumer_sources": consumer_sources, "current_state_source": current.ref(),
            "abilities": ability_observations, "resource_and_state_sources": resources,
            "validation_status": "unverified", "equipment_capacity": "one_current_weapon_inventory_capacity_not_inferred"},
        "sources": sorted({(ref["path"], ref["sha256"]): ref for ref in sources}.values(), key=lambda ref: ref["path"]),
        "required_next_steps": ["apply_latest_overrides_before_authored_blueprints", "capture_actual_entry_capabilities_and_single_weapon",
            "prove_each_gate_alternative_with_real_motor_and_resources", "review_scene_composition_and_device_inputs",
            "keep_future_region_out_of_formal_runtime_until_admission"]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    context = build_region_context(args.region)
    content = json.dumps(context, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContextError, OSError, KeyError, ValueError) as error:
        raise SystemExit(f"Region context rejected: {error}")
