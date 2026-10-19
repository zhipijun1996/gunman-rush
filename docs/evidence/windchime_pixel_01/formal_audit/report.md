# Formal Plains terrain / presentation integration audit

Reviewer: `/root/formal_terrain_audit`, independent read-only production audit, 2026-10-19. Scope: source consumers + one genuine generated-definition inventory; no old art images inspected, no production edits, no aesthetic acceptance or route-completion claim.

## Measured geometry

Godot 4.7.2, `bash tools/godot.sh --headless --path . --script res://build/pixel-formal-audit/geometry_inventory.gd`, exit 0 with clean log. Seed `level-design-v2-baseline/08`, `PlainsRegionGenerator.root_bell_mode="v3"`, both formal difficulty classes:

| Difficulty | Modules | Static solids | One-way | Moving | Ground supports | Solid bounds all aligned to 32 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| intro | 60 | 55 | 74 | 7 | 24 | 0 |
| advanced | 64 | 50 | 82 | 6 | 24 | 0 |

Minimum sampled solid width 24, height 18 world units. Actual examples `Rect2(-200,18,400,32)`, `Rect2(1560,528,400,32)`; known live floating form `24 × 110`. Not all worlds can be represented by a fixed 32-unit TileMap without changing geometry. This sample is an inventory of one seed in two difficulty classes, not all seeds.

Full output, manifest hashes and reproducer: `geometry_inventory.json`, `geometry_inventory.log`, `geometry_inventory.gd` beside this report.

## Construction and replacement ownership

| Actual source path / function | Responsibility | Safe integration |
| --- | --- | --- |
| `scripts/demo/plains_region_stage.gd::_ready` lines 17–30 | Actual formal assembler, manifest, bounds/spawn; two-map stage retained | Preserve generator/assembler/region-state initialization |
| `scripts/generation/plains_region_assembler.gd::build` lines 15–30 | Module definition + offsets; serialized ground-support installation | Preserve geometry and offsets byte-for-byte |
| `scripts/generation/platforming_module.gd::_ready` lines 24–43 | Exact authored StaticBody/RectangleShape per Rect2; one-way group and named CollisionShape2D; old OneWayPaint child | Keep bodies/groups/names. Replace only one-way visual child, identifiable by `platform_index` meta |
| same `::_draw` lines 121 onward | Old static terrain, spikes and surface thorns | `terrain_candidate_preview` hides only solid terrain. Hazards still draw separately; pixel adapters must preserve visible hazard extent |
| `scripts/generation/plains_ground_supports.gd::install` | Exact collision-bearing serialized columns | Hide only its CanvasItem; never delete bodies or regenerate columns for new art |
| `scripts/art/plains_terrain_study.gd::collect_solids` lines 10–18 | All actual static non-one-way slabs + support columns | Best exact-union inventory, already excludes moving/one-way |
| same `::refresh_geometry` lines 19–35 | Detect changed committed geometry; rebuild presentation; observes deferred arena breakage/restoration | Swap visual builder at line 27. Retain observer so removed collision leaves no fake ledge |
| same `::set_candidate` lines 45–52 | Hide old solid draw and supports; enables old moving painted art | New implementation must also supply new moving paint; otherwise this method revives old moving assets |
| `scripts/generation/module_moving_platform.gd::_ready/_physics_process/restore_motion` | AnimatableBody carrier, clock, bell phase, engine platform velocity | Leave physics untouched; attach art in body-local coordinates |
| same `::set_painted_enabled` lines 55–64 | Old exact-rectangle painted moving material | Replace only builder or old painted_art subtree, preserve dimensions and body-local reference |
| `scripts/art/plains_wood_platform_art.gd::build` | One-way old ColorRect, above-surface art extent | Swap presentation with finite-width endpoint-aware pixel wood; respect physical standing y and drop semantics |
| `scripts/generation/plains_region_assembler.gd::_draw` | Closed backside shortcut gate art | Still old consumer after solid replacement; replace draw only, preserve body and opened state |
| `scripts/demo/demo_app.gd::_ready` lines 91–93 | Always creates direct child `PlainsBackground`, CanvasLayer -100 | New three-plane background must replace/hide this actual owner during Plains; do not leave old sky under translucent PNGs |
| `scripts/art/plains_background.gd::_build_shared_environment` | Actual default **two** old independent sources; other legacy 1/3 modes inactive by default | Replace default formal background with three genuinely independent source PNGs and distinct measured speeds |
| `scripts/demo/plains_region_stage.gd::_ready` lines 82–84 | Old PlainsRegionScenery root | Omit/replace entire cosmetic subtree in formal pixel style |
| `scripts/art/plains_region_scenery.gd::_ready` | Depth veil + PlainsRegionComposition + old landmarks | Overlaying new far planes alone leaves these old-world images active |
| `scripts/art/plains_region_composition.gd::_ready` | SemanticLandscape, ConnectedLandscape, observer + older area backdrops | Cosmetic only. Its old spatial/planning code is not required by gameplay |
| `scripts/art/plains_region_scenery.gd::solid_supports/protection` | Pure semantic support and keepout inventory | Can reuse geometry helpers without creating old scenery. Protection covers hazard envelopes, ferry sweeps, area clues, latches, shortcuts, rewards, merchant, enemies, spawn |
| `scripts/art/plains_stage_visual.gd` | Pickups, doors and boss loot, **not** background | Preserve claimed/collected/door logic; reskin textures separately |
| `scripts/demo/plains_region_stage.gd` lines 104–113 | Chest and merchant Sprite2Ds | Separate old sprite consumers; replace assets/visuals without mutating chest receipts or merchant position |
| `scripts/world/shot_latch.gd::_draw/_draw_gate/add_access_bell` | Bell(s), timer/sequence links, gate and access-bell sprite | Separate old art consumer. Keep accepted-shot logic, collision gate/phase/save and relation glyphs |
| `scripts/generation/module_saw_hazard.gd::_draw` | Saw visuals, current definition radius | Replace only drawing; don't suppress hazard visibility or modify hitbox |
| `scripts/bosses/boss_arena_seal.gd::_draw` | Actual closed arena barrier uses old gate source | Separate old consumer; maintain armed/closed state cues and barrier visibility |

`PlainsRegionStage._ready` does not call `GeneratedDemoStage._ready`; its replacement scenery choice can remain formal-only without affecting legacy development fixtures. The parent VISUAL_LAYER constant points at pickup/door visual code only.

## Recommended minimal terrain implementation

Keep the technical 47-mask implementation for grid-native labs/new modules; user now permits dual-grid, but the formal geometry constraint remains independently binding. A fixed-size 16-case dual grid cannot represent the measured off-grid boundaries exactly either.

For this formal visual migration, use a NEW visual-only exact-union pixel renderer. Reuse pure geometry operations `PlainsTerrainBorders.plan`, `occupied`, and optionally `PlainsTileComposer.merge_edges/pieces_from_edges` (copy/extract algorithm into new neutral helper if preloading old class would retain old assets). Derive canonical exposed faces from **all solids after assembly**, not each module in isolation. Interior color/material coordinate is world-based; moving surfaces use body-local coordinates. Clip every draw to exact union, light only exposed top faces, preserve empty cavities/holes and very thin forms. Use quiet two/three-tone fills and sparse texture as explicitly requested.

A genuine dual-grid option for future grid-native modules is 16 corner-occupancy cases on the half-offset presentation grid. It should have explicit cell size/origin and ambiguous diagonal policy. Do not label an arbitrary-rectangle shader or 47 atlas as a dual-grid implementation. Existing off-grid forms need an explicit exact-edge adapter, or a separately authorized geometry/module redesign with real route revalidation. Current task is visual remake and should avoid changing those authored routes.

No new collision in art subtree. Keep whole support union canonical under split/reorder/overlap input transformations. Geometry observer must refresh after boss slabs break, restore and return; art may not leave old silhouettes.

## Validation implications

- Existing `tests/plains_terrain_family_runner.gd` asserts old texture SHA and <=1 semantic pilot. Its old-asset identity assertions will intentionally fail after replacement. Preserve frozen old-consumer regression behind its original explicit mode or record replaced-consumer scope; do not silently delete/relax geometric assertions or claim old art tests passed unchanged.
- New formal tests need actual DemoApp `start_plains`, both maps and saved return; inventory every static, one-way, moving, hazard and gate presentation owner. Compare manifest, tuning hash, collision shapes and clocks before/after style installation. A Lab-only count does not prove formal coverage.
- Geometric cases: short width, height18, 24-wide wall, 24×110 island, long strip, internal shared boundary, L/T, enclosed hole, below-platform gap, off-grid positions, reordered/overlapped/split solids, removed/restored slab. True GPU tests should compare same union under authoring partition changes.
- Three PNG layers: verify distinct resource paths/content hashes and actual visible-in-tree planes, common pixel scale, strict far < middle < near camera coefficients; capture before/after camera moves in x and y and distinguish passive wind from camera parallax. No opaque empty upper layer may hide lower planes. Both finite camera extremes need coverage (do not promise seamless wrapping for non-seamless art).
- Motion: body-local art stays attached while ferry carries real Motor; one-way remains passable from below and supports down+jump. None of these are demonstrated by this inventory probe.
- Preserve all original RNG/resource/save/two-map/Boss services. Decorations use independent coordinate hash/seed and existing full-bounds keepouts.

Verdict: read-only implementation guidance supported by clean generated-definition probe. Formal visual/runtime integration, complete routes, aesthetics, performance, user and device acceptance remain unverified.
