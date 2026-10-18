# Independent projection causality limit — source46c3c099

Reviewer `regional_review`, read-only production, no new Godot execution or art iteration. Frozen source `46c3c0993b2ea69293f60161a1c2a95cc6677942`:

- `scripts/art/plains_regional_composer.gd`: `81a1e50632497b192304e386c343d7310c71f90b512464f8c18536cb172b8f2e`
- `shaders/plains_regional_ground.gdshader`: `bd52409a0c8a8691217a9cc72031ffbb7c466f5c2d9c1f81fbdfe8d75f212191`

**Source proves the present method does not guarantee globally continuous vertical material coordinates.** `_bounded_chunks` partitions large world polygons into1024wide pieces; hole decomposition may first split a body into original rectangles. `_build_terrain` recomputes each piece's bounds, filters its `exposed_tops` by those local bounds (x±350, vertical top cutoff at bounds.y−450), and sends `source_surface=bounds.position` to its own material.

The shader uses global-coordinate-shaped VERTEX x for horizontal phase, but vertical UV is the nearest distance to **that material's selected top set**. If no qualifying top is found, depth resets to `world_pixel.y−source_surface.y`, whose origin is piece-dependent. Adjacent pieces can have different selected top sets or fallback origins. Even where their horizontal phase matches, their vertical sample can differ. Tracing a common global collision boundary and using one PNG does not remove that dependence. The comment claiming continuity “across every source rectangle and union seam” therefore exceeds what the implementation establishes.

This also exposes a conceptual limitation independent of partition seams: nearest-top scalar distance is not a directed surface/face coordinate system. Shoulders, side faces, undersides and connected core can switch nearest top or mirrored core phase without expressing the intended geological structure. More texture variants do not by themselves repair that parameterization.

First source-bound movie e450 frame8400/140s, already actually viewed in independent-seeds, shows a horizontal material break and vertical smearing on the deep right face. **That observation is consistent with the limitations, but this source inspection does not prove chunk-local top filtering is its sole traced cause.** Core mirroring, selected-face depth and initial painting can also contribute. There was no per-fragment/chunk-ID/UV instrumentation identifying the exact culprit; do not present this as a completed pixel causal experiment. No claim every chunk seam is visible or every layout fails for precisely this reason.

Next representation should jointly define regional mass/void geometry and shared surface/face parameterization, including explicit top-to-shoulder-to-wall/core relationships. Shared coordinates or interpolants must remain invariant when the SAME body is partitioned for rendering; compare different legal render partitions of unchanged geometry as a diagnostic. That is an implementation-method question, not a request for more dressing, and it does not supersede the larger macro-embedding/art rejection.

**RETHINK projection/face grammar; no new artistic acceptance.** Existing physical/source/installed-foundation protections remain valuable. This source addendum is not a third actual artistic method, proof of device/render performance, complete movie playback or user approval.
