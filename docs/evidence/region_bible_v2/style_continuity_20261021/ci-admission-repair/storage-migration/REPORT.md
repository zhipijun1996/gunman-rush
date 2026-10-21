# Final native80 storage migration — verified, awaiting exact GO

All **80 original raw captures remain present**. Reclaim budget is **930,996,224 allocated bytes** (887.87 MiB); logical bytes 930,821,844. All80 have nlink1. This is a budget, not already freed space. No unlink/new ZIP/engine/source/Git action occurred.

Current free snapshot: workspace 283,471,872 bytes; independent /tmp 8,490,889,216 bytes. Full restored80 are retained at `/tmp/gunman-final80-restore-probe-6km4zzpt` on the separate /tmp filesystem. Small ignored planning/proof files consume workspace space; no second copy of the archive was created.

## Exact retained storage sources

- 78 members: `docs/evidence/region_bible_v2/style_continuity_20261021/final-native80/20261021T071751.419853Z/artifacts/forest-depth-region/large-json.zip`, 58,121,248 bytes, full SHA256 `a7fa2d5161878ad5bbfc2821b03ceedc69aa68f0da07665ce3d1355f0c279fb5`. Every member size/SHA is tied to the original artifact index and to producer capture/log receipts.
- Two raw portable captures: the retained31-map2-change_mind and39-map2-change_mind captures under the committed final-native80 artifact tree. Their full paths/SHA/size are in restore-index.json.
- Original native receipt is byte-identical to its portable committed copy: SHA256 `3294957b609177b051684c2b1113f9d070b5d33eb37696e443ecf3006bd77f8f`. All80 native runs have terminal passed/exit0/no errors;80 completed,0 unexecuted. The source maps contain3601 full SHA entries and are exactly equal before/import-after/after. This is historical producer source identity `dec23450fb8e4ce6bca5643f1893c4bf91d14386`, not a claim that a later current tree is the same source.
- Root reports portable bytes committed/pushed as c305b289; no Git command or metadata write was used by this migration task. The committed portable index, archive index and source receipts were read and byte-verified.

## Executed recoverability proof

Whole existing ZIP SHA and all78-member CRC were verified. All80 retained source bytes were compared directly with original raw bytes, then genuinely restored under their full root-relative paths in /tmp. All80 restored full SHA/size, original bytes, permission bits, uid/gid and nanosecond mtime matched. All80 repeated restores were idempotent; real CLI repetition also passed. Real CLI wrong-existing-byte refusal passed for both ZIP and raw source kinds, leaving foreign bytes unchanged. All sources, original80 raw metadata/SHA, source receipts and native logs were reverified afterward. No receipt, log, media or FAILED17 evidence was modified.

`restore-index.json` is the immutable original exact80 plan; its preparation-time pending/unlink flags remain historical. `restoration-verification.json` is the actual completed result. `pre-unlink-readiness.json` records the current budget/FD/free snapshot. Exact producer relative paths and all80 full SHA/mode/nsmtime/source mappings are recorded individually in the index and exact80-paths.txt.

## Explicit restoration

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B build/region_bible_v2/final-native80-storage-migration-first/restore.py --one build/forest_depth/region/harness-matrix/harness-17b1b4b56b8747208164999beefbcd32/00-map1-fast/capture.json
```

Use `--all` for exactly80; `--destination-root /tmp/...` selects an inspection restore root, `--workspace-root` points to the repository containing the recorded committed evidence. Existing same bytes with matching preserved metadata are idempotent; different bytes are refused. No automatic cache-pass claim is created when raw is absent.

## Remaining action requiring root GO

Authorize only the exact80 indexed paths, frozen index SHA256 `62e6bbcbacc625415d36251bc8d678c5472da183487585a1be684dc5e907236b`. Before unlink, recheck whole retained source SHA/CRC, every selected original raw stat/full SHA, preserved receipts/logs and active FD ownership; stop on a changed candidate. Exact-path search across tools/tests/config/docs/quality/records returned0 direct automatic consumer references. The FD snapshot found 0 visible selected inode users; inaccessible live processes are recorded separately and prevent claiming global FD visibility.

After exact GO only, remove these80 raw capture names while retaining all directory siblings, originalreceipt/log/cache/source proof/media/FAILED17/.godot/.git/ci-H and committed78ZIP+2raw. Report actual free-space delta after the authorized deletion; do not label this storage operation a gameplay or region-art pass.
