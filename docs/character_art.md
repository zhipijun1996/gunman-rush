# Demo courier character art

Original plains courier: ivory linen hood, bronze monocular with cyan lens, red scarf, articulated brass legs and recoil pistol. The generated transparent painterly master is `assets/characters/courier/source/master.png`; it is unchanged. Provenance records generation input and production limitations. Runtime parts are AI-authored SVGs, simplified from the master for stable animation and small-screen readability.

## Integration contract

Instantiate `assets/characters/courier/courier_visual.tscn` beneath the player as a cosmetic child. Its local origin is the center of the feet. Source body canvas is 96×96, nominal standing height is 104 px including legs, and aim pivot is local `(4,-51)` relative to feet. For the current 24×36 player collision, attach at local `(0,18)` and use uniform scale `36.0 / 104.0`. Visual dimensions never redefine collisions.

Public methods: `set_state(StringName)`, `set_facing(float)` and `set_aim_direction(Vector2)`. States are `idle`, `run`, `jump`, `fall`, `recoil`, `death`. Run alternates mechanical legs; jump tucks legs; fall stretches hood; recoil produces a decaying impulse; death tilts and fades. No timer changes gameplay or auto-transitions state. Consumer owns state priority: death overrides recoil, recoil briefly overrides locomotion, then derive jump/fall/run/idle from motor state.

Weapon uses its own shoulder pivot and accepts every aim angle; upward and downward aiming do not rotate the body. Facing mirrors body and scarf; weapon flips its vertical orientation while aiming left. Subscribe to `ShootAbility.shot_fired(direction, shot_id)` for recoil and aim, and controller `died` for death. Reuse scene in preview without a motor.

## Production and validation

Run `python3 tools/build_character_art.py` to regenerate four transparent SVG layers and manifest metadata, not the AI master. This script does not edit raster images. Source paths are relative to repository root.

Godot required project target is 4.7.2. The available binary is 4.6.3, so any harness check records lower-version compatibility only, not target-version verification. These six states use procedural parts rather than sprite sheets. Full painterly animation fidelity and actual phone readability remain visual acceptance work.

Validation evidence: `python3 tools/check_docs.py` passed (22 required documents), exit 0. `godot --headless --path /tmp/courier_art_check --editor --quit` imported the SVGs and scene with 4.6.3, exit 0; the initial default user-data directory was unwritable. Re-running state verification with temporary XDG directories, `godot --headless --path /tmp/courier_art_check --script check.gd`, passed all six states and four cardinal aim directions, exit 0, with no script errors. The harness source is retained at `tools/build_character_check.gd`; copy it to the temporary project as `check.gd`. First harness attempt invoked processing before node readiness and emitted errors; corrected harness defers its check until the scene is ready. No target 4.7.2 or physical-device validation performed.

## Painted static cleanup candidate

`source/clean_courier.png` is an untouched image_gen edit of the master, intended as an optional painted static candidate. Three attempts (two edits and one fresh generation) retained ambient halos despite explicit transparent cutout instructions. The candidate is therefore **rejected for runtime** and remains reference only. It has no independent gun pivot or animation. Prompts and rejection are recorded in `source/cleanup_attempts.json`; the four vector layers remain the usable animated production fallback.

## Shared player integration — 2026-10-10

`scenes/player/player.tscn` now instantiates the accepted vector courier for fixed demo, module lab and generated preview consumers. `scripts/art/player_visual_adapter.gd` observes the existing Motor, aim output, accepted `shot_fired` and `died` events. It never consumes input, grants resources, changes collision or moves the player. Temporary controller deactivation for menus or completed stages does not imply death. Recoil briefly preserves the actual shot direction even while movement momentum points the opposite way; death takes priority. Pausing freezes inherited cosmetic processing.

The attachment uses feet `(0,18)` and uniform `36/104` scale; collision remains exactly 24×36. Weapons and scarf are decorative and can extend beyond that collision. Actual opaque SVG pixels measured at runtime span 35.65 px vertically in the horizontal-aim standing pose, up to 49.85 px horizontally including scarf and gun; upward aim reaches local y −24.40 and downward aim y 25.10. These cosmetic extensions never become hitboxes or projectile origins. Close-platform readability and clipping still require visual/device acceptance.

Target-version integration verification: `bash tools/godot.sh --headless --path . --script tests/player_visual_runner.gd`, Godot **4.7.2.stable.official.ed1daf0bf Standard**, **20 assertions, 0 failures**, exit **0**. Coverage uses the actual shared player scene, imported transparent SVGs, real accepted/rejected shots, mirrored and vertical aim, death/new life, paused processing, unchanged collision/resources/input, and transformed opaque-pixel bounds. The earlier 4.6.3 results above remain historical art-branch evidence. No new artwork was generated and the painterly cleanup candidate remains excluded from runtime.


## 世界锚点衔接

[世界背景](world_and_story.md)中的旅人/守钟人身份与枪的工作名尚未定稿。现有courier为可玩外形候选，不能从面罩、围巾或黄铜造型反推出已确认角色身世；后续比例、线条与动作保持当前接入契约，不因剧情重做碰撞。
