# Serial cost appendix: frozen12f6 profile

Read-only. No implementation, tests, source changes or Actions requests. CurrentCI39945409720attempt2 is unaffected. Machine/source observations below are kept separate; no sum is presented as an exact CI forecast.

## Current inventory and observed coverage

At `12f6cb006d7119598e3235f4ca4f7323e4c9d092`, full selects142checks:89parallel and53serial. Effective serial weights total**1187.125** versus3343.874for all142;10serial entries omit weight_seconds and therefore have effectiveweight1. Exact53IDs/weights/timeouts are in serial-cost-data.json.

Important scheduling distinction: `harness.py:641–648` uses weight_seconds only to balance **parallel** lanes; `:727–728` executes the serial list sequentially after every parallel check passed. Serialweight1 is misleading cost metadata, but changing it alone will not shorten this serial tail or move any check to another worker. The19.8minutes represented by its weight sum is not a reliable duration forecast.

|Downloaded source report|Actual statuses|Harness wall time|Current53serial actually started|
|---|---|---:|---:|
|a074a709|70pass,1fail|1082.250s|0|
|cab95891|75pass,2fail|1347.815s|0|

Both failed in the parallel phase; all53serial are unexecuted in these reports. They establish neither serialPASS nor serial duration. Later source checks and local scratch proof must not be added to these walltimes to manufacture one predicted final-CI total.

## Four highlighted weights versus actual evidence

|Check|Effective weight|Current or relevant observed evidence|Boundaries|
|---|---:|---|---|
|plains-experience-golden|1|Latest current candidate receipt has native positive5.501s and real negative1.439s:6.940s process sum|No whole-wrapper wall clock in that receipt. The evidence does **not** support saying this current wrapper took hundreds of seconds. FreshCI is still needed.|
|plains-encounter-policy|1|One retained full3 attempt contains277.159s for14reward subprocesses,49.154s for4native/recovery subprocesses,15.660s cancellation,95.780s for4formal captures and18.245s repeat: **455.998s constituent process sum**|Same-attempt serial constituent sum/lower bound, excluding Python overhead and final remaining bait. Full3 retainedFAILED for a free-policy no-op counterexample; final reader/tail passed separately. Not a successful fresh full wrapper or CI estimate.|
|plains-redesign-scene|1|Current candidate handoff reports **226.592s whole wrapper**, including133.386s positive aggregate|Different scratch source/host from finalCI; original900s wrapper/180s positive budgets retained.|
|forest-depth-region|120|Exact5502 local Harness **369.678s PASS for80cases**|Different earlier source/host. The old5502CI separately timed out at600s with37cases passed under competing CPU work. Never average these into a finalCI prediction; currentserial isolation addresses that observed contention.|

References: experience `/workspace/scratch/plains-experience-current-20261023/overlay/build/plains_redesign/experience/run_e5ndonlg/receipt.json`; encounter `/workspace/scratch/root-bell-current-scope/overlay/build/verification/plains-encounter/run_dm58z4e1/receipt.json` and its four capture.invocation.json files; scene `/workspace/scratch/plains-scene-current-20261023/handoff-final.json`; forest `/workspace/integration-four/build/verification/harness/20261023T081923.124257Z/report.json`. These are observations, not a refreshed approval of current12f6.

## Three follow-ups ordered by likely return versus change cost

1. **Avoid existence-only evidence hydration.** Small finite check_docs/preflight adaptation described in report.md can avoid up to890published paths in recordeda074;869exclusive initially-missingOIDs contain1,864,128,011uncompressedbytes. Keep every Markdown source and every actual hash consumer, including108Markdown/SHA overlaps. Strongest measured opportunity, without reducing game tests. Acceptance: exact ordinary/sparse verdicts, ordinarydeletion/indexmismatch/symlink/wrongmode refusals, overlappingqualityhash still enforced; compare actual fetchcount/bytes/preparationtime. This is not permission to delete historical evidence or claim guaranteed wire/time savings.

2. **Batch Git metadata/blob reads.** Existing160-file local/no-network test measured15Git children per file/2400children/2.280s,79.5%in repository_state. Batch round metadata and use streamingcat-file while preserving HEAD/index/skipflags/SHA/size/nooverwrite and concurrent-change refusals. Moderate implementation cost, reliable local-overhead target; prior43.65s extrapolation to3063files is only same-host tinyblob arithmetic, not actualCI savings. Measure phase/process counts first; do not cache PASS or relax preflight.

3. **Isolate a proven independent serial family using existing workspaces, incrementally.** Serial53is currently a global ordered tail, and multiple entries have unmeasured/default costs. Keep web-build→web-bundle, promotion/export consumers and all actual shared writers ordered. Move at most one audited output-only family to existing isolated workspaces after proving source/UID/import/user/output separation and actual fullconsumer results; compare same-source critical-path wall time and CPU/memory. No particular serial family is preapproved by this cost audit. Keep CPU-heavyforest80 alone: its600s contention failure versus local369.678s makes blind extra concurrency unsafe. Do not raise budgets, reduce80cases or replace fresh checks with past PASS. This has potentially larger execution benefit but more validation cost than the two input optimizations.

Refreshing weights from same-source freshCI measurements would improve visibility and future parallel balancing. It is separate from an actual concurrency change and should not be advertised as a runtime optimization for currentserial checks.
