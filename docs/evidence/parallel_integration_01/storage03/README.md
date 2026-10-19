# Lossless custody migration of exactly 195 generated documentation caches

This separately authorized migration removed only the exact 195 `editor_doc_cache-4.7.res` files nominated in `cache-candidates03/eligible-generated-doc-cache-paths.txt`. It retained every containing snapshot/source directory and every other original cache, asset, trace, log, receipt, movie, archive, Git file and toolchain file. No hardlinks were created. The current shared Godot cache `/tmp/gunman-forest-feedback-godot-cache` and the current `.godot` binding were excluded and preserved. No engine or production wrapper was started, stopped or interrupted.

The complete historical cache bytes remain in `generated-doc-cache-original-bytes01.zip`, with one blob for each distinct SHA-256. There are 55 blobs for 195 original paths. `path-blob-map.json` records every original path, exact size/hash, mode/mtime, allocated size/link count, original inode, associated source snapshot, and its content-addressed ZIP member. Original caches therefore can be restored byte for byte; this does not rely on a fresh editor generating equivalent data.

- Original logical bytes: **637,566,971**.
- Original allocated file bytes released: **638,177,280**.
- ZIP size: **178,970,266** bytes.
- ZIP SHA-256: `ddfbb88bd133faed64dc560f6407471de30991537e7af055a06267c48a63ae67`.
- Allocated bytes released after subtracting ZIP allocation: **459,202,560**, before small manifest/script/receipt overhead.
- Measured filesystem available-space increase during the unlink window: **638,156,800** bytes. This includes receipt progress writes and any concurrent activity, so it is reported separately from the exact removed file allocation.

Before archiving, each original was checked against its prior candidate SHA/size and required to be an ordinary single-link file outside the current shared cache. The ZIP was created exclusively, fsynced, CRC-tested, and every blob completely decompressed and hashed/count-checked. Before the first unlink, all 195 originals were checked again for full SHA/size and stable inode/mtime/link count. A fresh process scan found no relevant active cwd, command argument or open target handle. The complete map and authorization/verification receipt were fsynced with directory fsync before any unlink. Only the listed files were then unlinked, with progress receipts. The migration ran at nice level 19 to reduce interference with active work.

**149 paths previously recorded in the old local exact-deduplication inventory now transfer to this lossless archive custody.** That old inventory and its audits remain unchanged historical observations. Do not claim those paths remain present in the working tree after this separately authorized migration. The new map preserves their exact historical bytes and recoverable target paths.

`receipt.json` records the exact migration, durability gate, process scans, allocation measurements and removed path list. `verification.json` and `verify.py` provide a subsequent independent read-only pass over ZIP CRCs, every full decompressed blob SHA/size, all 195 map entries, retained parent/source directories, and the current shared cache binding. This is storage verification, not gameplay acceptance. No actual restoration was executed during cleanup.

To restore all exact original cache bytes, with sufficient free space:

```sh
python3 build/integration01/cache-custody03/restore.py --all
```

To restore one path, pass its exact `original_path` from the map instead of `--all`. The helper verifies the ZIP and map hashes, streams the exact blob to an exclusively created temporary ordinary file, verifies its complete SHA/size, fsyncs it, restores recorded mode/mtime, and renames it to the original path. Each restored path is independent (`nlink=1`); the helper creates no hardlinks and retains the ZIP. An existing exact original is verified and skipped; differing existing content causes a failure. The full set requires roughly 638 MB of free allocated space. Do not restore into a snapshot while a process is actively using it.
