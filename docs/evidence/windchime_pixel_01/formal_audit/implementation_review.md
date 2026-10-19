# Exact-union pixel adapter: independent implementation review

Reviewer `/root/formal_terrain_audit` did not implement or edit production code. Reviewed working-tree source hashes are captured in `reviewed_sources.json`; this is not a frozen-commit/full-delivery acceptance. Commands use repository Godot 4.7.2 wrapper.

## Scope verdict

**ACCEPT, limited geometry/source scope.** The new `PixelFormalTerrain` renderer retains exact authored union geometry in the independently tested matrix, excludes collision generation and has the expected formal terrain observation hook. Runtime GPU pixels, final formal scene coverage, full route/movement lifecycle, performance, aesthetics and device/user acceptance are **UNVERIFIED** by this reviewer.

## Evidence

1. Independently authored `adversarial_union.gd` samples every critical-coordinate cell midpoint of 60 deterministic randomized rectangle sets (overlap, negative, fractional, narrow forms), explicit diagonal contacts and a 0.125-wide gap. It compares original occupancy against generated canonical pieces, then checks complete plan equality after authoring split and reversed order. Four actual formal generated-definition sets add both difficulty classes and two seeds including ground support columns. Actual builder must return art; output contains no collision objects. **32,231 checks, 0 failures**, exit 0 and clean log. This independently derives occupancy from rectangles; it does not reuse the implementation's boundary extractor as the occupancy oracle.
2. Independently executed author-provided `tests/test_pixel_formal_terrain.gd`: **2,097 checks, 0 failures**, exit 0 and clean log. This includes current one-way visual consumer and moving-platform style toggle invariants. It is a technical helper/module test, not a full formal route.
3. Source diff confirms no modification to `PlatformingModule` body creation, one-way group, named `CollisionShape2D` or shape sizes; no modification to moving-platform `_physics_process`, at_time phase or restore logic. New moving presentation attaches to original carrier body. `PlainsTerrainStudy.refresh_geometry` swaps only the art builder and retains geometry-change observation.
4. New renderer correctly documents that it is an exact-boundary adapter, not a 16/47-mask TileMap. `_nearby_edges` influence radius 12 exceeds all actual shader distances (top8, side2, bottom4), and overload handling subdivides quads rather than truncating edges. Canonical geometry tests preserve holes and subpixel empty gaps.

## Remaining boundaries and follow-up checks

- Real GPU rendering remains required. Canonical geometry equivalence alone cannot establish ColorRect vertex coordinate interpretation, shader face interpolation, source partition pixel equality, precision on Web/mobile or small silhouette readability.
- Proactive review found that fixed-width studs/posts could spill outside hypothetical narrow/short one-way or moving bounds. The implementer added `_inside` intersection clipping for every detail rectangle before this report closed; source reinspection confirms the geometry containment guard. This was not a demonstrated failure in the sampled formal sizes. Actual pixels still require GPU review.
- Follow-up saw and shortcut gate diffs only replace `_draw`: clipped pixel rotor squares remain inside the existing hazard radius; shortcut lattice remains inside the exact body rectangle. Physics/timing/request code is unchanged.
- Legacy exact-union geometry helpers still reside on `PlainsTileComposer`, which preloads old art constants. The new shader does not sample those assets; use is strictly mathematical. This is not evidence that old visual sources have been used as new creative input.
- `pixel_mechanism_art` defaults globally to true, so shared module fixtures outside formal Plains also receive new wood/thorn/rail presentation. Physics is unchanged. Legacy art-identity tests must select their frozen legacy mode explicitly or be recorded as replaced consumer checks, never silently claim old source identity assertions pass unchanged.
- The observer path was retained, but this reviewer did not yet execute actual boss platform deletion/restore, one-way traversal or Motor ferry carry in a formal stage. Root's consumer integration review must cover these separately.
