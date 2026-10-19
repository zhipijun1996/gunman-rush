# S2 commit-bound consumer integration review

**ACCEPT**, limited to test/tool contract migration and committed-source evidence binding. Reviewed `6adc5ff30515d7adaf598d5bbba0268d42af44f4` against base `6c61faadd511c48a267b975550da897e701fd09f` and prior S1 `7ba2e92d2c3cb5449ac6648b820f79679548ee89`. No engine, test suite, or CI was started by this review.

All **43** affected tests/tools match the final independent review chain: the S1 original40 coverage plus three additional Root Bell paths, with the overlapping profile replaced by its final artifact-only reviewed bytes. The exact SHA256/Git blob map is in the accompanying JSON. Old cases, negative counterexamples and budgets retain the S1 review coverage; S1→S2 changes only the four listed test/tool paths.

Git cat-file independently verified **1231/1231** original Root Bell before/after source entries against S2 objects, with zero mismatches. The original successful single targeted check remains recorded at S1 with dirty test changes: 121.717s under its original360-second budget, 165 native assertions, 41+9 refusals, 40 historical/current audit rows and original27+9 reader probes. This is a new commit binding of unchanged actual evidence, not a newly executed S2-native run. Original raw reports and identities are unchanged.

S1→S2 has **zero production diff** in scripts/scenes/resources/config/assets/project/export paths. The old forest2127 inventory now differs at three existing test/tool entries; the new historical fixture was absent from that inventory. Therefore the original S1 inventory binding stays scoped to S1. Unchanged production permits limited reuse of the original two films and16 representative routes, without calling them fresh S2 evidence.

The selected S2 CI `39200142616`, full89 checks, original80/600-second corpus, Web/device verification and player/whole-region quality remain outside this ACCEPT. Parent region remains REVISE. Old failures and old6c61/S1 raw identities remain intact.

Evidence: `commit_s1_review.{json,md}`, `rootbell_historical_review01.{json,md}`, and final `rootbell_native_review01.{json,md}` in this directory. Exact hashes and complete1231 input mapping appear in `commit_s2_review.json`.
