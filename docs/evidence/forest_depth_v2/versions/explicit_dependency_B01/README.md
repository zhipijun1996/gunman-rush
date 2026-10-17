# Full90 explicit tuning dependency candidate: strictFAIL

The controlled B snapshot used the exact2010 runtime files from failed A, with only one test file changed in two places: explicit TUNING_SCRIPT preload, and actual tuning construction through TUNING_SCRIPT.load_default(). This was a real dependency consumer, not an unused dummy keepalive. PlayerTuning, its configuration, physics, original90 checks and wrapper strict rules stayed byte-identical.

The original normal wrapper ran once with strict coldimport90/native90 and verbose exit diagnostics. Actual30.8367s, functional90/0, but strict exit still rejected two ObjectDB script/native-class instances and player_tuning.gd resource in use. Snapshot and all original baseline source guards stayed true. The candidate was not applied to main and does not solve the leak. Failed A, the minimal two clean probes and the three failed full-runner branches all remain separate actual evidence.

The compact archive preserves raw native/import/capture/receipts, exact changed test source, diff, producer and full source inventory. Media/full runtime are omitted; it is not a standalone full source replay or final current-source approval.
