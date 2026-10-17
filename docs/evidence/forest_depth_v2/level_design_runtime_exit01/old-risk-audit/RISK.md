# Known strict-exit risk: level-design-runtime

**Affected preflight is justified before final full CI.** No fix for this particular consumer is present. Current exact native behavior has not been tested by this audit, so this is an unresolved known blocker, not a new native FAIL or proof of a unique resource-cycle cause.

The CDA remote check exited1 after6.765s, within its original720s cap. Its connector traceback identifies `tools/run_level_design_tests.py:16` (the capability script subprocess) → `tools/run_tests.py:47` (strict ObjectDB/resource-exit guard). The remote artifact lacked redirected `capability.log`, so remote owner counts are unknown. The preserved same-commit local log records `LEVEL CAPABILITY: 41 assertions, 0 failures`, followed by232 leaked ObjectDB instances and170 resources; those counts apply only to that local execution.

`receipt.json` independently records old/current SHA equality for ten concrete files: the wrapper, strict process runner, capability SceneTree runner, snapshot sidecar, level trace, parent plains trace, BuildState, PlayerTuning, FoundryCatalog and player scene. The current capability runner still preloads the snapshot/Player scene/level trace, uses BuildState and typed Player objects, frees its Motor and quits from the SceneTree callback. It has not adopted the later campaign/version Node execution boundary. Those later helper changes are in different consumers and do not establish clean exit here. Historical capability-specific ownedNode/dynamicBuild+Trace attempts were already failures; do not blindly repeat them or infer that one similarly named Node change fixed this graph. Selected equality does not assert the entire transitive resource graph or engine environment is unchanged.

Recommended single affected target, after ecology releases the global slot and using a guarded fresh runtime snapshot with explicit4.7.2 environment/independent userdata:

```sh
timeout 720s flock /workspace/gunman-rush-design/build/verification/engine.lock env GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains GUNMAN_DATA_HOME="$PWD/build/risk-userdata" XDG_CONFIG_HOME="$PWD/build/risk-config" XDG_CACHE_HOME="$PWD/build/risk-cache" python3 tools/run_level_design_tests.py
```

This preserves the exact registered target argv (`python3 tools/run_level_design_tests.py`), original720s outer budget, original120s editor import and120s capability subprocess budgets, subsequent capture/analyze behavior and strict leak checks. Save `build/level_design_v2/capability.log` plus stdout and before/after source inventory. On the known early strict failure, stop before final full CI and diagnose that actual source/log; do not weaken guards or count41/0 as PASS. A successful existing full wrapper would resolve the actual target risk more directly than another broad profile run. No native was launched, no production/test/doc source was changed by this audit.

Portable old source: `docs/evidence/forest_playable/final/ci_monitor_cda8c30_failed_remote_evidence.tar.gz` (remote report/connector) and `capability-exit-and-two-lane-failures.tar.gz` (local log/diagnoses/failed candidates). Selected excerpts retain their actual scopes. Later forest/App partial successes and default promotion checks do not replace this target.
