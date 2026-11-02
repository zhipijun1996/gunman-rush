# COMBAT-PERF-DEPLOY-01 / Root Bell geometry preparation

Frozen static candidate, not committed. Owner wrote only `plains_revision_pose.gd`, `plains_revision_flora.gd`, and the existing deformation oracle runner. Skin is root-owned and was not edited. Other concurrent item changes are excluded from this patch/freeze.

The original scalar/vector expressions for Root Bell death IK, lower/upper/crown angles and hanger, and live carried elbow/hanger/leaf and angles now run once for a prepared pose/valid size. Flora owns the preparation; Pose only stores typed Vector2/float fields, so no reverse Pose→Flora dependency is introduced. Same prepared snapshot at a different size recomputes; the separate captured live snapshot also checks its size. Public `deform` still prepares a fresh snapshot; no global/cross-draw result cache exists.

`_fold_elbow` is unchanged. `_carry_stem` retains the original point rotations/windows/lerps using the prepared angles. UV-selected leaf attachments, per-point joint/scale work, clamps, early invalid-size guard, live/dead/handoff ordering and original math associations remain. Vector2 results are stored as Vector2, scalar angles as float; no coordinate repacking into Vector4/packedfloat32 or trig rewrite.

The snapshot is the existing draw-local prepared value object, not a mutable animation control API. Callers create a fresh prepared snapshot when pose values change, as the existing precomputed sin/cos terms already require. The new size invalidation explicitly supports reusing that snapshot with changing size; it does not cache by the source Dictionary identity.

Static evidence only: original source SHA and bytes in baseline.json/original; static-proof verifies all original Pose methods, all unaffected Flora methods, exact moved local RHS expressions, unchanged IK and all original test methods except one additive run call. `git diff --check` passed. No Godot/Chrome/performance measurement was run by this author.

The existing runner now additionally compares public/prepared outputs with immutable `FloraOracle` under live/default/dead/handoff poses, several UVs and offsets, repeated A→B→C→A sizes and invalid-size→valid recovery. It adds84 assertions and924 compared vertices; original7101/371801 observations are prior evidence, not a pass for this candidate. With no other additive changes, the expected combined counts are7185/372725. Root must execute original native wrapper and byte-exact oracle, then a real timed pose kernel; benefits are not quantified here.
