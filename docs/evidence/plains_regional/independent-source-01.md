# Independent source audit — regional production baseline

Reviewer `regional_review`, read-only production scope. Baseline PR85 `148d9251`; this review precedes new native captures and does not judge unseen pixels. Applicable existing gameplay-reviewer Skill read; no Godot execution, image creation, production or forest writes.

## Actual consumer split

`DemoApp._load_stage` selects `plains_place_plan.gd` for the explicit places candidate before the formal `generated_plains` branch. The candidate does **not** invoke formal `PlainsRegionGenerator`: its manifest describes three finite places, empty reward/pickup lists, no actual merchant, and an off-map1x1 boss rectangle. Its preserved source-derived geometry and consumer checks are useful, but its35-point trace cannot establish a complete exploration region.

Formal `PlainsRegionGenerator` already creates15/18-area footprints, Seed-selected topology families, cycles, optional challenge routes, backside shortcuts, family-specific one-way drops, tutorial prefix, fixed reward budgets, merchant/recovery convergence and real Boss arena. The semantic graph, inline/existing module assembler, region-state and capability contracts should be reused rather than reproduced as a second regional gameplay engine.

## Production bottlenecks visible in source

1. Formal world embedding is computed from phrase widths and terrace rows before foreground artistic expressibility is considered (`plains_region_generator.gd` phrase-clearance block). Junctions then receive rectangle floors and connections receive authored module rectangles. Post-hoc painting cannot choose continuous regional masses or preserve intentional voids if the reserved space is already incompatible.
2. `PlainsTerrainStudy.collect_solids` gathers physical rectangles then invokes `PlainsTerrainFamilySampler.build`. Existing union/boundary logic is reusable geometric machinery, but aggregate rectangle validity is not evidence of a good landform, and silent presentation fallback must not be reported as successful candidate art.
3. `PlainsRegionComposition` adds semantic/connected landscape and local backdrops after layout. Multiple prior consumers may overlap artistic authority; a new region plan needs one explicit candidate-owned actual consumer branch, not merely another layer of metadata.
4. PR85 proves source/geometry coincidence and limited attachments, not whole-map composition. Its shared scaled silhouettes are insufficient evidence for continuous cliffs, shafts, roof/underside relationships and negative-space variation across an exploration graph.

## Required counterexamples for this experiment

- Two Seeds must differ in actual graph adjacency/direction or genuinely distinct branch/cycle structure, not only phase/hash/place order. Archive graph and actual geometry separately.
- Whole-map landform/layer overview must be captured from Godot-rendered consumers, with topology/route overlay clearly identified as diagnostic, not normal-camera art. Normal-camera moving windows remain necessary for repetition, actor readability and joins.
- Openings needed for shafts, shortcuts and branches must stay visually empty as well as physically traversable. Whole-mass fill must not create false walls/standing ledges or conceal moving hazards.
- Global color, rhythm, landmarks and layer assignments must influence rendered nodes. Unconsumed plan metadata cannot pass.
- Unsupported terrain/asset combinations must reject, regenerate locally, or visibly remain failed; no hidden bare rectangles or automatic historical assets as artistic acceptance.
- Source-based whole-bank duplication per old module is still premade island assembly, even when physics is exact. Approval requires a new regional volume/connection method with actually viewed results.

## Present decision

**UNVERIFIED** for new regional implementation/art/playability pending frozen native captures, source-bound manifests, actual consumer inventory, two graph-distinct Seeds, whole-map/layer view and route evidence. No expansion approval. Prior PR85 finite-chain results retain only their original limited scope; no full-movie playback, listening, manual play, user preference or device validation performed by this reviewer.
