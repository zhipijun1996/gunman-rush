# Shared loot material — limited independent acceptance

Accepted scope: only `shared-material.patch` (594a7ea5…), StageVisual b6b85b4d… and existing App test 9a375fd8…. No blocking issue found. Original files match Git 5d3303b7; both candidates match the actual external source tree.

The shader has no uniforms. Texture, transform, UV and tint remain per CanvasItem. The material belongs to each stage visual instance; it is not a global cache. One resource is allocated even before any drops, a small intentional allocation shift. The teardown check releases its local strong reference and confirms the old material is freed after App reload.

The test delta contains insertions only: all original lines and their order remain. There are 38 original `_check` call-bearing lines plus its declaration (the author's receipt counts these as 39), and four added assertions. The real supplied 603/0 report reaches and passes all four checks. No assertion, action, frame wait, reward or physics rule was removed or changed.

The existing fixed-time native fixture reports bound material counts 3→1 and 8→1, independent tint and weak-reference release. I independently hashed all three baseline/candidate PNG pairs: each pair is byte identical. This is software GL evidence at fixed time, not phone performance. The earlier non-fixed-time rejected attempt remains preserved. Root performed the separate visual inspection.

No engine or browser was run for this review. Optional warming, compilation elimination, FPS, hardware devices, natural gameplay and full CI are outside this acceptance. Full evidence paths and hashes are in `loot-shared-review.json`.
