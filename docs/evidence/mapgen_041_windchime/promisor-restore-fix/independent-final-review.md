# Independent review: verified promisor Git cache repair

ACCEPT for submission to the next exact-head CI. This is not a full-CI PASS.

Reviewed source SHA256: tools/cloud_inputs.py 9c6fa1a33613aabeb11afa31adb25c8e0dbdfb64fa41fb527b0a318576c1d44d; tests/test_cloud_inputs.py 2dad730e07080ecb1c1ca6cf3c7465043f9bbea2598414b0c47ade968fe9378d.

Independent execution passed all 56 tests in 12.704 seconds. All 50 original test ASTs are unchanged. Only restore_bundle changes among existing top-level source functions, with the cache helper added. The cache writes immutable Git objects only after full archive/member verification and before atomic worktree publication; object IDs and readable sizes are verified. Existing objects skip writes. Cache failures cannot publish inputs or produce ready. The new batch process preserves the original Harness 30-second guard and all check budgets.

Actual filtered-clone tests with the remote unavailable prove that cache operations preserve raw index bytes, refs and flags; original Git diff runs without fetching and detects real content edits before its first clean scan. The separate independent 2MiB fixture also detects mode changes and deletion. No game, SDK, PCK, Harness/profile, workflow or production-loop implementation changed in this repair.

The previous actual 422 run remains FAILED: strict large-bundle restore succeeded in both lanes, but original Git diff timed out before any of the 179 registered checks. Its complete evidence is preserved in ../final-ci-contract-repair/. This local review does not certify the next real large-cache cycle, CI Git2.56 performance, 179 checks, or affected aggregate. Those must be read from the next exact-head run.
