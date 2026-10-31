#!/usr/bin/env python3
"""Read the actual resource/scene inventory without invoking Godot."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PLAINS = ["patrol_drone", "plains_charger", "plains_diver", "plains_hopper", "plains_sentry", "plains_fan_sentry", "plains_root_bell"]
FOREST = ["forest_bark_beetle", "forest_swing_pod", "forest_lantern", "forest_seed_sentry", "forest_thread_spider", "forest_crossbranch", "forest_bible_weaver"]
BOSSES = ["clockwork_guardian", "bellstrider", "windkeeper", "thorn_guardian", "thorn_queen", "rootbell_guardian_v2", "thorn_queen_v2", "thorn_queen_canopy"]
PREDICATES = {
    "patrol_drone": "Contact-only patrol: actual Motor movement and contact emitter; no authored telegraph/ranged attack.",
    "plains_charger": "EnemyAttackBehavior._can_engage: active target/lifetime, activation range, protected points, unobstructed ray; idle cooldown then telegraph -> attack -> recovery.",
    "plains_diver": "Same _can_engage; diver orbit, committed dive goal and physically bounded return; observe attack, not only telegraph-cancel recovery.",
    "plains_hopper": "Same _can_engage; committed parabolic physical Motor motion toward recorded goal.",
    "plains_sentry": "Same _can_engage; actual EnemyAttackProjectile created at telegraph completion.",
    "plains_fan_sentry": "Same _can_engage; actual three-angle EnemyAttackProjectile volley.",
    "plains_root_bell": "Same _can_engage plus grounded Player and continuous real static support for _ground_target; pulse_committed/actual pulse requests. Accepted warning hit can cancel before attack.",
    "forest_bark_beetle": "Target ahead of committed facing, abs vertical offset <60 and _can_engage. ForestBarkDamageable rejects shield-front shots; real rear/steep-angle shots required.",
    "forest_swing_pod": "Contact-only continuous authored pendulum; swing/turn phases; real obstruction blocks. No invented ranged attack/telegraph requirement.",
    "forest_lantern": "Contact-only moving anchor: dwell -> telegraph -> travel -> dwell. Original fixed destination and real obstruction.",
    "forest_seed_sentry": "_can_engage and grounded Player with real support ray; committed seed arc -> actual temporary zone.",
    "forest_thread_spider": "configure_line(start,end) required; _can_engage, clear physical finite segment, safe protected points; telegraph/extend/hold/retract/recovery.",
    "forest_crossbranch": "configure_shores(exact two supported Rect2 endpoints) required. rest -> telegraph -> flight -> actual supported landing -> settle; contact hazard, not projectile shooter.",
    "forest_bible_weaver": "configure_strands(two distinct-height upper/lower rows) required; _can_engage, clear/safe line, unchanged rooted home; telegraph/extend/hold/retract/recovery with alternating entrance.",
}


def file_info(path):
    text = (ROOT / path).read_text()
    return {"path": path, "sha256": hashlib.sha256(text.encode()).hexdigest(), "fields": dict(re.findall(r"^([A-Za-z_]\w*) = (.+)$", text, re.M))}


def scene_info(path):
    text = (ROOT / path).read_text()
    resources = {ident: resource for resource, ident in re.findall(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', text)}
    output = {}
    for block in re.split(r"(?=\[node )", text):
        match = re.match(r'\[node name="([^"]+)"[^\]]*\]', block)
        script = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
        if match and script:
            output[match.group(1)] = resources[script.group(1)].removeprefix("res://")
    return output


def inventory():
    ordinary = []
    renderer_chains = []
    for ident in PLAINS + FOREST:
        scene = f"scenes/enemies/{ident if ident in FOREST else 'patrol_drone'}.tscn"
        definition = file_info(f"resources/enemies/{ident}.tres")
        hosts = scene_info(scene)
        chains = ["scene", "underworld"] if ident in PLAINS else ["scene"]
        if ident == "plains_root_bell":
            chains.append("root_bell")
        for chain in chains:
            renderer = {"underworld": "game/presentation/actors/underworld_plains/underworld_enemy.gd", "root_bell": "game/enemies/presentation/root_bell_presentation.gd"}.get(chain, hosts["Presentation"])
            renderer_chains.append({"id": ident, "chain": chain, "scene": scene, "host": "Presentation", "renderer": renderer, "installer": "game/presentation/actors/underworld_plains/underworld_actor_installer.gd" if chain == "underworld" else ("game/world/levels/providers/generated_demo_stage.gd:_spawn_enemies_from_plan" if chain == "root_bell" else None), "formal_art_metadata": "forest_bible_actor_art=true" if ident in FOREST else ("underworld_formal_style=true" if chain == "underworld" else None)})
        ordinary.append({"id": ident, "group": "forest" if ident in FOREST else "plains", "definition": definition, "scene": scene, "components": hosts, "attack_predicate": PREDICATES[ident], "terminal_policy": "persistent-corpse-with-save" if ident in ("plains_charger", "plains_diver") else "existing species death policy; report actual retained/dismissed body separately", "status": "inventory-only; no actual recording or human approval implied"})
    bosses = []
    for ident in BOSSES:
        scene = f"scenes/bosses/{ident}.tscn"
        modern = ident in ("rootbell_guardian_v2", "thorn_queen_v2", "thorn_queen_canopy")
        metadata = "forest_bible_actor_art=true" if ident in ("rootbell_guardian_v2", "thorn_queen_canopy") else ("underworld_formal_style=true" if ident in ("bellstrider", "windkeeper") else None)
        bosses.append({"id": ident, "scene": scene, "components": scene_info(scene), "definition": file_info(f"resources/bosses/{ident}.tres"), "formal_art_metadata": metadata, "activation": "bind_duel(real factory geometry, PlayerController, FrameDamagePolicy, DemoLifetime), configure_arena, activate" if modern else "configure_arena(real PlayerMotor), activate; Windkeeper bind_stage_geometry for actual bridge lifecycle", "attack_predicate": "Original mode/clock/ground support/receiver eligibility; no core_open, HP or mode override allowed", "status": "inventory-only; full fight unverified"})
    return {"task": "ENEMY-ALL-02", "ordinary_species_count": len(ordinary), "ordinary_renderer_chain_count": len(renderer_chains), "boss_scene_count": len(bosses), "runtime_boss_definition_combinations": 9, "ordinary": ordinary, "renderer_chains": renderer_chains, "bosses": bosses, "boss_formal_definition_override": {"scene": "scenes/bosses/windkeeper.tscn", "definition": file_info("resources/bosses/windkeeper_storm.tres"), "consumer": "game/world/levels/providers/plains_region_stage.gd:55", "difference": "36 HP, continuous combat; default scene is legacy 12 HP gated core"}, "orphan_boss_resource": {"path": "resources/bosses/plains_bell_warden.tres", "scripts_consumer_found": False, "scope": "Not counted as an additional admitted species"}, "development_prototypes": [{"id": "candidate_lure_guard", "recipe": "experiments/generation/module_enemy_prototypes.gd:setup", "base_definition": "resources/enemies/plains_charger.tres", "renderer": "game/enemies/presentation/prototype_enemy_presentation.gd", "receiver": "game/enemies/prototype_enemy_damageable.gd", "behavior": "game/enemies/behaviors/enemy_attack_behavior.gd", "attack_predicate": "Original charger predicate; guard rejects front shots outside actual recovery", "admission": "development candidate, excluded from formal pool and save schema"}, {"id": "candidate_crosswind_moth", "recipe": "experiments/generation/module_enemy_prototypes.gd:setup", "base_definition": "resources/enemies/plains_sentry.tres", "renderer": "game/enemies/presentation/prototype_enemy_presentation.gd", "receiver": "game/enemies/prototype_enemy_damageable.gd", "behavior": "game/enemies/behaviors/prototype_moth_behavior.gd", "attack_predicate": "Original sentry engage + two time-separated locked volley lanes and physical orbit", "admission": "development candidate, excluded from formal pool and save schema"}], "scope": "Static actual scene/definition/installer inventory. 22 counts host chains, not 22 independent species. Metadata-gated formal body selection is listed explicitly. No visual or battle completion claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(inventory(), indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
