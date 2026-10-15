# V3-PIPELINE-01 round 2 — ACCEPT_SCOPED

Actual reviewer `/root/v3_independent_engineering`, implementer `/root/v3_pipeline_engineer`; these are different actual canonical agents. Bound request hash `c25bea8103e6008d731f81dbc0f3651601b2050f0dc57265d4281628a8aa4d4a`, attempt 2. Baseline `ed0623000c61287282f89e6b0463937b0afe0aca` plus six exact dirty-code hashes in `pipeline_review_results.json`; production_loop SHA256 `de7469335f19f0ada676197c0d0bb1d97b93839012cd9978ed10c9ddd4df99c8`. Source/request/skill binding and source stability verified. No tracked file edits by reviewer.

**Acceptance scope:** process mechanism G0/G4 only. Current actual `check_task_quality` returns scope_complete=true/content_complete=false. The real host process-kill/resume drill remains unverified and is owned by the parent after this review. This verdict does not claim that interrupted actual agents have already been stopped/replaced/recovered.

## First rejection repaired

V3-PIPE-REVIEW-001 is resolved for the observed response-consumption/publication boundaries. The original first-round script, accepted revoked response, invocation metadata, rejected report and response remain unchanged. A separate second-round copy only changes output/request/implementation paths. It runs the same revoke-then-response polling race against the frozen new consumer: now rejected, not accepted. Positive live matching response remains accepted; expired matching response and mismatched nonce/hash remain rejected.

Independent added boundaries execute the actual `invoke_host` consumer with explicitly simulated response/clock/file hooks: revocation after parsing, wall expiry after parsing, revocation after result validation, revocation after result publication, monotonic expiry after publication, and wall expiry after publication. All six reject; no accepted result remains. All three publication cases retain `rejected_result.json` and mark invocation failed/expired with no successful exit. These are controller simulations, not actual host/model work or content evidence. Exact artifacts and script are in `lease_publication_results.json`, `lease_publication_tests.py`, and each named case directory.

Completed-task raw log/invocation tamper and coordinated checkpoint/SHA rewrites were re-run: missing completion marker, exit1, same implementation/review identity, and budget under/overcount all reject without another worker call. See `pipeline_review_results.json` and seven retained case directories.

## Fresh checks and retained assertions

Reviewer independently ran the original five Python CLI entries: production-loop54, routing12, region-context10, experience29, contracts26; all exit0. Raw logs/timing/hash records are in `pipeline_review_results.json`. AST comparison of first-round frozen tests against current tests found all original52 test methods and bodies unchanged, now54; `retained_assertions.json` records this. First review had separately established the baseline37/10/25 methods were unchanged. Existing direct CLI tests exercise phase persistence/recovery, transient retry counting/backoff/caps, 401 priority/no retry, independent-package continuation and forest proof refusal.

## Explicit remaining boundaries

Actual parent-host kill/resume with raw interruption receipts, new request nonce and different actual agents: unverified, required before claiming live recovery was demonstrated. Forest-specific native technical consumer/producers: unverified; forest route stays an offline authority/S2-H plan, formal-opening=false, no ability grant. Shared Plains/Foundry PASS cannot grant missing forest proof. Game operation/G1, visual/animation/audio/G2, formal game integration/G3, user/device/G5 and full content completion receive no acceptance from this process review. No Godot, ffmpeg, engine suite, GUI, playback/listening or device test ran here.
