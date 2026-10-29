# PLAINS-MONSTER-REVISION-01 · legacy scope routing review

Reviewer `/root/legacy_scope_review`, independent and read-only. No repository edits and no Godot execution. Reviewed clean source `b479775383c46527096ebc6e4e284924f66ccf48`, the actual failed native data log/report and current profile/registry/test sources.

**Decision: REVISE an unconditional whole-check removal; ACCEPT a scoped routing repair which preserves the original compatibility check and retains its live current-version guards in the default suite.** No old frozen failure is accepted or reclassified as PASS.

## Applicable user instruction

`AGENTS.md:120–122`, 2026-10-23, explicitly records the user: “暂时可以不考虑旧存档旧特性兼容。” Its operational instruction is: “旧存档迁移、冻结历史版本回放暂不作为合入／发布前提。原断言与检查保留，legacy-compat 为显式手动 profile；未执行记延期／未验证，不能记通过。” It also explicitly does not exempt current saving, gameplay, resources, export or real playtest regressions.

This instruction applies to exact frozen v11 manifest/hash replay across changed current EnemyDefinition bytes. It does not authorize deleting current registry refusal/selection checks, changing old fixture hashes, or falsely declaring old layouts compatible.

## Actual failure and mixed scope

The source log `build/plains-revision-integration-03.log` records **57 completed passing checks**, then starts `forest-depth-versions`. No final Harness report was present after the environment interruption. Do not synthesize a successful or complete aggregate.

The actual native `build/forest_depth/versions/native/harness-8616e90005c240cdbc8d43fe6e6cce85/data.log` ends **280 assertions, 2 failures**, both map1 exact-v11 replay:

- entire final v11 fixture and exact old hash rebuilt map1;
- actual final v11 original validates map1.

The data receipt says exit_code1. The original327 aggregate is not reached and its separate world consumer has not run in this attempt. Keep all original logs, data, receipts and old fixture bytes.

`forest-depth-versions` currently occurs in only `gameplay` and `full`, not `docs` or `art`. Its check entry has original argv `python3 tools/run_forest_depth_versions.py --output-dir build/forest_depth/versions/native/harness-{check_token}`, timeout210, success_pattern`^PASS:`, weight20 and artifacts`build/forest_depth/versions`. It is not currently in the explicit legacy profile. Preserve that complete original entry and all its native/Python ledgers and fixtures.

It is **not purely historical**:

- `tests/forest_depth_version_runner.gd:31–74` also tests the live unversioned registry's independently expected public version, complete output and validation across4 seeds×2 maps, plus explicit unknown/empty version refusal and malformed capability version refusal.
- `check_fruit_contract` additionally checks the live default V15 layout against independently expected complete explicit output.
- The separate world process is explicitly original v1 App compatibility and hash-bound saved-state/actor reconstruction.
- Most other data cases are pinned historical v1/v7/v9/v10/v11/v12/v13/v14 contracts and exact old recorded payloads.

Thus describing the entire check as “only old fixture playback” would omit real current guards.

## Current coverage already retained elsewhere

The public registry's actual selected layout is `forest-bible-world-v15`. `forest-bible-versions` retains both current V15 candidate data/strict manifests and two actual unpinned public App map consumers; `forest-debug` and `forest-campaign` independently check actual selected public version/layout and Boss paths. Keep those original checks unchanged.

However, the explicit registry malformed/unknown-version and actual HOME/active-request refusal-without-mutation checks are primarily in the mixed older version test. The current Bible runner is not a blanket replacement for those refusal guards. Do not claim complete replacement solely from its name or56 assertion count.

## Minimal safe recommendation

1. Retain `forest-depth-versions` byte-for-byte as an executable check and explicitly include it in `legacy-compat`; its current real v11 failure remains deferred/failed, not green. Do not edit old fixture bytes/hashes, generation authority, strict source validation, original327 ledgers, caps or native teardown rules.
2. Before removing this mixed check from default profiles, retain its live current responsibilities in a small default current-registry check. An explicit one-for-one default replacement preserves166 full checks,151 gameplay checks,163 docs/gameplay/art union and91/75 physical-lane counts; it is preferable to silently reducing a hardcoded total. This is a real current consumer, not a dummy passing wrapper.
3. That current check must independently expect version`thorn-forest-region-v2` and layout`forest-bible-world-v15`; cover4 seeds×both maps, unversioned whole output equal to the explicit expected layout and actual strict validation; preserve unknown/empty versions and malformed capability-version refusal. Include actual current App HOME/active invalid-request refusal with pending request fields/state/active Stage unchanged, both current maps, and original strict audio/ownership teardown. The existing public App/Bible checks remain.
4. Run the new default consumer's positive and meaningful negative cases, exact profile/lane selection tests and actual affected checks. A profile change needs independent test-scope review and test_change_justification. Keep the original failed compatibility run accessible and explain the scope change in the workline/quality/PR records.
5. If choosing only a count-reducing profile move instead, explicit equivalent current guards must still be preserved elsewhere and independently demonstrated. Report the reduced selected scope honestly; do not call162 a passed163. This review does not approve dropping live guards for speed.

This does not require user permission again: the historical-replay deferral is already explicit user authorization. It also does not require restoring old production geometry solely to satisfy historical frozen inputs. Current forest placement, current saving and current playable consumers remain mandatory.

## Boundaries

This is only a scope/code review. It does not execute the proposed new check, sign a changed profile, sign the original failed compatibility suite, replace current regressions or approve monster art/user/device quality. The proposed routing remains to implement and verify. No current check or original budget has been modified by this reviewer.

## Read source hashes

```json
{
  "AGENTS.md": "2120a8f2321d41abec3936e36656afa27dad5be05caa45496e7984a25eb65791",
  "tools/harness/profiles.json": "aaf74f9286b275455ab0f7e967f1d4d51fc0fe2c036223431a05418144cad6f3",
  "scripts/generation/thorn_forest_region_generator.gd": "203e3fc032d3ec3b6dd6fb81cb967533773797e14d580628964ef74e3faac1e6",
  "tools/run_forest_depth_versions.py": "b38a4861c8acfd04374fbb0362dcf6127aee90dc11d7e65d47ef290434eaf94c",
  "tests/forest_depth_version_runner.gd": "f5fae251fcda79370ba3b8fac8bb4f66fee65bd85e6a63031dfd1420dce74750",
  "tests/forest_depth_version_world_runner.gd": "4e9eed97587582285cef0a4d07438c30f34a84fc67c0b03ee1102f6f9de59059",
  "tests/forest_depth_version_app_case.gd": "2632f7744906afc1929225d5731b6ee2d02f95001a40c8a727fa70f97c3e8274",
  "tools/run_forest_bible_versions.py": "e198147843f34b0e910fc0a6501391d4c52c62a327d75bc06a4d51062903518a",
  "tests/forest_bible_versions_runner.gd": "2cfade31c614eb1672bbf711cd1ed10de4cfe27f6a7e7cc07b5affab52d7fe13",
  "tests/forest_progression_debug_runner.gd": "14745db1ea391d6a4ef35246bad2afb28dca8c51bc6a8052e84425d8eb1684a4",
  "tests/forest_campaign_runner.gd": "c51a23eb1554cd40bf5cd09160392e2dc58772be3e4225ff6a0b1dcb3cdd71e4"
}
```
