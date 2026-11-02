# Exact e42 → current candidate paired native measurements

Baseline: `e42b277f37425458a2920815258d1cfc817acfc3`, not the former8df baseline. `prepare.py` uses `git show` for the exact Pose/Ground/Flora/Skin source bytes, renames only their four lexical class tokens and nests their unchanged bodies. Every generated body has an exact inverse assertion. `original/` preserves Git bytes; `source-vector.json` pins the original and candidate SHA plus shared Weights/Motion/six PNG identities. Those shared inputs were independently checked equal to e42.

Executed once using the existing `harness.run_check` with the original `tools/godot.sh` identity wrapper,180s cap. Actual4.756s, status passed/exit0, no SCRIPT/Parse/SHADER/ERROR or ObjectDB/resource-exit error, source pre/post stable. Engine banner: Godot4.7.2 stable custom gunman_sd1.ed1daf0bf. Complete native.log and receipt.json retained. Author released the engine lease immediately after completion.

## Results measured, not forecast

Constructor and kernel variants alternate execution order. Three rounds,80 constructor samples per kind per variant per round;63 kernel inputs per case/variant/round, first3 excluded from timing. Kernel samples still all checked byte-for-byte, including warmup:567 paired samples ×625 =354375 vertex outputs,0 differences. Constructor checks count625 and kernel neutral points/UV bytes agree. This does not replace the larger existing frozen2ce regression.

| Timed CPU scope | e42 mean ms | Candidate mean ms | Reduction | Samples per variant |
|---|---:|---:|---:|---:|
| Root Bell repeated `Skin.new` |0.196521|0.007108|96.38%|240|
| Patrol repeated `Skin.new` |0.198513|0.008583|95.68%|240|
| Root Bell moving, prepare+625 |3.471478|1.905689|45.10%|180|
| Root Bell hurt/attack, prepare+625 |3.336606|1.905889|42.88%|180|
| Root Bell dying, prepare+625 |4.085017|3.216011|21.27%|180|

The **first Root Bell constructor was slower**,0.307→0.491ms, one sample per variant. This includes filling new shared topology/point templates and is retained rather than discarded as inconvenient. The later first Patrol constructor was0.258→0.036ms with the candidate topology already warm, but its per-kind neutral points new. Neither single observation is a stable distribution.

Actual Node2D._draw stopwatch observations (each cell lists first new-instance draw / following draw, ms):

| Pose | e42 | Candidate |
|---|---:|---:|
| Moving |6.600 /4.119|3.902 /1.970|
| Hurt/attack |5.177 /3.227|2.228 /1.708|
| Dying |5.296 /3.499|3.041 /3.334|

These are only two observations per case, not statistically established frame percentiles. First moving candidate draw constructs the Root Bell weight template; later new-instance draws reuse it. Topology was already warmed by construction measurements. Draw clocks include CPU setup, deformation and rendering-server submission, not completed GPU work. Do not add these separated samples to manufacture an end-to-end startup measurement.

## Interpretation and responsibility

The constructor comparison exercises the root-authored mesh template implementation: UV/index and per-bounds neutral point generation are reused, while each body still creates its own ArrayMesh and mutable point/UV copies. Timing ends before rig disposal; it excludes destruction cost, script/texture preload, actualGPU completion and full scene initialization. It demonstrates a substantial repeated-constructor CPU reduction on this host, with a visible initial template cost. It does not demonstrate that total startup improved96%, or that all instances became free.

The prepare+625 kernel uses the same explicitly prebuilt UV weights for both variants, so its improvement isolates the current mathematical/prepared-geometry route rather than claiming the template constructor gain again. Its dying samples sweep progress0→1 (and lethal live blend); settled production draw caching may avoid this forced kernel, so no settled-corpse FPS claim follows.

Root Bell geometry code and this benchmark were authored by preview_audit; those are author measurements, pending runtime_audit's separate review. Mesh template production code was authored by root; preview_audit's limited non-author review here is only the accuracy of the performance/cold-cost interpretation, not a substitute for its correctness/lifetime/aliasing independent review.

No browser, phone/device, actual-map AI workload, shader compilation timing, P14 workload or GPU FPS was measured. No production source was changed during this run. Candidate identity is the precise WIP leaf vector in the receipt, not falsely attributed to committed e42.

Reproduction after explicitly checking the same source vector:

```sh
python3 /workspace/refactor-evidence/combat-perf-deploy-01/root-rig/paired-e42/run.py
```

A future run must use a new evidence directory/log rather than overwrite this one. The runner rejects a changed candidate leaf before invoking the engine.
