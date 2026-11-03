# Verified input restore: promisor Git object cache fix

Baseline: 42244887a6cacb82a6b3d59f04a933a6eee71e87. Only tools/cloud_inputs.py and tests/test_cloud_inputs.py changed. No stage/commit, native/Web rerun, CI launch, Harness/workflow/profile/budget change.

## Actual causal reproduction

`before.log`/`before-result.json` were captured against the original implementation using an actual file:// --no-local --filter=blob:none --no-checkout Git transport and sparse checkout. Selected blobs were absent, remote was switched to a nonexistent path, byte-only restore returned ready, then the original Git diff invoked a lazy promisor fetch and failed. `after-manual-cache.log` shows the independent minimal cache intervention. `after.log`/`after-result.json` repeat the actual fixture against the fixed source: selected blobs become available, original Git diff with its 30-second budget returns empty without fetching, and content/mode/deletion edits remain visible.

These are tiny local reproductions (99 selected bytes), not a claim to have rerun 4GB input restoration, GitHub Git 2.56, all 179 checks, or final CI. Local Git is 2.52.0. The large-run failure and successful strict restore remain recorded separately under final-ci-contract-repair/.

## Minimal change and invariants

After complete archive/member/tail SHA, Git blob, path, mode and receipt verification, import only missing unique immutable blob objects from numeric staging leaves with one no-fetch/no-filter Git hash-object -w --stdin-paths process. Compare every returned OID and reread sizes before publication. Existing objects skip import. Existing post-stage HEAD/tree/index/sparse snapshot remains in place, without adding another snapshot. Failure publishes no new files, leaves pre-existing files intact, and may retain valid immutable cache objects.

The cache operation itself leaves raw index, refs and flags exactly unchanged. Normal Git sparse-checkout reads may normalize S to H when restored worktree files appear; that was already original restore behavior, so whole-restore raw flags are not falsely asserted immutable. HEAD/tree/index mode/blob/stage entries and refs remain unchanged; no assume-unchanged or guard bypass is used.

Cache timings and actual filesystem snapshots are separately reported; compressed cache allocation is not assumed equal to raw input bytes. The new bounded 300-second bulk local cache IO is separate from the untouched original 30-second Git diff guard. Starts/completion and before/after storage events make the phase visible. No additional per-file Git calls are added.

## Validation and preserved failures

`tests-final.log`: 56/56 passed. `source-and-original-tests.json`: all original 50 test ASTs unchanged; 6 new meaningful regressions. py_compile and git diff --check passed. Added regressions cover real missing promisor blobs/offline original guard, first dirty edit, cache failure, SHA disagreement, invalid archive rejected before cache, and no writer when objects already exist.

Earlier failed development attempts remain preserved in original-50-after-source.log and tests-attempt-01.log. They caught an unnecessary sixth repository snapshot and invalid whole-restore raw sparse-flag expectations. The final source preserves original snapshot count/order and all original test ASTs. tests-attempt-02.log is the initial complete 56-test pass; tests-final.log is the final verbose identity-frozen pass (10.585s).

Source/baseline copies and exact patch are included. `reproduce_before.py` and `reproduce_manual_cache.py` were executed before the fix; do not rerun them against current code and relabel the new output original. `reproduce_after.py` runs current source and stores truthful current output.

Resume commands (no CI automatically):

    cd /tmp/gunman-rush-mapgen-041
    python3 -m unittest discover -s tests -p test_cloud_inputs.py -v
    python3 /workspace/refactor-evidence/mapgen-041-integration/promisor-restore-fix/reproduce_after.py
    git diff --check

Two-file write ownership released for independent review. Parent owns publication and any full-CI launch after review.
