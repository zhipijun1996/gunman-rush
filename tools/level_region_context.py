#!/usr/bin/env python3
"""Extract cited region design inputs. Never grants abilities or runs a generator."""
import argparse
import hashlib
import itertools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGIONS = "docs/bible/regions.md"
WEAPONS = "docs/data/weapons.md"
ENTRY = "docs/data/player_actions.md"
WORLD = "docs/bible/world_regions.json"


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


def _gd_source_lines(source):
    """Admit single-line quoted literals/comments; reject unsupported continuations.

    This finite source observer intentionally does not interpret multiline
    strings. Reject them before looking for any function or inheritance edge.
    """
    lines = []
    for line in source.lines:
        quote = None
        index = 0
        while index < len(line):
            char = line[index]
            if quote is not None:
                if char == "\\":
                    index += 2
                    continue
                if char == quote:
                    quote = None
            elif char == "#":
                break
            elif char in ("'", '\"'):
                if line[index:index + 3] == char * 3:
                    return None
                quote = char
            elif char == "\\":
                return None
            index += 1
        if quote is not None:
            return None
        lines.append(line[:index].rstrip())
    return lines


def _gd_function_has_statements(source, name, statements):
    """Bounded source observation, not execution/reachability or a GDScript parser.

    Match complete statements inside one named top-level function, in order.
    Unsupported source shapes fail closed and require a new source review.
    """
    lines = _gd_source_lines(source)
    if lines is None:
        return False
    starts = [i for i, line in enumerate(lines)
              if re.match(r"^(?:static )?func " + re.escape(name) + r"\(", line)]
    if len(starts) != 1:
        return False
    start = starts[0] + 1
    end = next((i for i in range(start, len(lines))
                if lines[i] and not lines[i][0].isspace()), len(lines))
    observed = iter(line.strip() for line in lines[start:end] if line.strip())
    return all(any(line == expected.strip() for line in observed)
               for expected in statements)


def _forest_consumer_observed(root, app):
    """Follow the existing forest provider/plan/runtime source edges, not a registry."""
    provider = Source(root, "game/world/levels/providers/forest_level_provider.gd")
    adapter = Source(root, "game/world/levels/providers/legacy_region_plan_adapter.gd")
    configured = Source(root, "game/world/levels/providers/generated_demo_stage.gd")
    stage = Source(root, "game/world/levels/providers/thorn_forest_region_stage.gd")
    inherited = Source(root, "game/world/levels/providers/plains_region_stage.gd")
    runtime = Source(root, "game/world/levels/level_runtime.gd")
    assembler = Source(root, "game/world/generation/thorn_forest_region_assembler.gd")
    generator = Source(root, "game/world/generation/thorn_forest_region_generator.gd")
    observed = all((
        _gd_function_has_statements(app, "start_debug_region", [
            "_debug_region = region", "var accepted := start_demo(seed_value,true)"]),
        _gd_function_has_statements(app, "_select_next_region", [
            "active_region_id = id",
            "director.continue_region(_progression_token,id,_next_id(\"enter_thorn_forest\"),campaign.abilities)"]),
        _gd_function_has_statements(app, "_load_stage", [
            "var request := LevelRequest.new()", "request.region_id=active_region_id",
            'var loaded := ForestLevelProvider.load_level(request) if active_region_id==&"thorn_forest" else PlainsLevelProvider.load_level(request)',
            'stage = ThornForestRegionStage.new() if active_region_id == &"thorn_forest" else PlainsRegionStage.new()',
            "(stage as GeneratedDemoStage).configure_level(loaded.plan,loaded.legacy_generated,controller.motor.tuning)"]),
        _gd_function_has_statements(provider, "load_level", [
            "var generated := ThornForestRegionGenerator.new().generate(seed_value,request.tuning,request.map_index,capabilities)",
            "var result := LegacyRegionPlanAdapter.generated(generated,request.tuning,request.map_index,true)", "return result"]),
        _gd_function_has_statements(adapter, "generated", [
            "var result := geometry(data.manifest,tuning,forest_region)", "var plan := result.plan", "return result"]),
        _gd_function_has_statements(adapter, "geometry", [
            "var plan := LevelPlan.new()", "if forest_region:", "var forest := ForestLevelGeometry.new()",
            "plan.forest=forest", "result.plan=plan", "return result"]),
        _gd_function_has_statements(configured, "configure_level", ["level_plan=plan"]),
        "extends PlainsRegionStage" in (_gd_source_lines(stage) or []),
        "extends GeneratedDemoStage" in (_gd_source_lines(inherited) or []),
        _gd_function_has_statements(stage, "_ready", [
            "var built := LevelRuntime.assemble(self,level_plan,region_state,generated.manifest)"]),
        _gd_function_has_statements(runtime, "assemble", [
            "var assembler: PlainsRegionAssembler = ThornForestRegionAssembler.new() if plan.forest!=null else PlainsRegionAssembler.new()",
            "parent.add_child(assembler)", "var result := assembler.build_plan(plan,presentation)", "return result"]),
        _gd_function_has_statements(assembler, "build_plan", ["level_plan=plan", "forest_geometry=plan.forest"]),
        _gd_function_has_statements(generator, "generate", [
            'return generate_version(str(capability_snapshot.get("forest_content_version",VERSION)),seed_value,tuning,map_index,capability_snapshot)']),
    ))
    return observed, [source.ref() for source in (provider, adapter, configured, stage, inherited, runtime, assembler, generator)]


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
                  "experiments/motion/action_studio.gd", "tests/fixtures/campaign_fixture.tscn",
                  "tests/fixtures/campaign_fixture.gd", "game/player/player.tscn",
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
    """Bounded fixed-world region navigation, not a runtime grant or route plan."""
    root = Path(root)
    catalog = Source(root, WORLD)
    rows = json.loads(catalog.text)['regions']
    matches = [r for r in rows if region_id in (r['id'], r['working_name'], r['code'], r['legacy_region_key'])]
    if len(matches) != 1:
        raise ContextError(f"Unknown region: {region_id}")
    row = matches[0]
    source = json.loads(catalog.text)['canonical']
    world = json.loads((root / source).read_text())
    region = next(r for r in world['regions'] if r['id'] == row['id'])
    return {'schema_version': 2, 'kind': 'fixed_world_context_not_runtime_configuration',
            'region_id': row['id'], 'code': row['code'], 'name': row['working_name'],
            'design': {k: region[k] for k in ('play', 'time_state', 'split', 'story', 'clock_repair')},
            'room_ids': [r['id'] for r in world['rooms'] if r['region'] == row['code']],
            'authority': source, 'canonical_sha256': hashlib.sha256((root / source).read_bytes()).hexdigest(), 'sources': [catalog.ref()],
            'implementation': {'fixed_world_runtime': False, 'validation_status': 'not_playtested',
                               'current_state_source': 'docs/project/current_state.md'},
            'next': 'python3 tools/world/room_context.py <room_id>; add --contract only for target-room construction'}


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
