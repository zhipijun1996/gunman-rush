# V3-PIPELINE-01 independent review — REJECT (process G0/G4 only)

Reviewer: `/root/v3_independent_engineering`; actual implementer from this lease metadata: `/root/v3_pipeline_engineer`. Request hash: `a3e4a60aabd8c07e8c882178a69678530144c8d70895785f8c7ab02a735a8df1`. Baseline source commit `ed0623000c61287282f89e6b0463937b0afe0aca`, plus the six exact dirty-source SHA256 values in `pipeline_review_results.json`, independently matched to archived verification. Request/skill/source hashes verified before and after checks. The real production request is live and not revoked at response time. No tracked files were edited.

## Required correction V3-PIPE-REVIEW-001

**Severity: high, G4 correctness. Location:** `tools/production_loop.py::invoke_host`, lines 138–159.

**Invariant:** a revoked host lease cannot grant acceptance, even when a matching response arrives concurrently.

**Reproduction:** the separate `pipeline_review.py` invokes the real `invoke_host` function with an explicitly SIMULATED response writer. During the first polling `time.sleep`, the writer creates `lease_revoked.json` first, then atomically writes a schema-valid response with the exact current request hash/task/attempt/role. The next `while not response_path.exists()` condition is false, so the only revocation check (inside that loop) is skipped.

**Observed:** the revoked lease returns `status=accept` and writes `invocation.json` with `exit_code=0`, `lease_status=completed`. The original artifacts are retained under `host_revoked-and-response/`. A live matching response is accepted; expired and mismatched-hash responses are rejected, so this is specifically a revocation ordering defect. This executes the production acceptance consumer with simulated transport; it does not claim a real model invocation, worker cancellation, or actual kill/resume.

**Minimum repair:** reject revocation after observing/reading the response and before committing its result/marking successful invocation; preserve the original counterexample and add it to the real CLI test entry. Re-review a new frozen version. Do not delete or weaken old assertions.

## Independently verified

Five original Python CLI entries passed fresh: production loop 52 tests, routing 12, region context 10, experience 29, contracts 26. Their raw logs and SHA256 values are in `pipeline_review_results.json`. AST comparison against HEAD found all original 37/10/25 test methods retained byte-semantically (AST), with no changed existing test bodies.

Independent completed-evidence mutations now fail closed: altered log bytes; altered invocation bytes; bad log with both checkpoint/hash rewritten; exit 1 with invocation/checkpoint/hash rewritten; same implementation/review identity with raw events/invocation/checkpoint/hash rewritten; call-count undercount and overcount. The previously reported pre-review gap is fixed in this frozen candidate. The existing fresh direct controller suite also exercised clean phase resume, partial-check recovery, live cancellation/expired lease recovery, fresh retry directories, nonce mismatch, authentication precedence over disconnect, bounded retry budget, and independent package continuation while only descendants block. These are controller simulations, not autonomous content evidence.

Forest route remains an offline plan: authoritative S2/H context, explicit ecology/Boss/assets/animation ownership, proof contracts and formal-opening=false. Existing shared Plains/Foundry PASS and missing forest native proof do not grant the stage. No forest-specific native producer/formal consumer has been executed here, no ability is granted, and no forest content completion is accepted.

## Scope and remaining evidence

G0 process design reviewed; G4 rejected for the lease defect. No gameplay/G1, visual/animation/audio/G2, formal region/G3, player/device/G5 or full content acceptance is granted. Actual parent-host process-kill/recovery with different actual agents remains pending and must retain its original lease/cancellation/raw host records. No Godot, ffmpeg, full suite, GUI, video/audio or physical device was run by this reviewer.
