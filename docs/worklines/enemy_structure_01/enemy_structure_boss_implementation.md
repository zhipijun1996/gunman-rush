# Boss presentation/query and creation boundary implementation

Scope: scripts/bosses only. No Godot run, git commit, gameplay numeric/AI/HP/weakpoint/restore/cancel change, image edit or quality approval by this agent. Root coordinates creation consumers and engine verification.

## Actual boundaries

- BossPresentationState: detached constructor deep-copy; read-only public getters; phase_axes/as_dictionary return copies. Carries source, real raw mode/time/domain, combat/route axes, real owner-supplied visual semantic flags and common lifecycle facts. Contains no Node/Resource/controller references.
- BossEncounter/each family now owns presentation_state and presentation_capabilities. BossMotion no longer knows Windkeeper, Rootbell or Queen classes, mode names, warning suffixes or Definition subclasses. It reads only the value snapshot plus its existing accepted health/projectile subscriptions.
- Narrow value queries: Windkeeper intro/core/rune/locked aim/blade angle; old forest heart/ground mark; Rootbell Bell position/radius and original projected throw/pursuit footprint geometry; Queen migration path preview; Canopy living knot label values. Returned paths/rows are newly constructed values, not live combat nodes.
- Rootbell original duel_event remains; a copied dictionary is also sent on presentation_event so the renderer subscribes without casting the Encounter to Rootbell or retrieving its private Bell.
- All owned Boss renderer reads of Encounter private fields are removed. ForestDuel no longer reconstructs gravity/ballistic projections from a mutable Bell; it draws the owner's provided points/footprints.
- Motion bind is same-owner idempotent; owner replacement disposes previous subscriptions/cache. synchronize reconstructs movement/facing baseline and handles a changed health epoch; same epoch does not clear hurt, mode age, warning/recovery/death clocks. All seven actual renderers expose synchronize_presentation for App restore coordination.
- BossFactory RECORDS is the sole finite 8 scene/9 combination path table. create(id) dynamically loads only the selected PackedScene; create_recorded(scene, definition) rejects non-whitelisted pairs. Empty definition explicitly means that allowed scene's default. Instances remain unparented/unready, default shared definition semantics preserved; storm alone applies the same shared Resource override before parenting. Custom Module fixture definitions may still be assigned afterward by their original owner.

## Consumers

Changed owned presentation consumers: BossPresentation (Clockwork); BellstriderPresentation; WindkeeperPresentation (default/storm); ThornForestPresentation (old Guardian/Queen); forest_boss_duel_presentation_v2 (Rootbell); thorn_queen_weave_presentation (Weave); ThornQueenCanopyPresentation. BossArrivalPresentation consumes the intro view.

Root's actual factory migrations observed read-only: DemoStage, GeneratedDemoStage, PlainsRegionStage, ThornForestRegionStage, ModuleBossTrial, ActionStudio. These files are outside this agent's write scope. Root coordinates restore synchronization in App.

## Deliberately non-equivalent concepts retained

1. Clockwork has no native mode. Its state_source=attack_pattern, raw_mode is empty, raw_clock remains the original elapsed pattern clock; derived projectile_warning/patrol IDs preserve prior presentation transitions. Other owners expose their actual mode and unchanged countdown raw values, including negative boundaries.
2. Weave network combat phase and route phase are distinct phase axes. Canopy has its own continuous path section/leg clock; no invented perched/recovery state was added.
3. core_hint_visible is only the pre-existing UI/exposure hint. It is not a damage gate; continuous body damage, old aperture/side/rune rules, contact qualification and original Damageable/Policy remain unchanged.
4. synchronize_presentation is not reset/restore combat and does not erase accepted same-epoch hurt. It does not silently reset every legacy per-leaf fade/form clock; those original terminal policies remain distinct.
5. Rootbell's terminal pending counter settlement and all persistent field pause/restore ownership remain original. New presentation queries never cancel, move, deal damage or change geometry.
6. Art-specific pose selection stays in the corresponding renderer using that owner's snapshot; this is different from a shared helper guessing another family's AI. Existing external PixelFormalActors/Underworld legacy draw helper APIs still receive the public Encounter because those files are outside this agent's ownership. They were not falsely reported converted.
7. The finite Factory intentionally rejects arbitrary paths rather than replacing old save manifests or adding a fallback. Default/storm remains one scene/two definitions, not a ninth species; generation contract paths are unchanged.

## Verification performed (static only)

All scripts/bosses/*.gd parsed with gdtoolkit; git diff --check clean. A function-by-function comparison to HEAD of eight AI/lifecycle owners shows every existing function unchanged, except Rootbell._event adds the isolated presentation_event emission after preserving its original duel_event. New functions are pure query/formatting methods. Existing raw mode/clock/phase/restore/cancel methods are unchanged. rg finds no `(encounter|duel)._` reads in owned Boss presentations and no family type/mode classification in BossMotion.

Engine type checks, all 8 scene/9 resource factory/readonly protocol cases, real signal bind/rebind/epoch/synchronize, original lifecycle/gameplay regression and actual visual equivalence are for root's single engine lease and independent reviewer. This document is not an engine PASS or a claim all monster code is now unified.
