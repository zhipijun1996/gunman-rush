# PLAYER-PRESENTATION-01 · M1 representative recovery sample

The real formal player now recovers its hidden weapon anchor after accepted recoil/hurt ends. This is a small attachment recovery fix, not a new body animation set or completed player presentation. Original recoil remains Courier's sole existing `shot_pose`; no Definition, alternate feedback bus, body pixel edit or gameplay implementation was added.

Runtime source: before `b9fe6b5a443ea911a34dc8fe7b0391b939f38331`; after `c77642fc89c34ff4c1a2083f1baa4f9a92bae21a`. The later task-only Preview/tests/checkpoint source is separate from these film source labels. [Versioned impact analysis](impact-v1.json) includes old/new script SHA, exact consumers and pending coordinator rebind. Style-v4 and all three body dependencies retain their original bytes; no old SHA was refreshed. Explicit versioned style rebind, independent review and cross-region revalidation remain pending.

Standalone Preview/tests and their Godot-generated own UID sidecars are frozen at `977b89a1f0ef2da9c672249c9bce3ccf38ee45af`. The final `python3 tools/player_presentation_01_tests.py` actually ran on that source: [full raw output](targeted-tests-final.log), [command/source receipt](targeted-tests-receipt.json). Both constituent tests pass at their original 27/11 assertions; no global profile or historical-quality rerun is implied.

## Actual evidence and falsification

The first hypothesis “weapon has no recoil” was rejected during M0 because disabled Adapter processing does not disconnect its signals. Actual formal trace then confirmed the narrower fault: visible body recovered idle while hidden Courier stayed hurt until the run ended. Its old shoulder pose differed from neutral by 3.375 world units vertically; this was an attachment position difference, not merely a state-name difference.

The fix only tracks the existing `PlayerVisualAdapter.RECOIL_POSE_SECONDS` window and returns transient hidden `hurt/recoil/machine_recoil/death` states to idle after current hurt/recoil/death has ended. Applied damage, session change and accepted segment return cancel the old recoil timer. Exported `recover_weapon_anchor` allows an explicit negative control. Pixels, body state selection, feet anchor, collision, Motor, input, physics, HP, resources, ability grants and shared damage feedback source remain unchanged.

| Actual film | Source | Media |
| --- | --- | --- |
| Before | `b9fe6b5a443ea911a34dc8fe7b0391b939f38331` | [movie.mp4](before/movie.mp4), [native log](before/native.log), [trace](before/trace.json), [source/media receipt](before/report.json) |
| After | `c77642fc89c34ff4c1a2083f1baa4f9a92bae21a` | [movie.mp4](after/movie.mp4), [native log](after/native.log), [trace](after/trace.json), [source/media receipt](after/report.json) |

These are actual continuous Godot MovieMaker recordings, each 735 encoded frames / 12.25 seconds, 1280×720 at 60 FPS, real 48kHz stereo track retained. Each driver records 720 action frames; the other 15 frames are real startup/teardown. They are normal playback, not stitched stills or a hardware performance claim. Audio track presence is verified; listening/user approval is not.

Frozen conditions: `DemoApp.start_plains("underworld-formal-integrated")`, map 1, normal initial spawn, actual run camera, Manifest `ac5a6654b8aab5ceb53451a767b9efaa665b3d0ec3a45e661ce976cbdb967d5f`, fixed 60, same literal Router schedule in the same hashed `tests/player_presentation_01_trace.gd`. Short walk right → reverse left while aiming right → accepted upward shot during left movement → explicit accepted policy hurt interrupt → recovery; second short turn and downward shot → hurt/recovery; terminal fixture at tick600 triggers actual run teardown/return Home. No later position assignment or resource injection. The three damage requests are **explicit lifecycle fixtures submitted to production FrameDamagePolicy**, not natural enemy combat.

[Exact comparison](comparison.json): all 720 selected per-frame Motor position/velocity/recoil, HP/terminal, energy, active/session and accepted counts match; accepted event lists are identical. Both recordings have two real accepted shots and three applied fixture damage events with no failures. Recovery changes hidden hurt to idle and corrects displayed/authoritative muzzle by 3.375wu. Muzzle coordinates and future projectile origins intentionally differ from the stale pose; this does not prove every projectile collision/route is numerically identical. All declared source inventories were stable during each recording.

The same comparison also confirms identical body frame selection/source pixels/facing and actual camera positions across both recordings. It does not substitute for an independent viewing of the films.

## Actual local checks and retained failures

- Original `python3 tools/run_underworld_player_animation_tests.py`: exit0, **607 checks / 0 failures / 583 real Motor frames / 7 states**, [original log](original-animation.log).
- New real-App lifecycle checks: **27 / 0**, covering accepted shot→hurt interrupt→recovery, paused timers, duplicate/stale damage refusal, configured-off counterexample, session/segment return, terminal unload→Home, fresh new run and old-token refusal. [Native output](lifecycle-native.log), [structured result](anchor-tests.json).
- New standalone Preview native smoke: **11 / 0**, actual formal scene, Router/Motor movement, accepted fixture/switch/recovery and restart. [Structured result](preview-smoke.json). Calls exercise actual control callbacks; browser pointer/touch GUI remains unverified.

Failures are retained, not overwritten: [first motion schedule native failure](first-schedule-failure.log) and [full trace](first-schedule-failure-trace.json) show a long initial walk ran off the real starting platform, creating two additional environment damages and failing the exact count. The driver was shortened before freezing either comparative film; no terrain/gameplay changed. The initial stage-initialization probe also failed at `trace.gd:86` because the deferred stage was not yet ready; eight initial physics frames were then observed as in the original formal test. The initial lifecycle run submitted damage during authored spawn protection and failed six assertions: [original failure](lifecycle-first-failure.log), [result](lifecycle-first-result.json). Only the fixture waits were corrected to respect the original protection, never its duration or production policy.

## Independent operable Preview source

Entry: `res://scenes/dev/player_presentation_01.tscn`, backed by `scripts/dev/player_presentation_01.gd`, a task-specific subclass of the real DemoApp. It starts the same formal Seed/map with normal controls and session-only meta. Controls: `RECOVERY ON/OFF` for the negative control, `HURT FIXTURE` for an explicitly requested production-policy hurt, `RESTART SAMPLE`. Ordinary game/menu input is retained. No formal menu, DemoApp source or central configuration changed.

The native scene and callbacks were actually exercised. This checkpoint does **not** claim a Web build, browser GUI, independent public URL, hosted download or user/device acceptance. The coordinator owns Web export/independent hosting capacity and actual public verification. Its existing generic-scene bootstrap can consume this exact path; no new shared interface is required. New dev/script/test paths retain conservative full routing until the coordinator registers audited development impact; this line did not edit Harness/config to shrink it.

## Recovery and next commands

All commands run in `/workspace/worklines/player-presentation-01` after `source /workspace/worklines/player-presentation-01-env.sh`.

```sh
python3 tools/player_presentation_01_tests.py
python3 tools/run_underworld_player_animation_tests.py
# Only in an assigned GPU slot; always use a new output directory:
python3 tools/player_presentation_01_trace.py --output build/player-presentation-01/next-fresh-film --movie
```

Production write set remains exactly `scripts/underworld_plains/underworld_player.gd`; other additions are task-specific Preview, tests, driver, evidence and quality record. No PR, complete CI, main merge, shared style rebind or publication was performed by this line. The existing same-source main global quality/Integration146 and common 0ee docs33 receipts are inherited coordinator evidence, not this line's fresh checks. The M0 global sparse-history quality failure remains preserved; no broad history restoration/repeated scan was performed.

Next stage is the coordinator's independent code/media review, explicit style version rebind with affected formal consumers, precise planner registration, Web export and actual independent URL/browser verification. Technical samples do not sign continuous-animation aesthetics, operation feel, natural combat, full weapon/region coverage, complete player presentation or physical device acceptance.
