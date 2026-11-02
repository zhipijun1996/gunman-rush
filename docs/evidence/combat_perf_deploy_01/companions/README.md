# Companion query candidate — frozen, native pending

Author scope: exactly two production leaves and two existing runners. No engine/browser run, commit, registry/config/resource/tool/budget change. Parent owns the engine lease and final acceptance.

Before → after:

- Ordinary `ItemCompanionEffects._target` still obtains the same full sorted candidate list. Without G08, it now returns immediately at the first eligible, unobstructed candidate. Previously it stored that result, continued testing every later candidate's LOS, then returned the same result. G08 priority and fallback body remain intact. Actual existing eligibility implementations (Damageable and WindkeeperDamageable) are read-only; actual clear_line is a physics ray query with no mutations. Three count, 1.5-second attacks, origin geometry, cooldown and damage rules unchanged.
- `ItemRuntime.targets` still calls the identical `WeaponActionRuntime.receivers(point,radius)` with identical parameters and its first distance sort. It now checks strict increasing order using the *exact original final comparator*. If strictly increasing, the final total order is already established and no second sort is needed. At the first violation—including fully equal keys—it performs the exact original second sort on the original unmodified array. This intentionally preserves Godot's old tie behavior instead of silently adding an instance-ID tie-break or relying on a stable sort.
- No WeaponActionRuntime change and no duplicate target query implementation. Cost changes from a second O(N log N) sort to at most N−1 comparisons for an already strictly ordered result; noncanonical/equal-key input incurs a bounded extra prefix check and the original sort. Native CPU benefit is **not measured yet**, so this is not a universal timing claim.
- S02 distribution remains unchanged. One idle device can still make all three search every tick. Skipping cooldown members would miss newly better-ranked marks/positions/eligibility changes used by the existing distribution contract; this candidate deliberately does not invent a cross-frame cache or defer acquisition. Original max2/target and lock/epoch behavior retained.

Regression additions:

1. Existing actives runner: actual physics rays behind a real wall; ordinary first visible target needs only two LOS checks rather than checking the third distant target; G08 still examines the marked farther target and scans all candidates when no mark exists; empty set produces zero rays. Adds counters to the fixture only. Adds S02 actual singleton retry and a new dream mark during cooldown, proving the unchanged eager revalidation contract.
2. Existing formal runner: real App ItemRuntime and real Shape queries over existing training hurtboxes. Compares against the exact old full sort in distinct-distance, reverse/ordered tie IDs, equal complete keys and instance-ID fallback cases. Setup restores original IDs/metadata/positions before original primary damage tests.

Original test method bodies/conditions are byte-exact after removing the explicit newly appended test call and fixture-only counters. No original check, wait, success marker or budget removed/relaxed. `candidate.json` binds all four original/final hashes and the patch. No claims of compilation or engine PASS until parent runs the original wrappers.

Requested original commands (native120 seconds per family, editor90; existing Harness outer240 each):

```
python3 tools/run_item_v5_tests.py --suite actives
python3 tools/run_item_v5_tests.py --suite formal
```

Native measurement suggestion: same-process alternating original/candidate target query over actual receiver counts0/1/2/16/64; separate strict distance order, reverse tie IDs and equal complete keys. Include range query cost and preserve actual target IDs/epochs. First-visible LOS count test is a deterministic work-reduction check; it is not phone FPS evidence. Keep every failed compilation/test/performance run.
