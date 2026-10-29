# PLAINS-MONSTER-REVISION-01 · current registry/routing review

**Verdict: ACCEPT, limited to the current-registry test code, strict report reader and explicit default-versus-legacy routing below.** Independent reviewer `/root/legacy_scope_review`; no repository edits or Godot execution. Actual reviewed clean code head: `d431e3a8196d4bddefd5e6ae415052b712cf5b8b`.

This satisfies the conditions in `/tmp/plains_revision_legacy_scope_review.md`; it does not accept the old frozen-v11 failure, whole monster art or an unexecuted final full suite.

## User scope and exact preservation

AGENTS.md120–122 explicitly records the user's old-save/old-feature compatibility deferral and directs preserved frozen-history checks to explicit `legacy-compat`, without exempting current saving or gameplay.

I independently compared the actual JSON configuration against frozen pre-change `b479775383c46527096ebc6e4e284924f66ccf48`:

- The complete original `forest-depth-versions` check dictionary, argv, timeout210, marker, weight and artifacts are exactly unchanged. Every previous check entry is unchanged; the only new entry is `forest-current-registry`.
- Only `gameplay` and `full` replace that one old ID at the same ordered position with the current ID. `legacy-compat` adds the preserved old ID. Every other profile array is identical.
- Counts remain full166, gameplay151, docs/gameplay/art union163; physical partition remains91parallel/75serial. The new check has the same210 outer cap, weight20 and nonserial classification.
- Eleven old source/fixture files were byte-compared to the original commit: original Python wrapper, all three native GDScript version consumers, original Python reader tests and all recorded-layout JSON fixtures are unchanged. No old expected hash, ledger, assertion or original compatibility budget was edited.

The real old data run remains280assertions/2failures for the map1 exact-v11 fixture; its old327 aggregate/world phase was not reached. The interrupted Harness log contains57 completed passing checks, not a complete163 success. Those failures must remain visible as deferred compatibility evidence.

## Current guards retained as real consumers

`tests/forest_current_registry_runner.gd` independently expects `thorn-forest-region-v2` and `forest-bible-world-v15`, rather than obtaining its expectation from the producer.

The data portion actually requests four original contract seeds × both maps, requires whole unversioned output equal to explicit selected-layout output, strict validation and exact identity, then constructs coherently rehashed unsupported-version negatives. Seven distinct version/layout inputs cover unknown, empty and malformed requests without silent fallback.

The actual App portion creates the current default world for both maps. It checks HOME unknown-version/empty-seed refusal while preserving pending fields/state, full current App manifest equality, active replacement refusal without changing pending fields/Stage, current JSON snapshot acceptance and unknown/malformed snapshot rejection. It then saves real nondefault actor health plus claim/open/mechanism/actor ledgers, reloads the same current world and verifies manifest/hash/state/ledger/health preservation with a new actor instance. It drains owned audio and observes App release via WeakRef. These are declared setup fixtures, not earned combat, natural traversal or device proof.

The original `forest-bible-versions`, forest debug/campaign and other checks remain in their original default profiles. This is not a dummy passing replacement or a blanket omission of current version/saving behavior.

A precise coverage boundary remains: this new snapshot-negative probe edits `generated_layout.version`; it does not independently claim an exhaustive mutation of every output category. The full original compatibility probe for its historical categories remains executable unchanged, and the other default manifest/current-world checks remain. No total semantic equivalence to every historical327 assertion is claimed.

## Strict reader and executed independent mutations

Final Python reader `tools/run_forest_current_registry_tests.py` requires exact88 nonempty native checks,11 typed cases, all four seeds/two maps, seven distinct ordered refusal kinds, both actual App maps, current identities, boolean-success observations and finite positive saved/restored health. Boolean-as-integer schema/map fields and restored-health masquerading were found during this read-only review and hardened by the implementer before this verdict.

I executed the final reader directly against the actual dev04 capture, then independently mutated deep copies: **48checks/0failures, including47 refused corruptions**. Cases include zero/float assertion counts, missing/false/integer ledgers, missing/extra/duplicate cases, row and manifest map booleans, schema boolean, failuresFalse/nonzero, wrong scope/identity/seed/layout/version, missing manifest, false validation/equality/rehash-refusal facts, missing/duplicated/reordered/false refusals, App map corruption, false HOME/active/snapshot/reload observations and NaN/infinite/bool/zero/string health (including saved1/restoredTrue).

The actual source capture remained byte-identical after all mutations. Script and full results are `/tmp/review_forest_current_registry.py` and `/tmp/plains_revision_current_registry_regression.json`.

## Real native evidence and attribution boundary

I read the actual dev04 native log: `FOREST CURRENT REGISTRY: 88 assertions, 0 failures`; no script/parse/shader/ObjectDB/live-resource exit-failure lines were found. Its receipt has passed=true, source_stable=true and25.656316seconds. This is implementer-run evidence, not reviewer execution.

The dev04 receipt's base_commit is `b479775383c46527096ebc6e4e284924f66ccf48` with a dirty development source. Three subsequent Python type checks were tightened. Thus the old dev04 receipt is **not** a fresh native run of clean d431e3a8 or of the final tightened wrapper. Only the independent pure-reader acceptance and mutations above were executed against the final reader. The final default Harness must still execute the finalized consumer normally.

The wrapper retains strict `run_tests.run_engine` error/exit/leak rejection, import90/native90 caps within the outer210, unique fresh output directories, an exact original native completion marker, and before/after shared runtime/driver inventory using `level_formal.source_files(extra_paths=SOURCES)` including its four explicit callers. The inventory uses that existing helper's code/scene/resource/config/shader/JSON suffix contract; this review does not turn it into independent visual validation of every PNG. No source guard or error condition is suppressed.

## Remaining verification

This code/routing acceptance authorizes running the original default profile with the replacement current guard. It does not pre-sign final163, current full CI, old compatibility replay, user acceptance, sound, device performance or complete monster animation quality. Preserve actual first attempts and report fresh/reused counts and exact execution source honestly.

## Reviewed final source SHA256

```json
{
  "tests/forest_current_registry_runner.gd": "c9c2344e2393fd8bdf53d237a325e05a1821309086c39fa3589f0c04af383851",
  "tests/forest_current_registry_runner.gd.uid": "0143350db708a2512b81bb2824b1b4d1b720b803d3244266a218b1d0d201fef5",
  "tools/run_forest_current_registry_tests.py": "1e98bef0ef30c4199da59672f419e88a21c8aa4aeb4934576293a4561f032311",
  "tools/harness/profiles.json": "7e4309aaf8d6a5d30f05951db5035ed3e8f2fdb8bbcbae8413cc5d02379a05f9"
}
```
