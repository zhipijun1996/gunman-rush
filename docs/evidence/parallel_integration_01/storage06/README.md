# Custody06: three old raw AVI byte streams preserved losslessly

The three explicitly authorized old runtime AVI files now have their complete original bytes in adjacent `.avi.xz` files. The original uncompressed `.avi` paths are absent and require the exact restoration helper before old tools can access them. All original raw JSON, producer receipts, failure logs and other evidence remain unchanged. No shared/current Godot cache, Git data, source or CI7 extraction was modified.

**Actual physical disk-space reclamation is unknown and must not be claimed as 233 MB.** The value 233,562,112 bytes is only the sum of original inode `st_blocks` allocation minus XZ inode allocation. This operation did not record a before/after `statvfs` baseline. On overlay storage, removing a lower-layer file can create a whiteout without reclaiming its underlying blocks, while newly created XZ archives consume upper-layer space. Concurrent work also changes free space. The observed post-operation free space did not improve. The initial receipt's misleading field name is preserved in `receipt-initial-logical-accounting01.json`; the corrected current `receipt.json` explicitly records physical reclamation as unknown, retains the original receipt SHA, and distinguishes logical allocation accounting from actual filesystem measurements. No reverse restoration/deletion was attempted to fabricate a measurement.

| Original runtime path below `/tmp/gunman-forest-feedback-runtime/build/forest_feedback/` | Existing producer status | Original bytes | Retained XZ bytes |
|---|---|---:|---:|
| `movies01-map1/00-map1-fast/gameplay.avi` | PASS | 81,940,618 | 27,954,492 |
| `movies03-map2-fast/00-map2-fast/gameplay.avi` | PASS | 97,394,688 | 30,798,740 |
| `movies02-map2/00-map2-growth/gameplay.avi` | failed / timeout | 162,025,472 | 49,042,368 |

Each retained path is the exact original path with `.xz` appended. Total original bytes are 341,360,778; total XZ bytes are 107,795,600. These counts describe preserved file contents, not physical free-space gain.

The two PASS recordings were checked against their existing producer movie SHA-256 and size. The failed/timeout recording had no producer movie SHA or size. Its full existing raw stream was first hashed/count-bound for this custody migration; this is not proof of a complete valid movie or an independently recorded producer-time hash. The original timeout failure remains failed. Its newly measured raw SHA is `eb09384cf9164c333d6925143be17841dc74982407f9b82d7e3915a2ab23c549`.

After the hook browser released and the aim agent's native probe exited, process checks found no active engine/browser/media, related runtime cwd/command, or open target file handle. Each source was an ordinary single-link file. Compression used single-threaded XZ preset 1 at nice level 19. Each XZ was fsynced, then its complete decompressed stream was hashed/counted against the complete raw baseline. A durable receipt was saved before unlinking each authorized uncompressed redundant working file. Original raw and producer receipt hashes were checked again immediately before unlinking. `verification.json` subsequently rechecked actual XZ hashes/sizes, unchanged original producer receipts, absent old raw paths, and retained parent directories. Its full decompression evidence references the actual per-file migration checks rather than claiming an additional movie run.

To restore one exact original raw path with adequate free disk, no process using that recording, and no file already at the destination:

```sh
python3 build/integration01/custody06/restore.py /tmp/gunman-forest-feedback-runtime/build/forest_feedback/movies02-map2/00-map2-growth/gameplay.avi
```

Use the exact `original_path` in `receipt.json` for the other two files. The helper checks the complete XZ SHA/size, streams to a newly created temporary ordinary file, verifies the complete original SHA/size, fsyncs the file, restores mode/mtime, atomically renames, and fsyncs the directory. It creates no hardlinks and retains the XZ. Restoring the failed stream preserves its failed/timeout identity. Do not run restoration merely to repeat disk accounting: it would consume additional upper-layer disk space.
