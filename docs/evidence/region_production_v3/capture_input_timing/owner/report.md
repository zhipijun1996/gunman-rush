# Visible capture input transport: actual controlled reproduction and minimal repair

Scope: test transport only, with `game-quality-gate`; no gameplay, Router, Controller, Motor, resource, strategy helper, rendering or old evidence modification. Only `tests/level_formal_trace.gd` and `tools/level_formal_capture.gd` changed. Not a formal-route, performance, fairness, device or commercial-art acceptance.

## Actual reproduction

`probe.gd` instantiates the original Player scene on a fixture floor. Its original Controller remains normally scheduled; the actual production `level_formal_trace.tick()` drives observations. No manual physics_tick/move_and_slide, timestamp/epoch rewrite, resource grant, enemy disabling or actor reposition after fixture spawn. One `_process` call deliberately blocks 130 ms, guarded by the actual Controller tick so it occurs during the observed draw frame. This is a controlled wall-clock transport experiment, not game/device performance.

| Case | Actual observer preconsume age | Actual shot accepted | Router rejected signal |
| --- | --- | --- | --- |
| legacy_predraw | 0.135960s | 0 | 0 |
| visible_postdraw | 0.000157s | 1 | 0 |
| postdraw_new_request_deliberately_expired | 0.130305s | 0 | 0 |

R2 actual exit 0 and `VISIBLE INPUT TIMING PROBE: true`; original log/invocation/source hashes retained. This proves the controlled scheduling failure and candidate boundary. It does not retroactively certify TTL as the reason for old movie failures: those original recordings did not observe request age. Old failed movies/AVIs and evidence are untouched.

R1 genuinely failed the reproduction assertion: the fixture armed its delay before the relevant physical frame, so legacy request age was only 5 ms and accepted. Its complete source, result, invocation and audio-fallback error log are preserved under `probe_r1/`. R2 fixes only fixture scheduling with an actual Controller tick guard, and explicitly selects the dummy audio driver for this silent transport fixture. It does not change production core or weaken expected expiry. The final negative still deliberately expires a newly submitted postdraw request and the original Router drops it.

## Repair

Visible real-display captures explicitly use `visible_post_draw_v1`. After the unchanged physics-to-process snapshot, tick waits for `RenderingServer.frame_post_draw` before returning to route helpers. The first route invocation also starts at that boundary. New actions use the unchanged request API and actual Time timestamp; no queued input is refreshed, resubmitted or retried. Headless/nonvisible capture keeps the original deferred launch and tick scheduling, with timing observation disabled. Captured scope identifies the protocol and observer, and actual driver hashes change in existing policy_basis.

Only `tick` and capture `run` function bodies changed; all 39 other function bodies byte-identical to the prechange snapshots (see freeze.json). Existing resource/collision/accepted-event snapshots, frame budgets, policy attempts and strict 27+9 verifier code are untouched. Three core source hashes and both verifier/test hashes equal current committed HEAD. Actual capture script `--check-only` compilation also exited 0.

`helper_await_audit.json` follows 16 recursive GDScript sources. Runtime route helpers await tick/advance or wrappers that reach the same tick. The direct process wait in claim_required_chest waits for the real modal to open; its subsequent real submission calls tick(3) before returning. The extra physics waits in inherited standalone test run/fixture functions are not live formal-route execution paths. All jump/release/drop/interact/shoot APIs remain unchanged. Actual fixture acceptance is demonstrated for shoot only; complete multi-action formal-route and movie validation belongs to the parent final run.

## Remaining verification / comparison boundary

Full fresh native and normal movie captures must use the new frozen driver. Existing 80-case/headless and old films remain original evidence, not same-driver comparisons with this new visible protocol. Even when headless logical scheduling is unchanged, source hashes differ. Timing rows are `observer_preconsume_boundary_not_controller_receipt`; absence of accepted events alone still does not prove TTL expiry. Godot/backend movie encoding or another postdraw subscriber can add subsequent wall delay; this controlled fixture does not promise all real recording loads stay below TTL. The parent must inspect actual new movie request ages and preserve any subsequent failure rather than adding request retries or changing the original Router limit.

No full movie or paid image/host request was launched by this slice. Engine used shared lock, software GL and LP/OMP=1. R2 engine wall time (including lock/startup): 3.623s. Independent review remains pending.

Frozen sources:

- `tests/level_formal_trace.gd`: `37ac033ff27dcb0e1996416b60b2bfacfad3bd7e87ff16809c0f30565d01454b`
- `tools/level_formal_capture.gd`: `b67e7f058763aa244f1391e23ff0a064dffd546922f75945992dff0059f5546a`
