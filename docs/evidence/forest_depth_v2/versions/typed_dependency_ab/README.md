# Typed dependency preload-order diagnostic

Attempt01 failed to compile its diagnostic fixture because it called a non-static Object method directly on a preloaded class. Attempt02 corrected that call but could not run because sealed snapshot import caches had been reclaimed. Both failures remain as actual logs, not positive or negative leak evidence.

Attempt03 first restored the cache through a real strict4.7.2 editor import, then ran two identical minimal SceneTree consumers whose only difference was LEGACY/TUNING preload order. Each actually generated and compared v1 direct/delegate data, released its owned instances, and returned before deferred quit. Both native processes exited clean under the original strict leak/error reader. Total31.3997s; each native cap30s, import cap90s. Original2010 source hashes and new diagnostic script hashes stayed unchanged.

Both orders passed, so preload order is not established as the full version runner leak cause. The script weak reference remained alive before quit in both clean runs, disproving the inference that this alone means a leak. This is not a new full90-assertion native result. No PlayerTuning production/config/physics file was changed and no error was filtered.

The next unexecuted proposal isolates the original generation branch, no-reload App map2 branch and hash-fallback-reload App map1 branch while preserving the full default runner; it is not included here as an executed experiment.
