# Plains golden fallback-audio teardown — bounded ACCEPT

Reviewer: `/root/forest_runtime_review`, independent of this three-file patch. I read the actual Git diff, the original 4.7.2 verbose failure, the inherited cleanup implementation and the completed new original-wrapper outputs. I did not run an engine, rerun the target, or modify the reviewed files. This review concerns test lifecycle and guard preservation, not forest mechanics, gameplay quality or full CI approval.

## Confirmed original failure

`build/verification/plains-negative-diagnosis01/` records source-before equal to source-after, Godot 4.7.2, and the real `--delete-far-bank` case: exit 1, 10 assertions / 1 original geometry failure, final tick 208, supported destination not reached. Its verbose exit additionally leaks four concrete Ogg backend instances (`OggPacketSequence`, `AudioStreamOggVorbis`, `AudioStreamPlaybackOggVorbis`, `OggPacketSequencePlayback`) and two `bell.ogg` resources. This is a genuine locally reproduced teardown failure. The remote CI outer assertion lacked its inner log, so its identical internal cause is not independently established; the original remote FAIL remains retained.

The custom `RecordedTrace.install()` built its own world and bypassed the inherited fixture's lazy audio-helper load. Both owner paths directly freed their worlds; the negative then immediately called `finish()`/`quit()`. `ShotLatch` uses a real `AudioStreamPlayer2D` fallback in these worlds without a `GameAudio` service.

## Actual minimal change and preserved checks

The runner now loads the existing helper before world/audio creation, awaits the existing `release_test_world()` after each completed observation/control, and accumulates its actual boolean into `cleanup_ok`. That inherited method stops voices, detaches streams, frees the world, and waits on the original captured playback WeakRefs for at most 1000ms. A failure still calls the original check ledger. `cleanup_ok = released and cleanup_ok` cannot erase an earlier failure. Original action observations are stored before teardown; no route ticks or physical actions were added to the case.

I independently compared all original 33 check-call lines, 11 Router-containing lines and 23 loop/budget headers: all are exact. The Python wrapper retains all 94 original assertion ASTs, resource/script error regex, expected negative exit 1, nonempty geometry failure, unreached receiver, >30 ticks, actual collider removal and accepted jump requirements. Its only extra assertion requires `raw['cleanup_ok'] is True` before either positive or negative validation. Removing that one line restores the original Python file byte-for-byte. Direct evaluation of that actual AST accepts True and rejects False, integer 1, string "true" and a missing key. Cleanup failure therefore cannot be relabeled as the expected geometry rejection.

The profile change only adds `artifact_paths: ["build/plains_redesign/golden"]`; removing that property restores the entire original profiles JSON structurally. Existing inner 180s, outer 240s and backend 1000ms limits are unchanged. No production file or helper implementation was altered by this patch.

## Completed new target evidence

Original Harness invocation log: `build/verification/harness/20261018T020510.665107Z/plains-redesign-golden.log`. The final original targeted Harness `report.json` is also passed: the single fresh/reused=false check exits 0 in 59.707s under its unchanged 240s cap; its working-file hashes match the source table below. Completed original-wrapper receipt: `build/plains_redesign/golden/run_n3gvbvpe/receipt.json` (SHA256 `5ded33c00d2b8dcddcfe88fb516b154037c8106d70a1801b989902f526c95a73`). Its status is passed; all 923 inventoried source entries are equal before/after. The explicit source commit is `89dccfeaf7764428102cb06a59f9a634fe964ace` plus the reviewed dirty overlay, not a new clean commit.

- Positive: actual exit 0, 53.909s, Godot 4.7.2, 3171 assertions / 0 failures, all 64 observations plus 2 resource controls, `cleanup_ok: true`. Its log contains 66 successful fallback-release receipts and no forbidden exit-resource/script errors.
- Deleted-bank negative: actual exit 1, 1.985s, 11 assertions / the same 1 geometry failure, `cleanup_ok: true`; one observed real `bell.ogg` playback releases in 13ms, and exit has no forbidden resource/script errors. The additional assertion is the real cleanup check, not a removed geometry check.
- I independently compared all 209 original/new negative frames on tick, phrase, position, normal/recoil velocity, recoil lifetime, grounded/support state, energy/capacity, charges/jumps, axis, safety and continuity: exact. Thus the observed negative physical failure is preserved. A separate independent recursive whole-JSON comparison finds 608 changed leaves: only native process-local Motor/hazard/collider IDs, the corresponding Motor-prefixed energy event ID, assertions 10→11, and new cleanup_ok=true. No other raw field changes. The author’s full-difference ledger retains these original differences rather than normalizing the raw files.
- The original positive-validator rejection ledger reports 11 cases, all rejected. This review does not treat those as new gameplay samples.

## Exact reviewed source binding

| Path | SHA256 |
| --- | --- |
| `tests/plains_redesign_golden_runner.gd` | `c7227e1fbd210e4587ae7b7cfb93315ba7faad74644da1099babc2e7ddf382ea` |
| `tools/run_plains_redesign_golden_tests.py` | `b8c01855191b2481af61d7c4eea4eec0e9bf74c4309c896ed78243f0256ec0a8` |
| `tools/harness/profiles.json` | `a7788c1e84daa9eadfd249fc509491b28e478182cdd711cc3e9cfc7c12e11c74` |
| unchanged `tests/plains_region_trace.gd` | `0c8e70220452b7432c3c9cdd87dfce54cea65e4e70b580311f157a1de119280e` |
| unchanged `tests/audio_teardown.gd` | `b2ff397c59cb5e4d7014b27f540e73b0c3127ebf4e0352ad7f01856bf90f36da` |

New positive raw SHA256: `a7f21a9e4453ecaa730a22fdd79ec93101a6d329cbc455c0a7f85ec341ca9df4`. New negative raw SHA256: `e61dbd4447154877de2982f328535829a80b2170d1df492057abd18bbd3c5579`. Negative log SHA256: `d54e84400311b9f0419f87ee083869bca0ce2818378b259b83a52ea8c1da7d24`.

Bounded ACCEPT for this exact test-only audio lifecycle repair, strict cleanup result validation and artifact collection. Original CI FAIL and original verbose-leak evidence must remain. No new global engine/resource-cycle fix, full final CI, native forest suite, browser, device, player or release acceptance is implied.
