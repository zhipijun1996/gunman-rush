# Original CI verifier review — PLAINS-MOTION-LOOT-02

Reviewer: `/root/guard_review_recovery`, read-only. No engine or check was executed, and no production/test/Harness/verifier source was changed by this review. Target source is `a5ff2ccb9bd59efc79eb5fb1bc2b6e59de0f4249`, CI40993924803. At review time only prepare has succeeded and raw context/prepare artifacts are available; this is **not** a lane or full167 PASS.

## What the current verifier gets right

It reads the exact requested commit's full-profile manifest; preserves the original167 expected IDs, lane ownership/order, argv, timeout and completion regex; checks native exit0/fresh/non-reused state, input digests, original log digests/markers, strict script/shader/lifecycle errors and cross-lane unique tokens; compares before/after source/toolchain inventories and task-production bytes with Git. It correctly treats each lane as partial, preserves existing Foundry preparation as explicit modified inputs, and states that official affected/merge closure is still required. These checks should remain.

## Required narrow corrections before this is a sole technical audit receipt

1. **Use parity with the existing frozen verifier.** The script currently does not check each report's `lane` field, exact integer `jobs`, full toolchain shape/query success, `reason is None`, expanded argv and the recorded Python interpreter, or finite/consistent actual start/end/duration. Those are already required by `tools/harness.py::verify_lane_reports` at the target source. Raw argv, token and log checks alone do not replace them. Preserve the original process timeout; do not add a new wall-duration cap — the existing function allows launch/cleanup/log overhead and checks consistency within1s.
2. **Compare full declared Git metadata across both lanes.** Current code inspects only parallel `working_files`/`untracked` and compares only source/toolchain inventories. It does not verify serial `git_status`, `diff`, `working_files` or `untracked` against parallel. Require all five existing metadata fields (`commit`, `git_status`, `diff`, `untracked`, `working_files`) to match across the reports. For every declared prepared modification, require its hash to equal the source inventory. Continue limiting preparation to the original context-proven Foundry JSON set; do not call this Git clean.
3. **Do not read logs or reports outside the current original ZIP evidence.** `base / c['log']` currently allows an absolute or traversing report-log path. Require the exact `id + '.log'` relative basename, regular unlinked files inside the freshly extracted evidence, and original ZIP membership. Extraction currently uses an existing directory and `rglob`, so stale report/log files from an earlier extraction can be consumed if the latest archive omits them. Use a fresh, previously nonexistent directory (or read members directly), reject duplicate/unsafe/linked members, and reject a pre-existing output receipt rather than leaving an earlier PASS after a new exception. Original ZIPs remain untouched.
4. **Lock the audit implementation too.** Manifest bytes are read from `args.commit`, but `harness` is imported from the live worktree. Before using its resolution/digest/lane functions, require the imported Harness source and manifest to equal the target commit's bytes. No implementation or policy update is needed.

The smallest maintainable approach is to keep ZIP API-digest and task-Git-byte checks, extract each ZIP into a new path below the existing ROOT/build, then call the exact frozen `harness.verify_lane_reports(...)` rather than reproducing part of its contract. Pass the parallel report's declared five-field metadata and source inventory explicitly; this checks that both original transcripts agree, **not** that this cloud checkout reproduces CI's prepared Foundry state. The official affected job is still the authority for that comparison.

Suggested shape (read-only validation; no engine):

```python
# Assert imported tools/harness.py and MANIFEST match git show target:...
# Extract untouched original ZIPs into fresh unlinked ROOT/build subdirectories.
metadata = {k: parallel[k] for k in
            ('commit', 'git_status', 'diff', 'untracked', 'working_files')}
merged = harness.verify_lane_reports(
    manifest, ['full'], [parallel_report, serial_report],
    metadata, parallel['source_files'])
# Keep API ZIP SHA checks, each working_files hash/inventory agreement,
# Foundry-only/context-exact preparation and changed-production Git SHA checks.
```

## Remaining original artifacts and closure to verify

When downloads arrive, bind API artifact IDs/names/digests to the same run40993924803, attempt and exact head a5ff. Verify both original partial lanes independently and jointly: expected92/75 ownership,167 unique/fresh checks, no failure/unexecuted/reused entries, unchanged original budgets/regex/argv, byte-exact logs and before/after/cross-lane source/toolchain/Git metadata. Preserve all earlier failed runs.

Then inspect the original context/pre-execution plan and official affected/merged proof from this same run. The context plan must name exact a5ff, full_lanes and the original full167 selected closure. The merged report must be passed, partial=false, approval_scope=selected_profiles_technical, and its167 per-check results/tokens/log digests must agree with the two original lane reports. Its lane reference hashes must equal the original report bytes, and the merged prepared inventory/metadata must agree with both lanes. Require prepare, both lane jobs and affected aggregation to be terminal success for that run/head. Merely combining lane JSON locally does not replace this closure.

The current changed-production byte comparison is correctly limited to task changes since2ac. If a final claim is broadened to *all* runtime production matching Git, independently compare every available non-Foundry runtime file too; otherwise keep the wording limited to task-production bytes and separately disclose unavailable historical evidence inventory entries (`deleted`) and validated Foundry preparation. Do not silently treat an inventory equality/hash count as a clean Git checkout.

## Quality statement boundary

Even a successful exact full167 closure updates only technical evidence and this exact-source limited independent review. It does not bypass G1–G3, set G4/G5, or supply GUI/consumer-coverage, art/audio, device, economic-balance or user evidence. Keep those main enemy task gates/dimensions unverified as requested; process-only guard migration records have their separately bounded scope.

Reviewed script SHA256: `4337db1bfd3950c25009f857e050f925131c04fc027875f33ad72fc738cbc2be`. Frozen Harness SHA256: `588f0079f01713caa55a84ad3ad44c1bd667d8535678620460a9b31fb2c46c7e`.

## Follow-up source review after the owner correction

The updated script now locks both Harness and manifest bytes to the requested commit, rejects linked ZIP entries, uses new extraction directories, and calls the exact frozen `verify_lane_reports`. That original call supplies the missing lane declaration, full five-field cross-lane Git metadata, toolchain query/type, expanded argv/interpreter, reason=None, actual interval and strict log-path checks. The main receipt-consistency gaps above are therefore addressed without changing production/test/Harness policy or running any check. **The revised tool is suitable for the pending read-only original-artifact audit**, subject to actual inputs and official affected closure. No artifact result has been approved yet.

Two small operational safeguards remain advisable: refuse a pre-existing output receipt (so a new early exception cannot leave an old PASS at that path), and explicitly compare every declared working_files hash with its matching source_files value. Also validate each manual log basename before its initial read; the original verifier already rejects a bad path later, so this is fail-fast hygiene rather than an unhandled false-PASS route. Duplicate ZIP members can be rejected before extraction for unambiguous provenance. These do not justify changing any CI/check threshold. Root may retain a fresh run-specific output path and perform the supplemental hash checks during the independent artifact audit.

Final claims remain bounded to technical and exact-source limited independent review. G1–G5, formal GUI/consumer coverage and all subjective/device/user dimensions remain unverified.

Updated script reviewed SHA256: `4337db1bfd3950c25009f857e050f925131c04fc027875f33ad72fc738cbc2be`.

## Final candidate-tool snapshot

Owner has additionally added pre-existing-output refusal, duplicate ZIP-member refusal, exact id.log validation before manual reads, and prepared working_files-to-inventory hash checks. I re-read these source guards. Candidate verifier source SHA256: `70863d9f22ce5f8307bd4e84d4d7cf34b8aa3137bd9248038f0f87d9bf3d6b5a`. This is approval of the candidate audit tool only; no original final lane ZIPs have been audited and no CI result is inferred. Actual original-artifact review will be reported separately when paths are supplied.
