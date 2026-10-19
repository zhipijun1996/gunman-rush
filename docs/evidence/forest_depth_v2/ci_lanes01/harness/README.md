# Existing Harness phase execution and strict merge

Implementation only: `tools/harness.py` and additive tests in `tests/test_harness.py`. No profiles/check definitions, native budgets, markers, Player/GDScript, production code, commit or push was changed by this author. The workflow is owned separately by `/root/forest_progression`.

CLI:

```
python3 tools/harness.py --profile gameplay --profile art --release --jobs 1 --lane parallel
python3 tools/harness.py --profile gameplay --profile art --release --jobs 1 --lane serial
python3 tools/harness.py --verify-lanes <parallel-report.json> <serial-report.json> --profile gameplay --profile art
```

`--lane` requires explicit non-auto profiles, release, jobs=1, and no targeted checks or reuse. The original default CLI behavior, `run_check` and `execute_checks` remain unchanged. Lane assignment uses the original check.serial value in resolved profile order. Each phase executes only its assigned checks through the original engine/timeout/marker/lifecycle logic and stops at its original first failure. Its report explicitly remains `partial: true`, `approval_scope: partial`.

Each phase records the complete requested IDs, full tracked/deleted/untracked-nonignored source SHA map before/after (including prepared Foundry data), original dirty Git metadata, and original real toolchain identity before/after. Per-check reports retain exact argv/cap/input_digest/fresh execution results and add original marker plus original stdout log SHA. Both source/Git/toolchain must remain unchanged.

`--verify-lanes` executes no check or native/toolchain subprocess. It requires the two distinct passed, fresh, release/jobs1/full-profile phases, their exact lane ownership and complete original check set, matching current commit/manifest/profile/prepared source/dirty metadata, matching successful phase toolchain identities, original caps/argv/expanded argv/input digests, finite consistent actual intervals, fresh unique tokens and no reused proofs. It independently reads each sibling check log, checks SHA/marker/native-lifecycle errors, and preserves those log bytes beside the new standard merged report. Reports/logs changing during copy fail. Its new report is `partial: false`, `approval_scope: selected_profiles_technical`; fun/device remain unverified.

Portable phase upload must retain `report.json` and all its check logs as siblings with their original names/bytes. Original artifacts remain attributable through original phase report references and separate raw phase artifacts. The verifier is a source-bound CI report validator, not cryptographic proof that arbitrary authored JSON came from CI; external artifact/API provenance remains the delivery workflow's responsibility.

Validation: original `python3 -B tests/test_harness.py` completed with all 33 tests passing under the original 60s unit cap. `receipt.json` binds final source hashes and the actual log; original test classes and original execute_checks ASTs are exact. Eight added tests use actual temporary Git sources, dirty prepared data, and real bounded Python checks. Only the synthetic toolchain identity is mocked; no native or browser was run. Positive cases execute both phases then merge. Negative cases reject CLI misuse, failed/missing/duplicate/unknown/wrong-lane/timeout/reused proofs, changed commit/dirty metadata/source/Foundry bytes, changed argv/caps/markers/input digests/toolchain, corrupt/missing/linked logs and source changes after the last check.

The earlier first implementation suite is retained as `unit.log`; final code after preserving merged log siblings is bound to `unit-final.log`. This is ordinary unit verification after code changes, not rerunning a native failure for PASS.

Read-only CLI plans for current gameplay+art resolve 67 parallel +18 serial =85 distinct checks. These are plans only, not executions and not a claim that either CI lane meets its wall limit. No full/native CI, deploy, device or gameplay approval is issued here. An independent author should review this implementation before use as release evidence.
