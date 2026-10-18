# Recommended north return: original failure and strict pass

This package closes only `forest-depth-hollow-00 / map 2 / growth`, layout `shared-tree-canopy-hunt-v10`. N02 passed the actual native route and unchanged strict reader. It does not certify the fixed 80 routes, a Boss fight, player enjoyment, device input, or audio quality.

- **01 remains FAIL**: native exit 0, but strict reader rejected `shot_not_actual_router_request`. Its raw capture, logs and receipts are retained without retagging.
- **02 is strict PASS**: fresh 2068-file current-main snapshot; cold import 28.493 s, native 5.229 s, outer 35.085 s. Import/native exit 0, reader errors empty, before/copy/after and post-run source guards true. Budgets stayed import 90 / native 240 / outer 360 seconds. Independent userdata and global engine lock were used.
- Fourteen actual completed legs include reward return W at 534, N at 629, S at 704, C at 876 and final gate at 1013. Final HP 5, energy 100. **Accepted shots total 3**, at 232, 763 and 843; the final snapshot `shots: 2` (also described as 2 in the original independent report) means remaining airborne shot allowance, not total shots fired.

## Telemetry correction and strict association

At tick 232 the caller input A was `[0.70710676908493, 0.70710676908493]`. The real Router normalized its queued packet to B `[0.707106828689575, 0.707106828689575]`; the accepted shot and actual projectile also record B. Only `TRACE.request` was edited by this task: `input_aim` retains A; successful requests immediately observe the actual queue tail direction/type/sequence/epoch. The queue is not mutated by observation. Request count/arguments and Player/Router/Shoot physics were unchanged. No tolerance or reader assertion changed.

The whole archived reader file and its `validate` function are byte-identical between 01 and 02. The actual queue packet has sequence 7 / epoch 3; shot/projectile serial is 1, projectile session 2 / weapon epoch 0. These are separate scopes: no consumed-action sequence signal is invented. The same-frame queued direction, accepted shot and independently spawned projectile establish the recorded association. Original 01 did not record queue sequence/epoch; they are not backfilled.

## Provenance and verification

`01` reused sealed `canopy_app02` (2068 files, warm cache). `02` copied fresh current main into `recommended_growth_v10_02` (2068 files, cold cache); it is not an edit of sealed 01. `source-delta.json` records all differences across these snapshots, including other authors' intervening changes. Only five selected source files per run are bundled; full authored-source inventories are included, not a claim to bundle every source byte. Matching binary assets in 02 were linked only from a sealed snapshot; code was copied independently. Exact copy receipts identify the domains and hashes.

Command in each snapshot: `python3 tools/run_forest_depth_region.py --seed forest-depth-hollow-00 --map 2 --route growth --output build/forest_depth/region/recommended-growth-v10-0N` (`N` = 1 or 2). Outer producers lived under the corresponding `build/forest_depth/region/recommended-growth-v10-0N-preparation/`; raw sources under each snapshot's output directory. Native logs, import logs and inner/outer receipts are retained here. Gzip captures decompress to the original SHA in `results.json`.

Independent static and actual reports/audits are byte-exact copies. Reports use `.md.txt` to preserve their original relative references as archival text. Their limited technical CONTINUE does not reverse the original failure or approve whole-region quality.

Run `python3 docs/evidence/forest_depth_v2/recommended_north_return02/verify.py` from the repository. Verification is offline: it checks every packaged byte, lossless captures, the unchanged strict reader and real queue/shot/projectile chain, then replays the archived reader on both captures. No Godot is launched. `index.json` excludes only itself.
