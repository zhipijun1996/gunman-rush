# Pressure background consumer fixture repair

The old pressure Boss runner tested the single panorama without explicitly selecting that historical consumer. The default now builds independent sky and ridge. The original full-release failure is preserved in `original_full_region_failure.log`.

Only `tests/plains_pressure_boss_runner.gd` changed. It explicitly selects the historical background for the unchanged panorama assertion. All original 39 `check` call sites, their order, Boss fixtures, attack timing, real shots and physical damage remain byte-for-byte intact after removing the two documented insertions. They account for the original 47 actual assertions. See `runner_before.gd.txt`, `patch.diff`, and `assertion_retention.json`.

The added fixture starts a real DemoApp and assembled PlainsRegionStage, with background defaults untouched. Its real Manifest supplies the camera domain. Installed sky/ridge sprites are checked at 1280×720, 720×1280 and 2560×720, at domain center, independent x/y shifts and all four corners. These are source/material/geometry tests, not raster appearance or device acceptance.

Actual specialist run: **189 assertions, 0 failures**, exit 0, 3.382 seconds, original 90-second limit. The unmodified 15-suite region script was then run once with all original per-suite limits. It passed the first 11 suites, including pressure 189/0 again, and correctly stopped with exit 1 at `plains_campaign_map_runner.gd`: **3705 assertions, 3 failures** concerning RunManifest replay/roundtrip. The last three suites were not executed. This is **not** a full region-suite PASS. Source hashes remained unchanged through both runs.

The new campaign failures are outside this narrow test fixture scope and have been referred to Root. Original ObjectDB/resource exit diagnostics remain in the logs. Production rendering, gameplay, save/RNG code, assertion thresholds and timeouts were not changed. A different agent must independently review this patch; the implementer does not self-sign acceptance.

`background_assumption_audit.txt` and `audit.json` preserve the preceding tests/tools scan. The painterly legacy checks already explicitly disable shared environment; directed-space legacy panorama checks are gated by an optional contract flag, and its default wrapper follows the current two-layer branch. No other unscoped default layer assumptions were found in that scan.

Frozen runner SHA-256: `f27cbe2545cede11767fc1332eb1437e974f47f31928005965a3bb81a1a99061`.

`specialist_pressure01.json` and `region15_01.json` preserve exact commands, real exit codes, durations, and full before/after source hashes. `summary.json` enumerates completed and unexecuted suites, the new failure messages and artifact digests.
