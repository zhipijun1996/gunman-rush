# Current Bible / explicit history execution

Base: 23887fe5c9d32afa8bcba8725fd7895b6266aa5d. No production GD, media, engine, or remote CI changes by this batch.

- `python3 tests/test_region_bible.py`: 46 current and generic tests; 19.276s under the unchanged 30s cap, exit0.
- `python3 tests/test_region_bible.py --history`: 28 historical custody/replay tests; 11.244s under the unchanged 30s cap, exit0. Existing Harness registers this only in legacy-compat.
- `python3 tests/test_region_bible.py --all`: all74 via the same unittest runner; available explicitly, not run or claimed as a single30s success.
- Existing planner46 and Harness91 passed. Their logs are retained here.

The HEAD file has67 `test_*` methods (earlier references to72 were not the test-method count for this file). All67 remain, plus the previously reviewed two finite Git-history tests and five new current-binding/partition tests. `partition.json` lists every exact qualified method ID. Discovery must equal the disjoint, nonempty union, with no duplicate IDs; unknown/missing methods fail loading. The test exercises missing, unknown, overlap, and empty partitions. This is not a class-name/version-name filter.

Default coverage retains actual current206 reference SHA checks, real player body dependency closure, missing/corrupt/current-source drift, quote/attachment identity, path escape/symlink, before/after-worker and restored-state rejection, forged re-signing, current caller scopes, and current check input digests. New style28 tests cover the five changed GD leaves, all206 ordered roles and exact current bytes, unchanged non-GD/media, rejecting former27 bytes/missing/corrupt live files even with an archive, finite27 archive corruption/missing/re-signing rejection, and stale27 binding rejection.

Historical-only duties are the prior19–27 parent/merge/source-custody chains, whole historical test-method preservation, historical input-prefix reconstruction, old accepted source vectors, and the finite replacement for20 historical Git reads. Generic archive fallback/corruption counterexamples continue in the current suite as well. All old historical SHA and methods remain; `freeze.py` verifies the69 V2 methods by a finite inverse: three current-version literals, two normalization dictionary entries, and one former27 source-reader expression. Old Git reads were already independently reviewed in V2; the exact finite manifest/helper are reused. No caching of mutable source/document roots was added.

Only the two existing finite Bible inputs append three actual paths. The two creative checks retain their existing whole-snapshot behavior. The new manual check likewise uses Harness's existing whole-snapshot contract instead of duplicating661 input rows. Every old argv, marker, timeout, weight, full171 list, other profile, and legacy30 prefix is unchanged; legacy gains only the history check. The planner test retains the original16+14 history projection and verifies the new tail/command/budget/manual-only ownership.

After the successful current/history runs, the two method-ID tuple literals were only reformatted onto multiple lines; method/module AST behavior is unchanged. The manual check's duplicate inputs were replaced by the existing whole-snapshot contract before the planner/Harness run. Final source hashes are in freeze.json; no broader/native/full171 success is claimed. Previous full30s timeouts and historical Git failures remain in the previously archived evidence.
