# Terrain-border broad-phase independent bounded review08

No counterexample found to this patch's equivalence. The mathematical filter and frozen oracle are sound for its stated scope; the completed native comparison supports continuing actual App/performance/GPU verification. It does not yet prove the browser screenshot timeout is fixed or reapprove style v3.

Production SHA256 e1f710bfe7f125bf64245406db0b07d70def3a3ee591309cfb53196cb45f2d34. I am independent of this implementation and the new Godot oracle/runner. No source edits, Godot or browser launch.

The optimization only replaces occupancy-query inputs with a stable closed-AABB subset. Every queried face midpoint and corner belongs to the target rectangle's closed boundary. If a finite positive-area other rectangle satisfies either original directional occupancy predicate there, its closed bounds contain that point and therefore intersect the target's closed bounds. Strict axis separation safely rejects it; touching edges/corners remain. Original order/duplicates remain, and original symbolic occupancy and whole-input cuts are unchanged. Zero/negative/nonfinite rectangles cause full-input fallback, so the optimization inherits old behavior instead of redefining exceptional geometry.

Two concrete dangerous alternatives, both avoided here:

- Positive-area intersection would discard a rectangle touching at x32; point(32,16), rightward direction is occupied by that touching rectangle. Removing it would wrongly expose a shared face.
- Pruning cuts as well as occupancy changes exact output: target(0,0,40,60), far rectangle(999,11,40,12) still produces original cuts[0,11,23,60] on vertical sides. Union may remain equal after merging, but original ordered face segments differ. Current patch retains these cuts.

Independently compared reference bytes against baseline a6e7cfb4c9b50b22a4a643afcb98fbe7550d5d64: identical apart from class_name. It is a genuine old oracle, not optimized code copied into both sides. Runner compares var_to_bytes of complete ordered faces/corners and complete final edges/pieces, including duplicates/reversal/narrow gaps. Final geometry uses shared unchanged merge/pieces composers; this is valid for this border-only patch but does not freeze those composers against future changes. Native exceptional fixtures cover zero/negative dimensions, not NaN/Inf; fallback logic for the latter is statically reviewed only.

Read completed border-equivalence08 receipt/report: exit0,39.141s, source-before==source-after, all six changed snapshot file hashes verified,62 cases/3000 assertions/0 failures, including two real Forest worlds with legal grapple capabilities. Map1:1155 solids,2258 edges/813 pieces, original summed plan12.060s versus0.979s optimized. Map2:1377 solids,2658 edges/973 pieces,16.670s versus1.321s. These are plan timings, not full App or screenshot latency. Failed07 fixture-capability result remains historical failure;08 is a fresh completed report.

Pure-Python independent finite-arithmetic boundary property check covered292048 point/direction queries with exact equality between original and filtered occupancy, plus both counterexamples above. It supplements, rather than substitutes for, Godot byte comparison. Raw /tmp/forest-v18-border08-independent.py and .json.

Remaining scope: actual cross-region GPU and consumer timing, followed by explicit versioned style binding/review(v4). Do not silently refresh old v3's boundary_sides source binding or claim its old art review covers this new source. No expansion of optimization, gameplay gates or timeout increase is justified by this report alone.
