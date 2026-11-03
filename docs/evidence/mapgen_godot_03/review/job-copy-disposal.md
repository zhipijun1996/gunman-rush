# MAPGEN-GODOT-03 tuning snapshot / destruction / runner supplement

Non-author read-only review; no Godot/browser/test execution or production edits. Prior reports and original failures remain unchanged. **Final job source correction is statically acceptable; a passing final job/slice runtime result is not established by this review.** Known failing runs below remain failures.

Frozen reviewed files:

| File | SHA256 |
|---|---|
| experiments/generation/runtime_map_generation_job.gd | 8b3c3c37bad3fe116145079d64ef26a9a350591f1f04f8bed7142f8af9abc18d |
| tests/runtime_map_generation_job_runner.gd | b90f9d6bba7dd9986610ad16a820e4376645ad76678515fc615a44e2cffeb6f3 |
| tests/runtime_map_generated_slice_runner.gd | f408334eb6012b8609c967c1c1fd588321b76127588915d82fb3b47c0090cc13 |

Provider01c7a8cc is unchanged from the preceding review. Identity05's44/0 and the mixed-key ordering probe are root execution facts, not this reviewer's run.

## Original failure takes precedence over earlier static assumptions

Read retained `/tmp/mapgen-v3-audit/generated-slice-01.log` (SHA2568ef6f0f1708ee350f717455c438dfd752b7063683922e1a15c0979ea98c10258). It reports real M16 capability refusal after the old Resource.duplicate tuning snapshot and three PREDELETE self.close null-instance script errors. The earlier static reviews did not detect those two runtime semantics and do not constitute successful runtime acceptance; their exact historical SHA scope is retained. This new report does not amend them into passes.

## Actual tuning values copied

Job lines274–292 now instantiate a fresh PlayerTuning and copy actual PROPERTY_USAGE_SCRIPT_VARIABLE properties, deep-copying Array/Dictionary values. Current PlayerTuning fields are non-export booleans/numbers/string and one Array[float]; no nested Resource references require an unimplemented deep-object copier. Thus the code captures effective live tuning rather than exported defaults/zero fields, preserves actual scalar types/values and detaches jump_speeds. LevelRequest identity/expected hash/root mode and deep capability copy remain intact. Opaque handle/lifetime/token/owner checks are unchanged.

The unit oracle does enumerate fields with the same usage flag as the implementation, so that enumeration alone is not independent evidence that all relevant fields are included. It nevertheless contains meaningful counterexamples: explicit changes to ground_speed, gravity and jump_speeds, object-identity separation, caller mutations after copy, snapshot mutations after copy, and nested capability mutation. Reintroducing the observed Resource.duplicate bug would fail these value assertions.

More importantly, jobrunner lines257–329 uses public begin, then mutates caller request/config/bindings/IDs, clears the caller jump_speeds and max_jumps, and runs the actual locked addon through its real Provider. It requires ready/admitted Plan plus original captured seed/spawn/selection/capability provenance. This checks the copy in the real consumer chain, rather than merely restating the copy loop. The slice runner separately exercises the real configured player, generated entrance, original Provider/Stage, one player/controller/policy and actual Router→Motor motion. No replacement solver or fabricated PASS result is used.

## PREDELETE fallback

Job lines322–332 no longer dispatch close or another self method while the envelope is being deleted. It marks closed, directly cancels a still-owned live addon job, clears job/library/built references and drops the current Ticket. Explicit close remains the source owner's normal path. The opaque handle itself contains no result or reference back to the source, so a surviving handle cannot keep the source alive or access internal state.

Runner lines225–246 covers both release of an explicitly closed source and dropping an unclosed source with a real positive-operation suspended addon continuation. It verifies source WeakRef release and unchanged caller lifetime authority. It does not call the destructor directly or set fake phase fields. WeakRef release alone would not detect the old script error or every leaked internal resource; the unchanged original run_engine wrapper separately rejects SCRIPT/Parse/Shader errors and ObjectDB/resources-in-use exit reports. Actual execution of that complete wrapper is essential before declaring this regression fixed at runtime.

The remainder of the runner exercises actual same-epoch/different-lifetime identity, actor/run/stage invalidation through existing owners, freed/queued owner, foreign/old handles, replacement, cancelled/closed outcomes, detached diagnostics, separate validation tick, one-time take/commit and preserved original fingerprint/map_id. A fixed operation-count assertion belongs to the pinned candidate/cohort, not a timing SLA. No SceneTree assembly is performed by the job runner; it checks unchanged scene-node count.

## Current observed execution limits

Read `/tmp/mapgen-v3-audit/generated-slice-02.log` (SHA256df00d1d72081e7deff4f7279ca4e0968fcc42ad9e99f8d228c005b7e6e614bb2). It reaches ready/committed; the previous tuning refusal and PREDELETE script error do not recur in that log. However the run is **47 checks / 1 failure**, namely the slice runner's fixed expectation of two native ferries, and the wrapper exits1. This is not a passing slice result and does not certify all destruction paths.

Also read `/tmp/mapgen-v3-audit/generation-job-01.log` (SHA256559fa230fc35a5084182a7b187397bd5c633f8b78285f68569a72fb7c6c4c6d0): parse failure at runner line42, no lifecycle checks ran. The presently reviewed b90 runner has preload_source at that location; that difference is not a new runtime success. Final runner/source binding and a fresh successful wrapper receipt are still required. Reported both observations to root/author rather than guessing source attribution.

No additional confirmed source defect found in8b3c job. The remaining failing slice expectation and successful execution of the frozen job runner need resolution/evidence before runtime acceptance. No Web, phone, FPS, complete leak freedom or full-map playability signature.
