# MAPGEN-GODOT-03 tools and sensitive-test independent review

**Static source/test changes are acceptable within the scope below; no old assertion removal or execution-budget relaxation found. Quality-record closure is still required.** Non-author, read-only audit against HEADe7d703f4 in `/tmp/gunman-rush-mapgen-03`. No production/test edits and no Python-test/Godot/browser execution by this reviewer. Earlier reports/failures are untouched.

## Original tests and historical profile projection

Independent AST comparison gives:

| File | Original → current test methods | Original bodies |
|---|---:|---|
| tests/test_production_plan.py |49→52|All49 exact; only two added decorators|
| tests/test_web_bundle.py |56→66|All56 AST-exact|
| tests/test_cloud_delivery.py |33→37|All33 AST-exact, including existing media tests|

The two planner historical methods retain their complete bodies/assertions and gain only `prior_frozen_host_profiles`. That decorator deep-copies the manifest, asserts the exact ordered four-check tail, removes only that tail from gameplay/full, executes the original method, and restores the current manifest in finally. It does not skip, xfail, mock the planner or replace original guard results. Thus the old171/172 and earlier reconstruction assertions remain executable on their explicitly historical inputs. A separate new test checks the actual current complete176-check plan, lane counts93+83, exact old ordered-prefix hashes, four new definitions and their scopes. The historical projection is justified as version adaptation and is not a claim that the current full profile has only172 checks.

Independent structured JSON comparison confirms all old220 check names remain. Full's original172 entries and gameplay's157 entries remain byte-for-byte ordered prefixes, followed by exactly the four new checks. All other profiles are unchanged. New inventory is224 checks, full176 and gameplay161. No original argv, timeout, serial flag, success marker or artifact path changed.

Two original definitions, web-bundle and web-resource-contract-tests, add explicit input filters where previously no filter meant all tracked source. This **narrows cache invalidation**, not execution semantics; it should not be described as all old check definitions being unchanged. The filter retains addons/assets/config/experiments/game/resources/scenes/scripts/shaders/tools/tests plus project.godot/export_presets, covering the actual inspected runtime/checker/test dependencies. Documentation/workflow-only changes no longer invalidate these two checks. Their changed check payload itself changes the cache key. No relevant read dependency omission was found in the reviewed checker/tests.

New generated native markers require positive check counts and zero failures, with line anchors; the real shared run_engine import/error/leak gate remains used, original90s editor cap remains, and native caps are180/240/240. The adapter adds explicit rejection of resumed-after-owner-free errors. Planner unit tests probe empty/zero/failed/partial markers, shared engine binding, exception propagation and exact arguments. Installation adapter executes both real default commands with check=True; it emits no synthesized success marker. Its60s Harness budget and two30s subprocess caps remain explicit.

## Installer and14 default tests

Original installer read_payload AST is unchanged: original ZIP/archive/member validation is retained. New installed_hashes pins all19 approved installed files, including the complete config lock. Offline verify-installed shares preflight, rejects missing/changed files and self-resigned config/code, and records candidate_archive_checked=false rather than claiming to have checked an absent CI archive. Install/archive-verify still require an explicit archive and compare payload pins before any writes; all targets are preflighted before writing the first missing target. Known engine UID companions are permitted; unknown addon/plugin/orphan UID and symlinks are rejected.

The default test script loads all14 test methods and prints its own real count/failure result. Most cases invoke the actual CLI subprocess against real temporary files, including default checkout verification. Two install/archive-verify cases stub only the archive-reading boundary with already-approved fixture bytes; they test actual CLI/preflight/write-conflict/idempotence behavior, **not** independent original-ZIP validation. This fixture boundary is explicitly documented and does not weaken the unchanged production archive reader. The tests do not download or run Godot.

## Web payload and delivery gate

New Web checker reuses the installer inventory/pins, verifies exact local config/dependencies, and reads actual PCK bytes. Only the exact resources/mapgen/module-pack-1.1.0.zip path is admitted, and only while installed config exists. Python/compiled-Python, docs/tests/tools/evidence payloads and other ZIPs are rejected. Original raw JSON/PNG/import/excluded-consumer closure remains in place.

Each of15 addons requires either exact pinned raw source or a normal remap with one safe res path and nonempty target; raw/remapped .gd bytes must match the approved SHA. A raw script cannot hide a broken remap. Unknown addon/data siblings are rejected. Compiled .gdc is checked structurally/present, not reverse-proved equivalent to source; original export-artifact custody and actual runtime remain separate requirements. New tests use actual PCK fixtures and include deletion, valid-MD5-but-changed bytes, coherent source/config edits, missing lock, missing/empty/unsafe/duplicate remaps, sibling ZIP/code/evidence, and exact finite preset paths.

Delivery adds one exact generated scene alongside the earlier exact frozen slice; old scenes-prefix traversal/backslash/control-character and actual PCK/report checks remain. Four new pure tests are added in a separate class; existing media methods remain unchanged and default unittest.main still discovers both classes. The new class mocks only Git/clean-runtime environment and tests real bundle/chunk/MD5/report/resource logic, plus original launch-flag injection. This is not a browser test claim.

## Quality card: concrete pending closure

At review time `docs/quality/records/MAPGEN-GODOT-03.json` still has no test_change_justification, independent_review.status=unverified with empty evidence, and affected_paths lists only the initial installation scope. It does not yet cover these sensitive test/check changes. `tools/check_quality_diff.py:536–542` requires a covering independently reviewed record with a nonempty justification for changed guards. This is a **record/approval-evidence gap**, not an observed assertion weakening; root was notified.

The actual justification should identify: two historical-prefix decorators preserve original bodies and are paired with full-current-prefix tests; new cases add real locked installation/memory/entry coverage; three mixed-key comparisons changed to exact typed scalar/text-key structure because the real probe showed canonical key-order differences, retaining original result/fingerprint non-mutation checks; original failures remain. Archive this actual review attachment and preceding source/runtime evidence, expand affected_paths to the real writes, and record only the passed narrow independent/static scope. Do not merely set passed or cite an uncreated future attachment. No quality/full-CI completion is signed here.

## Root execution evidence read, not independently run

Read original logs under `/tmp/mapgen-v3-audit` and verified markers with no script/parse/shader/owner-resume/ObjectDB-resource-leak lines:

| Log | Actual marker | SHA256 |
|---|---|---|
|generation-job-02.log|883 checks /0 failures|5f0d95712234e55e6f9d1cb80bcb5f42a083fdc77f47910c635bfed7fa183a6f|
|generated-slice-03.log|55 checks /0 failures|f14d008accf3460bc7561871470ebc64dfe39ab20954fb49fea2be5927413d6e|
|generated-identity-05.log|44 checks /0 failures|332c9307651ed26a90584d3ad248bfa3e85268fc73c09e3692ed5c3044c44bd9|

These support the corrected run scope and supersede no original failure record. This reviewer did not execute the processes or certify complete CI/Web/device/performance/full-map playability.

## Reviewed exact tool/test SHA256

- tests/test_production_plan.py:623fdbe76f0088d879bfb9390522ad16a461bd1e2b5c140b6824b8609ae37a38
- tests/test_web_bundle.py:2de4c9ef7955316ee3799f80553945f93e701b3ed215fd55edd24269e5bf8061
- tests/test_cloud_delivery.py:1fe7d1d1fec3903454bcb02ea8e750c3c7f6c0f574cfe5f74e0daed33e5aa1fb
- tests/test_install_mapgen_candidate.py:08695c3dfbb37b1dc9ca0245908cd4091c9c3539b72dcd3945b9d5394585ca78
- tools/harness/profiles.json:f00cc1c9ed9fd1af0076adb4bd31c7558ef9ef80b229b78913422151df65b971
- tools/install_mapgen_candidate.py:4c5c4b530c8b3cd241f153ebfd34b59ff7c1a6b87c642b47375b9448461c91af
- tools/check_web_bundle.py:27a0552531c388a18b90df96b6d52372f6315f4c47ff41945bbe95faa8c8aa0a
- tools/cloud_delivery.py:008766d65dc4fa82982a63f2c2a966c1793bf2529b5b1050fdc0a358c8026cdb
