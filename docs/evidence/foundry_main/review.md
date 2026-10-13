# Independent Foundry/main integration review

2026-10-13. Scope: explicitly authorized integration of Foundry and mobile fixes into latest main; enhanced player feedback/export and optional enemies. Reviewer does not implement gameplay.

## Initial constraints / counterexamples to check

- Preserve latest main's one-way-platform boundaries, Boss safe exits, input adapters and sole PlayerMotor ownership; do not replace main wholesale with old Foundry branch.
- Foundry remains an independent development consumer: no Run/Meta settlement, no save writes beyond its own feedback file.
- EnemyActor has no automatic reward consumer. Safe reuse requires setting definition before scene enters tree, local FrameDamagePolicy.bind_damageable, EnemyAttackBehavior.bind_encounter with local lifetime/unique source IDs/protected anchors, and actual DemoContactEmitter disabled on defeat.
- Segment returns must retain enemy HP and phase; obsolete enemy projectiles must be cancelled by actor epoch. Switching/leaving must remove stage-owned enemies and sibling projectiles.
- Existing accepted replay is a geometry/motor proof, not automatically a proof that optional enemy variant is damage-free. Optional encounter metadata must be explicit in feedback/revision jobs and player replay UI; do not label enemy encounter as validated solely using original unopposed replay.
- Feedback free text must be bounded and sanitized on import, preserve manifest/capability/encounter and version context, and avoid accidental formal save export. Exact repeated reports should remain meaningful; AI must receive actual player observation rather than only canned labels.
- Touch-specific UI needs actual InputEventScreenTouch checks; latest mobile fix prevents modal popup windows. New text editor/feedback panels must be usable while paused and restore gameplay input safely.

Status: waiting for integrated source to run adversarial review. Existing API review only; no integration pass claimed.

## Frozen implementation review (native 4.7.2; baseline main 7f0e433)

Independent reviewer `/root/lab_main_review`, separate implementer `/root`. Invocation: repository gameplay-reviewer SKILL.md and general review method. Reviewed working tree based on integration commit 8712fdde887bd3c646332afc18268bfb8940d1c0; implementation is not frozen final commit yet.

Findings retained:

1. **REJECT / feedback failure coverage:** original `open_feedback` guard required ready_for_play, but `_fatal` clears that flag. Zero-health failures could not be described with free text. Implementer changed guard to require selected/valid actor rather than successful active play; independent native recheck confirms modal opens after fatal failure. `review_fatal_recheck.txt`.
2. **REJECT / modal drawing:** ActorResourcesHud was added after the modal blocker, drawing ENERGY text inside the feedback TextEdit. Actual touch screenshot `independent/touch-feedback-text.png` showed overlap. Implementer moved blocker last; final exported browser recheck pending.
3. **Harness failures, not production defects:** initial reviewer used nonexistent InputRouter API; second run met stale batch during implementation edit; combat harness inferred WeakRef Variant warning; first browser save coordinate missed button; CDP insertText did not synthesize Godot canvas keypress. All raw failures retained and explicitly distinguished from product defects.

Observed passes within stated scope:

- All 12 topbar Buttons fit 1280 logical viewport (rightmost x802). Native runtime fatal feedback restored and pause state handled.
- Actual controller `shoot_release` produced a real projectile and damaged local enemy HP3→2; segment return retained injured health; module switch freed old enemy; Meta snapshot unchanged. Four assertions pass, clean combat fixture exit (`review_enemy_runtime.txt`). This fixture explicitly starts on the enemy platform; it does not prove a complete entrance-to-enemy traversal.
- Touch-only Chromium emulation 844×390: open modal, tap TextEdit, type ASCII via keypress, save, actual download schema2 with exact note and reproduction Manifest. Enemy-mode button remains touch-accessible. `independent/touch-result.json`; no script errors. Chinese Android IME and physical-device keyboard remain UNVERIFIED; inserting Chinese directly in native tests only verifies storage/codec.
- Actual downloaded feedback becomes an AI revision job retaining note and exact Manifest, priority1 (`review_feedback_queue.txt`, `independent/revision_jobs.json`). Malformed schema2 manifest42 rejected with exit1 (`review_malformed_cli.txt`).
- `python3 tools/quality.py check` exit0, no structural record errors. Incomplete G5/device/player dimensions correctly remain unverified; consistency pass is not gameplay certification.

Limitations: optional patrols are development combat previews with no damage-free enemy-mode path certificate; original platform replay is explicitly refused while enemies enabled. No claims of creative quality, full enemy encounter balance, every profile/seed/device coverage, or autonomous ongoing model execution. Fatal fixture retained an EnemyActor reference through exit, producing ObjectDB/resource exit diagnostics in its raw log; separate combat fixture cleared references and exited cleanly.

Current verdict: native/API/queue checks ACCEPT within scope; modal rendering recheck and final reviewed content SHA pending, overall device/player acceptance UNVERIFIED.

## Final scoped recheck / verdict

Final local exported build **38a2bb550069**, reviewed working tree based on integration commit8712fdde887bd3c646332afc18268bfb8940d1c0. `review_touch_final_runtime.txt` and `review_touch_modal_block_runtime.txt` exited0. In actual touch844×390 canvas, feedback TextEdit receives ASCII keypress, Save closes and restores play, and download contains exact note plus schema2 reproduction Manifest. Touching underlying module and Return while modal open does not close/switch the challenge. `independent/touch-modal-blocks-underlying-ui.png` confirms ENERGY HUD no longer overlays first text line. HUD finding is **REJECT → fixed → recheck passed**. Independent final feedback suite: 11 assertions,0 failures (raw `review_final_feedback_suite.txt`).

**Verdict: ACCEPT for scoped main integration/development Lab APIs, note storage/export/AI queue, optional enemy damage/lifecycle and touch-modal rendering tested above.** Overall complete gameplay/device/player acceptance remains **UNVERIFIED**: these are opt-in patrol previews, not balanced certified enemy challenges; browser touch emulation is not a phone, and Chinese Android IME was not verified. No technical verdict extends to all seeds/profiles, subjective fun/art quality, or automatic recurring model modifications.

## Additional mobile virtual-keyboard counterexample

Parent found exported experimentalVK=false after prior scoped review. ASCII synthetic keypress acceptance did not cover a physical phone's keyboard activation, which remained UNVERIFIED. Enabling `html/experimental_virtual_keyboard=true` creates Godot-owned INPUT/TEXTAREA elements, but independent actual ScreenTouch tap into TextEdit leaves activeElement CANVAS and both controls display:none (`review_touch_vk_runtime.txt`, assertion failure). **REJECT for mobile keyboard activation until explicit touch/VK activation is fixed and rechecked.** This does not negate prior stored-note/codec/desktop-keypress tests; it exposes their scope limit. DOM Chinese insertion must be performed only after actual user touch activates an input; force-focusing DOM would not prove production control works.

## Virtual-keyboard fix final recheck

Initial config-only trace refined the failure: after opening modal, TEXTAREA was active; retapping the field moved focus to CANVAS and hid it (`review_touch_vk_trace.txt`). Config-only open→type Chinese→save/export passed (`review_touch_vk_open_runtime.txt`) but did not cover retap.

Implementer added explicit TextEdit ScreenTouch pressed virtual_keyboard_show and close_feedback virtual_keyboard_hide; Web export experimentalVK=true. Independent final exported build **2b140910078a**, source commit **dbd93007df7328b7133f8971a2577284c9e87009**, strict ScreenTouch retap fixture passed: click feedback, retap note field, assert actual browser activeElement TEXTAREA with display:block, CDP inserts Chinese through the active engine-owned VK input, Save, actual schema2 download note exactly `敌人挡住落点，移动平台卡住。`. No DOM force-focus or game-state injection was used. Post-save enemy-mode touch works; no script errors. `review_touch_vk_retap_final_runtime.txt`, `independent-vk/touch-result.json`, screenshot/export/fixture files.

**Mobile VK finding REJECT → fixed → browser-emulation recheck passed. Final scoped technical verdict ACCEPT.** Real Android/iOS keyboard presentation and OS IME behavior remain UNVERIFIED; browser DOM input proves Web text handoff, not physical phone testing. Previous native/controller/enemy/AI queue scope and player-quality limitations remain unchanged.
