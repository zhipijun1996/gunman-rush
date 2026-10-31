# Final Release read-only audit — 2026-10-23

No new Web/Windows export or resource-closure blocker found in the four-line increment. This is a read-only assessment, not a successful Release/deployment claim. No engine/export/CI/deployment was run.

Inspected `/workspace/integration-four` HEAD `d43f61c`; one existing local change was `docs/quality/records/FOUR-LINE-INTEGRATION-01.json`. It is not a clean frozen release source assertion. Compared F `fbb417cb4d4d4d8d2500d7c4bed11cebf681dd46` to this HEAD: no diff in scripts, scenes, assets, resources, project.godot, export_presets.cfg, config, addons, tools/build.py, tools/check_web_bundle.py, or `.github/workflows/environment.yml`. Later documentation/test/browser-helper changes therefore do not introduce an observed production/export resource delta.

## Existing F payload, inspected without rebuilding

Actual existing `build/web/build-info.json` binds source F, build `7f88f353bfb4`, PCK 184,478,012 bytes, download bytes 185,991,653. The four new runtime JSONs are present in the actual parsed PCK, MD5-validated by its directory, and SHA256-identical to current source:

- `assets/enemy_feedback_01/frames_v8/manifest.json` (4,976 bytes).
- `assets/actor_actions/weapon_catalog.json` (2,531 bytes).
- `assets/player_presentation_01/motion_v1/idle_fall.json` (4,735 bytes).
- `resources/art/avatars.json` (841 bytes).

All five MP3 `.import` remaps resolve to nonempty real `.godot/imported/*.mp3str` PCK payloads; each passes the PCK directory MD5 and SHA256 matches the current local imported resource. Sizes: plains 3,791,927; plains Boss 3,842,083; Home 4,243,323; forest 3,808,231; forest Boss 3,868,415 bytes. This checks imported stream closure, not five-song browser playback/listening.

Every platform preset uses `all_resources`; all four JSONs are explicitly included in every preset. Five songs are actual `preload` AudioStreamMP3 dependencies in `scripts/audio/game_music.gd`, with real import records and no matching export exclusion. UI font resources are real imported resources; UI license/source text filters are explicit. The raw PNG export plugin handles its existing finite PNG list, does not strip MP3 resources, and is unchanged from successful F export. Windows uses the same includes/import dependency model. Its actual current build still must pass CI; Web success alone does not prove a Windows executable runs.

## Main automatic Release

`.github/workflows/environment.yml` triggers on push main, and on explicit dispatch. A normal merge/push main triggers Release without prepared-playtest dispatch. `prepare` supplies validated Foundry; Windows runs `tools/build.py windows`; Web runs the complete existing `tools/harness.py --profile web --release`, uploads real `build/web/` artifact and Pages artifact. `deploy_web` requires **core, windows, web** success, uses `pages:write`/`id-token:write`, and then `verify_public` checks the actual deployment against Web job outputs. The final main SHA/CI job results remain necessary; local F evidence must not be relabeled as final source evidence.

Avoid a second manual core/prepared dispatch for the same final main SHA. Keep the automatic Release, full guards and existing artifact retention unchanged. Toolchain download/network, full quality/history inputs, GitHub runner timing, Windows execution, Pages permissions/propagation remain normal execution uncertainties, not newly discovered four-line packaging failures.

## Lightest public verification after final main merge

First inspect the one exact main Release run (read-only):

```sh
gh run view <MAIN_RELEASE_RUN_ID> --repo zhipijun1996/gunman-rush --json headSha,status,conclusion,jobs
```

Require expected final main `headSha`, success for core/windows/web/deploy_web/**verify_public**. The built-in verify_public already runs the minimum existing strong command (metadata + matching HTML + full raw PCK size/hash, no engine/GUI/export):

```sh
python3 tools/verify_published_build.py --url https://zhipijun1996.github.io/gunman-rush/ --build-id <TESTED_MAIN_WEB_BUILD_ID> --commit <FINAL_MAIN_SHA>
```

Get the expected build ID from the actual tested main Web export/CI result; do not substitute the currently public metadata as the independent expected source. F's `7f88f353bfb4` can only be used if final CI independently confirms it. The command retries boundedly and fails nonzero; it does not validate GUI/audio. Re-running this manual command after successful identical verify_public duplicates a roughly 176 MiB transfer and is optional.

For a later actual public GUI smoke, use the new `tools/verify_four_line_browser.py` with the public root URL and exact final source/build, fresh build output, and CJK tessdata. `--section r3` is the already exercised 24-check desktop/mobile scope; `all` also attempts the partially verified Home/Forest journey. Do not turn those existing partial failures into a full GUI or listening approval.
