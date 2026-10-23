# FOUR-LINE-INTEGRATION-01 · formal player assembly

Runtime source `908ac83a3e2b1668171e0cb676ebcb2ce60f4145`, private branch `feature/player-default-integration`, base `f38c6087e17efdd60f08965c65e50627a6fc7057`. This adopts the externally supplied player version `b1069762731e0cdb39f003f2dd2474ba5d8de058`; it does not reuse the other internal 28-line recovery candidate.

The real main scene is unchanged. Actual Home and shared-pixel Plains/Forest assembly now create the author's new idle/fall/motion body by default, attach existing MotionFeel and weapon V2, and share one PlayerWeaponFeelAudioV2 service with the latest V3 timer. Original GameAudio cues, volume and twelve-voice pool remain inherited. Preview hosts, equipment menus, training targets and debug controls are not installed.

The existing `character` Home service retains its id, authored position and interaction. Its live world label, nearby prompt and service menu now say **织时匠**. The menu offers new courier (`courier`, default) and classic courier (`courier_classic`). Classic instantiates the actual UnderworldPlayer leaf and restores original jump/land listeners and cues; weapon V2 remains available. Legacy `p1_traveller` / `p1_girl` definitions and explicit consumers remain present, but unfinished appearances excluded from Web are not listed at the formal NPC. The former floating appearance selector stays hidden.

Selection uses the existing App/AvatarPresentation session field across Home, region starts, death and retry. No preference persistence, Run/Meta schema, progression/ability/stat, damage, Motor, resource policy or main scene change was made. Current one-shot/time-energy behavior remains intact.

`PlayerPresentationRuntime` supplies only the finite factory/attachment adapter. Binding is idempotent; classic/new swaps detach old owned feedback before replacing the body. The production weapon leaf restores/frees its projectile children on cancellation/detach and rejects old owner/session/weapon identities. Removal restores the original Runtime renderer/audio callback and legacy shot listeners. The author leaf scripts, body atlases and existing Underworld base remain unchanged.

[Runtime references](runtime-references.json) lists concrete production callers, adopted readonly scripts, `.tres`/clip/shader/banks, explicit visual JSON/catalog reads, 70 literal audio preloads and unchanged inherited body reads, each with full SHA. This is the handoff for the coordinator's style-v7 consumer binding; original v6 and its Underworld20 references are retained by the coordinator, not refreshed here.

Actual validation on the exact runtime source: **235 checks / 0 failures**, clean native exit and audio teardown. [Command/source receipt](receipt.json), [full raw log](final-native.log), [structured observations](result.json). Coverage includes:

- Real main-scene default Home and live Timeweaver label; Router/Motor walk to the unchanged NPC; actual interaction and native control callback selection.
- Both appearances in real Plains and current Forest-v15 map1 consumers; single visible body, correct catch renderer, repeated binding without extra listeners/renderer, one SFX service and twelve voices.
- Original classic and new movement jump/land cues each accepted exactly once; actual shots preserve the current time-energy policy; pause freezes body state.
- Actual policy terminal-damage fixtures unload each region and return Home, preserving selection; actual retry starts the selected new default. These are explicit presentation lifecycle fixtures, not natural campaign completion.
- Wrong actor/old weapon/old session projectile counterexamples; real accepted laser owns one looping voice and actual pause cancels it; accepted segment return clears old projectile leaves.
- Detaching production feedback restores original Runtime/audio/listeners and a subsequent real accepted shot emits exactly one old shot cue.

Two real failures remain preserved. [Initial Home-ready failure](first-home-ready-failure.log) exposed that formal Home assembles before the original lazy weapon Runtime exists; production now uses the existing `ShootAbility.behavior()` accessor. [Early laser fixture failure](early-laser-fixture-failure.log) / [result](early-laser-fixture-failure.json) attempted a beam before the original pending shot cooldown expired; only the fixture now waits for that existing cooldown, with no timer change or resource injection.

Recovery command, after `source /workspace/scratch/integration-four-20261023/player-default-env.sh`, in `/workspace/worklines/player-default-integration`:

```sh
python3 tools/run_player_default_integration_tests.py
```

Harness candidate argv: `python3 tools/run_player_default_integration_tests.py`; completion pattern `^PASS: Formal default player, Timeweaver selection and feedback lifecycle$`. Inner strict marker is `PLAYER DEFAULT INTEGRATION: checks=235 failures=0`; original `run_engine` enforces its 180-second bound, native errors, nonzero exit and leaked resources. No Harness/config changes were made by this line.

This is a working formal assembly with native interaction evidence. Browser GUI, actual new Web build/public deployment, full Integration/Release, independent visual/listening review, aesthetics and physical-device acceptance remain unverified. No global quality/history scan, full CI, PR or main merge was performed here. The coordinator owns cherry-pick integration, the adjacent GameMusic `volume_source` hookup, versioned style binding and final publication. Only this private tree was edited.

Quality ownership remains with the coordinator's existing `FOUR-LINE-INTEGRATION-01` integration record; this line does not create a second task/card. Original `908ac83` evidence retains its own source label; the coordinator's later merged-source run is a separate fresh result.
