# Two diagnostic JSON working copies moved to existing lossless archive custody

Only these two newly produced, uncompressed working copies were unlinked:

- `build/integration01/ci05-scene-diagnosis01/positive.json` — 49,098,884 bytes, SHA-256 `ef54a7b78756949d57bc26511c20412e197600c0e2b3f63d33de59f8450029de`, retained as `positive.json` in `build/integration01/ci05-scene-diagnosis01.zip`.
- `build/plains_redesign/scene/run_oc2p8d_z/positive.json` — 49,186,454 bytes, SHA-256 `2d31875cbec4b10eb8e8f27d13185c8f065b57c13763eb24762104b8f9c23e25`, retained as `original_run/positive.json` in `build/integration01/ci05-scene-migration01.zip`.

Total released: 98,285,338 bytes. The complete original JSON bytes remain in the existing ZIPs; no new encoding or JSON serialization was applied. Existing ZIPs, archive receipts, all other raw results, logs and receipts, and all older evidence were left unchanged. The earlier archive receipts' `originals_preserved: true` describes their archive-creation time; this follow-up receipt records the later authorized removal of only two redundant uncompressed working copies.

Before either unlink, the corresponding producer process receipt was checked for terminal `passed`, exit code zero, and a recorded end time. Complete original JSON SHA-256/size, complete ZIP SHA-256/size, and the full decompressed target member SHA-256/size were checked against the original archive receipt. Both target files had one link. No process held either target inode open. An initial conservative global-engine check stopped before mutation while an unrelated wood-platform verification ran; that observation is retained in `preflight-unrelated-engine-stop01.json`. On the final migration preflight there was no active engine, only two defunct Godot zombies without file handles.

`receipt.json` was flushed and fsynced, atomically replaced, and its directory fsynced before each unlink. It records the existing ZIP, exact member, measured hashes and sizes, archive and process receipt hashes, restore target/command, and actual unlink timestamp. No CI result is relabeled by this storage migration.

To restore one exact original path, run the corresponding `restore_command` from `receipt.json`, for example:

```sh
python3 build/integration01/json-lossless-custody01/restore.py build/integration01/ci05-scene-diagnosis01/positive.json
```

The helper refuses an existing destination, streams the exact member into a newly created temporary file, checks its complete SHA-256 and length against the recorded original, fsyncs it, and renames it to the original path. Allow enough free space for the 49 MB reconstruction. ZIP archives are retained.

`cache-candidates-readonly01.json` is a read-only storage candidate inspection. The isolated old runtime worktree's `.godot` cache is about 101 MB, is distinct from the current shared cache, and had no open handles or process cwd at inspection time. It was not removed. Source snapshots, assets, evidence, `.git`, toolchain/export templates, and the current shared Godot cache were excluded. No significant inactive Chromium cache candidate was identified.
