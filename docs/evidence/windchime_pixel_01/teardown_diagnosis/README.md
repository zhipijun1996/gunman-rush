# Formal pixel teardown diagnosis

The new integration introduced a script dependency cycle; this was not an inherited fixture failure. No test assertions, thresholds, audio teardown or strict exit guard changed.

| Comparison | Functional result | Exit evidence |
| --- | --- | --- |
| Original working-source region run | Expansion 2871 / 0 | Strict failure: 314 ObjectDB / 180 live resources |
| Same expansion script against reconstructed 300d65c runtime sources | 2871 / 0 | Exit 0; no leak/error output |
| Current mini_rays subset | 19 / 0 | 282 ObjectDB / 179 live resources |
| Scratch annotation-only attempt | 19 / 0 | Same leak; rejected |
| Scratch local icon-cache diagnostic | 19 / 0 | Same leak; rejected, never applied to production |
| Scratch leaf helper diagnostic | 19 / 0 | Clean exit |
| Scratch complete installer split | 2871 / 0 | Clean verbose exit |
| Final working source through unchanged run_engine | 2871 / 0 | Strict exit guard passed |

## Cause and repair

`PixelFormalActors.install` statically named the presentation classes which call its drawing methods. Boss encounter parameter types and the ShotLatch walk added reverse script dependencies. Verbose output showed script/resource owners, with no leaked Node instances. Merely annotating the static cache or removing that cache locally did not break the dependency graph.

The drawing helper now has one-way dependencies: installation and latch traversal live in a separate stateless `pixel_formal_style_installer.gd`, loaded only while the existing `install(stage)` API executes. Boss draw parameters use `Node` with explicit scalar types. The original static icon cache, icon rows, drawing operations, real consumers and public install API remain intact; `@static_unload` permits the leaf cache script to unload. No gameplay, physics, RNG, collision or timing was changed.

## Baseline scope

`/workspace/scratch/baseline300d65c` reconstructed all 1068 tracked runtime source files under scripts/scenes/shaders/config/tests/tools/project.godot and verified their Git blob IDs against 300d65c, with zero mismatches. It shared unchanged assets and formal runtime Definitions from this checkout; asset manifest additions and unrelated foundry proof outputs are not a standalone checkout claim. Its expansion script SHA matches the current original script exactly. The abandoned broad git-archive attempt was interrupted before extracting files; it was replaced by this bounded source reconstruction.

Logs are losslessly gzip-compressed; original byte hashes and source hashes are in manifest.json. Scratch diagnostic edits were not copied as a production fix until the complete original 2871 test exited cleanly. This report establishes lifecycle correction, not visual/device acceptance. The application must be rebuilt from the repaired source.
