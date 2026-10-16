# Visible capture input transport — independent scoped ACCEPT

Reviewer `/root/v3_preflight_independent`, read-only production review. Reviewed exact frozen `tests/level_formal_trace.gd` SHA `37ac033ff27dcb0e1996416b60b2bfacfad3bd7e87ff16809c0f30565d01454b` and `tools/level_formal_capture.gd` SHA `b67e7f058763aa244f1391e23ff0a064dffd546922f75945992dff0059f5546a`.

**ACCEPT is limited to the controlled input-transport scheduling fix and instrumentation scope.** No complete formal route/movie, all helper outcomes, novice/device performance, commercial art or user acceptance is signed. This review actually ran Godot4.7.2 with the shared engine wrapper, LP/OMP1, Xvfb/llvmpipe and dummy audio; no paid host/image call or production-source modification occurred.

## Independent real execution

The reviewer copied the author's controlled fixture to a new ignored path, retained its real Player/InputRouter/normally scheduled Controller and added only observation: actual shot_fired calls the unchanged driver.event with the actual Controller tick; full driver frames are saved. No controller.physics_tick/move_and_slide call, resource grant, position rewrite after fixture spawn, timestamp refresh, request retry or enemy disabling was added.

Actual fresh result, exit0:

| Case | Observer queue age | Actual shot accepted |
| --- | --- | --- |
| legacy predraw with controlled process stall |136.799 ms|0|
| postdraw genuinely new request|0.133 ms|1|
| postdraw new request deliberately aged130ms|130.322 ms|0|

Across all111 observed fixed60Hz frames, trace ticks are sequential, actual controller_tick increments exactly1 per observed frame, and process-after controller_tick equals preconsume signal controller_tick_before+1. The single accepted actual shot is driver frame74 / Controller74 / event tick74. No missing/shifted frame or accepted event was observed in this fixture. Every case retains exact original request timestamp and sequence at the preconsume boundary. Actual Router epoch/0.1-second age limit remain untouched. Expired actions are silently dropped by the original consume_actions code; zero action_rejected signals were not misrepresented as a rejection receipt.

Raw actual probe, invocation/environment,111 frames and independent alignment analysis are retained here. This proves the controlled old scheduling failure and new scheduling behavior; it does not prove TTL caused any historical movie failure lacking ages.

## Static integration review

Independent byte comparison finds only `tick` and capture `run` function bodies changed:27 other trace functions and12 other capture functions remain byte-identical to the saved prechange sources. The Router, Controller, Motor and both strict27+9 Python verifier files match committed HEAD and the author's frozen hashes exactly. The new dictionaries only copy observed metadata; they do not mutate the Router queue or forge controller-consume receipts.

Visible capture explicitly enables the protocol only when --capture-visible is supplied and the DisplayServer is not headless. After the existing physics_frame→process_frame snapshot, tick waits for RenderingServer.frame_post_draw before returning to helpers; the first visible run_route invocation also starts at that signal. Headless/nonvisible paths retain old deferred entry and no postdraw wait. Input timestamps are created once by the unchanged production request API. No original TTL/attempt/resource/collision/physics assertion was weakened.

The live formal entry uses attach, not inherited standalone fixture/run paths. The live inherited traversal helpers pass the bound overridden tick callback through BranchModuleDriver.advance, ShotLatchModuleDriver, ferry/recoil and exploration-motion helpers. Their standalone testing physics_tick routines are not called by this formal attachment. The one reward-modal process_frame loop waits for the real UI modal; following submissions return through tick(3) before the helper completes. The observation-only fixture does not execute every one of those gameplay branches, so full-route runtime coverage remains required.

## Important limits

`input_timing.scope` correctly says `observer_preconsume_boundary_not_controller_receipt`: physics_frame observation is before normal Node physics, not instrumentation inside actual consume_actions. The controlled fixture verifies that ordering for its sampled frames; the metadata must never be relabelled an engine-consumption receipt.

RenderingServer.frame_post_draw is a rendering signal. This review does **not establish that every MovieWriter encoding operation or every other postdraw subscriber has completed before the continuation**. The source comment mentioning rendering/encoding is not evidence of backend ordering. Full-map recording load can add later wall delay and must be evaluated from new actual ages and accepted events; preserve a subsequent failure rather than refreshing timestamps, changing TTL or adding hidden retries.

All complete movies and route proofs must be freshly captured on the new driver bytes. Previous80-case or old-film evidence remains historical and must not be reused as a same-driver before/after claim, even where the headless control flow is unchanged. Independent proof here covers actual shoot acceptance and sampled frame alignment, not all action types, complete route or movie outcomes. No historical failed movie was altered or retrospectively labelled TTL-proven.
