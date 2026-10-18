# Plains experience artifact retention — limited review

**ACCEPT** actual dirty profile-only addition. Removing exactly its three artifact_paths lines reproduces the entire HEAD manifest byte for byte. Only the existing check gains `artifact_paths: ["build/plains_redesign/experience"]`; command, outer900, each native180, all assertions/actions/mutants, marker and serial placement remain unchanged. No production, runner, cleanup or workflow modification.

Actual CI serial log shows the check failed after approximately19 seconds with outer `RuntimeError: Actual experience proof failed .../run_gwnke3oe`. A missing inner receipt path was printed. Neither a timeout nor AudioTeardown is established. Original CI failure remains UNKNOWN and retained; cancellation of remaining parallel work is not a success.

Existing Harness fingerprints declared artifact paths before/after run_check, copies changed files into report artifacts even for ordinary failed checks, then reports lane failure. Existing workflow always uploads that report directory. The addition therefore preserves future unique run_ inner logs/JSON/finally-written receipt without affecting execution or verdict. Abrupt process death can still leave incomplete evidence; metadata does not promise a complete capture.

Independently verified every indexed local artifact/source SHA and size except live profiles, whose expected difference is this patch; archived profiles.json.txt matches the old indexed SHA. Source-before/after maps match. Existing local CLI receipt records exit0/53.482565s under cap900, positive255/0, expected deleted-island8/2 and42 validator refusals. These are a separate local pass, not the remote cause or a replacement for its failure. No native was run by this reviewer.

Do not bundle speculative audio lifecycle repair. Future CI has a new source/manifest identity: this patch improves diagnosability, not a proven causal fix or whole game/release acceptance. Audit binds current candidate hash and exact inverse proof. Only build reports written.
