# Current and historical background regression

The original full region run stopped at the old default-renderer assertion (50 assertions / 1 failure) after the default changed to the new pixel renderer. The raw failed run is retained losslessly as `original-region-failure.log.gz`.

No Boss, one-panorama, or two-plane projection assertions were removed. The complete old two-plane checks now explicitly instantiate `LegacyTwoPlaneFixture` on an actual DemoApp/formal Manifest; that fixture is never described as the current default. A separate current-default fixture verifies the real `PixelPlainsParallax`, three distinct PNG paths and native nonempty hashes, nine actual Sprite2D copies, actual `StageCameraRig`/Camera2D, independent X and unclamped Y speeds, all three aspect ratios (1280×720, 720×1280, 2560×720), no horizontal copy gaps, large positive/negative camera travel and unchanged formal gameplay Manifest.

## Actual portrait defect and bounded correction

`portrait-before.gd` ran against the original production renderer with an actual Camera2D. At 720×1280 it observed far sky bounds y=672, height=607.823, leaving the upper screen uncovered. This is an actual geometry probe, not a screenshot or visual acceptance.

The renderer now chooses the larger width-driven/source-height factor, using minimum canvas heights of 1.20, .85 and .62 viewport heights for far/middle/near; widths round up to even pixels to avoid fractional gaps between horizontally snapped copies. The far sky Y position is clamped to its full-screen coverage interval after snapping. Therefore its Y speed follows the configured coefficient only inside that interval, with an intentional stop at coverage boundaries; this does not claim constant speed over arbitrary vertical travel.

The suite compares all nine desktop zero-offset source scales and pixel positions against the original formula and passes unchanged layout. It tests actual Y rates in an unclamped interval and separately tests sky coverage at both bounded extremes. Transparent middle and near images are required to retain their intended horizon bands, not to become opaque full-screen backgrounds.

Command: original `tests/plains_pressure_boss_runner.gd` through unchanged `tools/run_tests.py::run_engine`, fixed 60 FPS, 90-second bound. Result: **488 assertions / 0 failures**, native exit 0 and strict leak/error guard passed. `suite-fixed.log` preserves the actual output. Only this affected suite reran after the bounded correction; it does not claim all 15 region suites reran or GPU/device acceptance. All source and native PNG hashes are in manifest.json.
