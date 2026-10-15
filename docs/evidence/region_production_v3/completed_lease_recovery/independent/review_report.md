# Completed-review collector — final independent scoped ACCEPT

Reviewer `/root/v3_independent_engineering`, distinct from implementer. Scope: V3-COMPLETED-LEASE-RECOVERY-01, G0/G4 mechanism only. This is not enemy content/visual/G1 approval or another child creative round.

Final source: tools/production_loop.py SHA `982af941d6b00bc25a4867167fe91e8f5bca127c7e5aa6cd1cd30d65503b843e`; tests SHA `5a3c0e9028b228571091fba7f2d2562147303aeda55e6d94f9c2eae5c2cfe727`. Actual independent unit execution:64 tests PASS, exit0,4.054s.

## Actual independent failures and repairs

R1 `fc8942…` was REJECTED: real temporary-file source/response/revocation changes and simulated clock expiry during actual original scope quality still produced complete state; checkpoint-publication revocation left modified original state and accepted-looking publications. Original failing outputs remain `independent_probe_results_r1.json` and `review_round1.md`.

R2 `49d20e…` repaired those original failures, but was not accepted: modifying state/checkpoint/invocation/result at the final state.after save still returned complete. Original failing outputs remain `final_guard_probe_results_r2.json`; original R2 first-probe outputs remain `independent_probe_results_r2.json`.

Final R3 rereads original inputs and exact expected publications through the final locked guard, including state/checkpoint/result/invocation, receipt, before snapshots, archived exact tool and state.after. The old source fingerprint is fixed independently of mutable state, so generic finalization cannot mask source drift. On guard failure it archives provisional bytes, removes accepted-looking publications and restores original state/checkpoint atomically per file; it does not revert external source/response changes. The final lock-held uniform guard is the explicit linearization point; this does not promise immunity to external writes after return or arbitrary process/power loss.

## Actual independent final execution

All fixtures use real temporary Git repositories, registered same-common-dir worktrees, actual completed PIDs and actual filesystem locks. Host payloads are clearly labeled simulated, not real AI identity or native execution. No real enemy lease/state/source was changed by the reviewer.

- Original five late quality/checkpoint failures now all throw, restore original state bytes and leave no accepted result/invocation.
- Original four final-output mutations now all throw and restore original state, with no accepted publication.
- Eleven independently constructed preconditions all refuse: coherently rehashed expired lease; valid nonce with unmatched response; implementation-only verdict posing as review; coherent wrong task; same author; coherently rehashed check log lacking completion; changed source; real live PID; real exclusive flock; wrong feedback checks; stage acceptance with genuinely missing target quality record. No original state change or result/invocation publication occurs in these negatives.
- Both positive cases still work: scope ACCEPT completes with calls2/contentfalse; REJECT ends budget_exhausted with calls2 and retains rejection. These do not constitute actual host recovery; real collection remains a separate authorized action by the pipeline engineer.
- Source hashes were independently rechecked against the final freeze. No production edit, engine/media/model execution or original assertion deletion was performed. Existing original55/173 assertion retention is also covered by the frozen author evidence; the independent adversarial results, not that self-report alone, support this acceptance.

Scripts/results: independent_probe.py, final_guard_probe.py, precondition_probe.py and their current JSON results in this directory. The original failed versions' JSON outputs remain separately preserved. Actual real collection should additionally preserve original peer REJECT/request/response/source bytes, original calls2 and the newly archived collector SHA without claiming the vanished controller consumed it.

## Subsequent real collection independently verified

Pipeline author subsequently executed the already authorized actual collector at20:31:11UTC, CLIexit2 as expected for the preserved peer REJECT. This reviewer read the real resulting artifacts: running→budget_exhausted, calls2→2, source3e330d64 unchanged; original request/response SHA and canonical reviewer/verdict preserved exactly. New calls/workers/checks are all0. Archived collector code matches final982af941; before checkpoint matches the old state's bound SHA; state.after bytes equal the terminal real state. Collection occurred before the original expiry, with actual ps exit1/empty output and explicit original_controller_did_not_consume metadata. Details are `actual_collection_independent_verification.json`. This verifies completed-response recovery only, not a new enemy admission or native reexecution.
