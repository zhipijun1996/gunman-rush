# Storage05: exact original AVI bytes retained in adjacent XZ

Four old native-speed AVI working files were migrated losslessly, then the task stopped immediately after the requested net 250 MB target was reached. No engine/browser was run. No JSON, source, historical receipt, log, ZIP, MP4, frame/source proof, current recording, shared Godot cache, or tracked file was changed or removed.

The initial read-only search found no AVI over 100 MB in the originally suggested verification/forest-depth roots. After the scope was explicitly expanded to all `build`, suitable older recordings were found in `build/forest_grapple02`. The large JSON fallback inventory remains read-only; no JSON was compressed or deleted.

The following original `.avi` paths **are no longer present as uncompressed working files**. Each complete original byte stream is retained in the adjacent path with `.xz` appended:

| Original path below `build/forest_grapple02/` | Original bytes | Retained XZ bytes |
|---|---:|---:|
| `movie_map2_growth01/00-map2-growth/gameplay.avi` | 148,021,752 | 55,004,988 |
| `movie_final_map1_growth02/00-map1-growth/gameplay.avi` | 108,078,324 | 41,542,336 |
| `movie_final_map2_fast02/00-map2-fast/gameplay.avi` | 100,100,952 | 40,712,572 |
| `movie_map1_fast01/00-map1-fast/gameplay.avi` | 82,273,278 | 32,043,584 |

Total original bytes: **438,474,306**. Total retained XZ bytes: **169,303,480**. Actual allocated file blocks released minus XZ allocated blocks: **269,180,928 bytes**, before the small new script/receipt overhead. The fourth file was used only because the first three saved 218,947,584 allocated bytes, below the target. No fifth file was touched.

Each original was initially checked for an ordinary single-link file, no existing XZ, no related active cwd/command or open target inode, and complete SHA-256/size equality with its existing producer movie receipt. Compression used single-threaded XZ preset 1 at nice level 19, streaming 1 MiB chunks. It did not transcode, trim, resample, or change presentation speed. Each archive was fsynced and completely decompressed into a SHA-256/count verification stream. The complete migration receipt was then fsynced and atomically saved with directory fsync while the original remained present. Only after rechecking no active references, original single link and full SHA/size, and unchanged producer receipt did the script unlink that one authorized redundant uncompressed AVI.

`receipt.json` maps every historical raw path to its actual adjacent `.avi.xz`, with original and compressed hashes/sizes, allocated-byte savings, original inode/link/mode/mtime, original producer receipt hash, recorded source-head/frames/duration, timing and unlink status. The source-head fields preserve exactly the producer receipts' existing recorded metadata (`6c61faadd511c48a267b975550da897e701fd09f`); they do not relabel these old recordings as a current deployment or provide new source/frames proof. All original producer receipts remain byte-identical.

`verification.json` is a post-migration full-stream pass: it rechecks every actual XZ hash/size and complete decompression hash/size, unchanged producer receipts, missing uncompressed originals and retained parent directories. The complete original bytes are recoverable; no restoration was performed during this cleanup.

To reconstruct a specific exact old raw path, with enough free space and no process using that recording:

```sh
python3 build/integration01/storage05/restore_avi.py build/forest_grapple02/movie_map2_growth01/00-map2-growth/gameplay.avi
```

Use the exact `original_path` from `receipt.json` for other recordings. The helper refuses an existing destination, checks the compressed archive's complete hash/size, streams into a newly created temporary ordinary file, checks the complete original hash/size, fsyncs it, restores original mode/mtime, and renames it to the original path. It creates no hardlinks and retains the XZ. Tools requiring the old `.avi` path must perform this exact restoration first; the path is not falsely presented as still present.
