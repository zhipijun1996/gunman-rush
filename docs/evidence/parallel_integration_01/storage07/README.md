# Exact committed duplicate cleanup: 164 build files

After explicit review/authorization of `approved-plan.json`, exactly 164 listed duplicate files were removed from `build/integration01`. Every original byte remains in an existing immutable committed documentation file or an exact member of a committed ZIP. No new large archive/compression, engine/browser run, hardlink, source edit, tracked-file edit or containing-directory removal occurred. CI7 extraction/new archive/current probes and all unique Web/custody archives were excluded.

This operation measured actual filesystem available space using `statvfs`, rather than claiming physical gain from inode allocation sums:

- Immediately before cleanup: **116,056,064 bytes available**.
- After cleanup: **356,712,448 bytes available**.
- Observed overall available-space increase: **240,656,384 bytes**.
- Sum of each item's immediately bracketing unlink-window available-space changes: **240,861,184 bytes**.

Small durable receipt/progress writes explain part of the difference; concurrent work can affect these windows. These are recorded actual filesystem observations. Logical candidate allocated bytes are separately recorded as 240,861,184 and were not substituted for the physical measurements. This operation therefore differs from the preceding `custody06` migration, whose physical free-space change was not measured and remains unknown.

The exact authorized plan is preserved unchanged as `approved-plan.json`, SHA-256 `7a9e2c86f0c78e2a5ae82919087a16f8c19e25e7414637857b83e3aabf41828d`. Its 164 paths map to 114 distinct retained committed alternatives. Every candidate's original SHA/size/inode/mtime/nlink1 and absence of open target handles were checked before cleanup. Immediately before each unlink, the original identity/content and no-FD gate were checked again; the retained alternative was independently checked for its fixed commit/tree blob identity, actual complete Git-blob SHA-1 and file SHA-256/size, and nlink1. For ZIP alternatives, that exact member was completely decompressed, CRC-checked by the ZIP reader, and hash/size-compared again. The approved manifest, restoration helper, and each item's verification receipt were fsynced with directory fsync before deletion.

All replacement files remain ordinary single-link files, preserving isolation from mutable build outputs. No existing documentation or old record was rewritten. Some old build paths recorded in historical logs/receipts are now absent; those historical records remain unchanged point-in-time observations. A consumer needing an old path must restore its exact bytes first.

`cleanup-receipt.json` records the complete executed per-item provenance and the real available-space measurements. `verification.json` checks that all 164 approved paths are absent, their parent directories remain, all 114 retained alternatives still match their committed Git blobs and SHA-256/size with nlink1, and their Git objects exist. It references the executed per-item complete ZIP-member checks without claiming another redundant decompression or gameplay acceptance run. `cleanup.py` is the executed one-shot script; do not rerun it over already removed paths or overwrite its historical receipt.

To restore any exact original build path:

```sh
python3 build/integration01/upper-duplicates-readonly07/restore.py build/integration01/movie-candidate6-map2-fast-portable/gameplay.original.avi.xz
```

Use the exact `build_path` from `approved-plan.json`. The helper requires an absent destination and retained parent directory. It verifies the fixed commit's blob identity and the current alternative's full hash/size; if a later documentation edit changes that working copy, it can read the exact immutable Git blob instead. It streams the direct file or exact ZIP member into an exclusively created temporary ordinary file, verifies the complete original SHA/size, fsyncs, renames to the original path, and fsyncs the directory. It creates no hardlinks and retains all committed alternatives. Restore only when needed and with sufficient free space. No restoration was executed during this cleanup.
