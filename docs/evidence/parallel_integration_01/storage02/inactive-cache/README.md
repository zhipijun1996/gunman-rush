# Authorized isolated Godot cache cleanup

Removed only `/tmp/gunman-forest-feedback-runtime/.godot`, an inactive generated cache for an older isolated runtime worktree. No other directory or file was deleted, relinked, or changed by the cleanup. The associated source project, assets, historical evidence, `.git`, toolchain, and current shared cache were preserved.

Immediately before deletion, the exact target was verified as an ordinary directory, distinct from the current project's `.godot` target `/tmp/gunman-forest-feedback-godot-cache`. Its top-level content was limited to Godot-generated imports, editor/export intermediates, script class and UID caches, and `.gdignore`. All 934 regular files had a single link. The scan found no active process cwd or command argument using the associated old project and no open handles beneath the target cache.

`cache-manifest-before01.json` records all 939 directory entries, sizes, allocated blocks, types, and link counts. `receipt.json` was fsynced and atomically saved before the sole deletion operation, `shutil.rmtree` on the exact authorized target. That operation does not follow nested symlink targets.

The removed scope occupied **105,590,784 bytes** of allocated storage. Filesystem available space increased by exactly **105,590,784 bytes**, from 780,001,280 to 885,592,064 immediately around the deletion. The target is absent; the current shared cache remains present and its binding unchanged. Receipt and manifest preserve this measured scope without claiming a gameplay acceptance result.

The cache can be regenerated from the unchanged isolated project's `project.godot`, scripts, resources, and assets by a fresh Godot editor import:

```sh
GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains bash /workspace/gunman-rush-design/tools/godot.sh --headless --editor --path /tmp/gunman-forest-feedback-runtime --quit
```

Rebuilding was intentionally not run during this storage task, since doing so would immediately consume the reclaimed space. Rebuilding recreates generated cache data; it is not a byte-identical restoration of editor cache state.
