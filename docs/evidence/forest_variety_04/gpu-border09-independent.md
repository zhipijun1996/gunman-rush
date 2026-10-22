# Independent shared-terrain GPU equivalence / style rebind09

Decision: ALLOW an explicit versioned style-v4 source rebind for the equivalent boundary performance optimization only. Preserve v3's original bytes, hash and conclusions. This is continuity of the same shared material family; it does not approve new v18 module art, gameplay or the browser timeout fix.

Actually used view_image on eight separate original PNGs (four before/after pairs) under `/tmp/gunman-forest-v18/gpu-border09`: plains_map1_reference.png, map1_thorn_mouth.png, map2_thorn_elbow.png and matrix/golden_2.png. Plains grass/stone top and vertical edges retain the same pixel treatment; Forest mouth and elbow retain the same thorn-covered platforms, pass-through ledges and family relation; the matrix preserves its concave/convex outline and shading. No new seam, material or thorn silhouette difference is visible. These are explicitly staged actual App compositions / a small native GPU matrix, not traversal captures. I did not visually inspect the other seven pairs.

Independently decoded every one of the11 pairs to RGBA and compared complete byte buffers: all equal. Also independently hashed PNG files: each exactly matches its counterpart and recorded receipt SHA. This includes both formal Plains references, four actual v15 Forest thorn views and five original matrix views. Actual PNG names/hashes and viewed subset are bound in `/tmp/forest-v18-gpu-border09-independent.json`.

Source isolation: independently recovered each pass's3712-file inventory from baseline a6e7cfb4c9b50b22a4a643afcb98fbe7550d5d64 plus six exact stored changed-byte files, hashing every remaining Git baseline blob. Before/after within each pass are equal. Between passes the sole difference is scripts/art/plains_terrain_borders.gd:

- original:240098cce12d435c902cb85c114dd302415f0d639f848fa89769c90581f8391d
- optimized:e1f710bfe7f125bf64245406db0b07d70def3a3ee591309cfb53196cb45f2d34

The original native matrix test, Underworld renderer and shader are unchanged from baseline. Each completed matrix result has5 cases/239910 checks/zero failures/gpu=true. Inspected original guard: real TileMap consumer, no added CollisionObject2D, sampled exact geometry coverage, canonical edges/corners/core-cells/adapter pieces, GPU split/reorder/duplicate equality and no outside-alpha spill. Native alpha inside rounded source corners is measured/logged, not asserted fully opaque; this is the retained original behavior, not a newly weakened condition. The wrapper's additional reference-equivalence run supplements the original native check.

This complements the prior border08 independent proof: genuine frozen old oracle, complete ordered-plan equality and two v18 world geometry comparisons. It supports rebinding boundary_sides in a new version, with explicit affected consumers shared formal Plains/Forest renderer, exact old/new hashes, native08 and GPU09 evidence, and no claim of a new global art direction. It must not silently mutate v3 or relabel old v18 ART_REWORK as approved.

Receipt exit0, two source-stable passes,48.5617s overall. Source/Python reproduction: `/tmp/forest-v18-gpu-border09-independent.py`. No engine, browser or source changes performed by this reviewer. App assembly timing and browser loading/click recovery need their own actual evidence; the supplied perf07/08 timings are not independently re-audited in this bounded GPU task.
