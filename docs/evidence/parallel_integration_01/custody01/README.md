# Local evidence custody failure and repair

During this integration task, a disk-saving deduplication linked 1,499 identical file pairs at approximately 09:06 UTC. This incorrectly included the reusable `build/verification/aim_save_compat.json` output and two historical copies. A subsequent compatibility test wrote new output through the shared inode, replacing the historical bytes. This was an actual local evidence custody failure, not a historical test failure or a reason to relabel a previous run.

The corrupted historical files expected SHA-256 `56f5a19ed9df643de31f026d22ae4b0f091a7049111025a999e2fabb757e66d2` (1,867,414 bytes). Their observed overwritten content had SHA-256 `b4723f7bd840b3c9c9133672bbc6f15ef9ce8469e9af856eaea0ae446a9edc4e` (1,868,870 bytes). The initial audit's `bytes` field retained the inventory's historical expected size; it was not the overwritten file's measured size.

The newly generated raw output was first copied to an independent inode at `build/integration01/new_aim_save_compat_after_integration01.json` and archived here. The current reusable output was detached to its own inode with those same new bytes. The two historical paths were then restored atomically to separate, ordinary independent files:

- `build/forest_grapple02/aim_save_compat04.json`
- `build/verification/harness/20261019T015430.683827Z/artifacts/aim-save-compat/build/verification/aim_save_compat.json`

Recovery used the exact original member in `docs/evidence/forest_grapple02/save01/selected-originals.zip`. Its member hash matched the deduplication inventory's expected hash before restoration. The second copy was independently compared with its own member in `docs/evidence/forest_grapple02/checkpoint02/selected-originals.zip`. Both archive files were checked byte for byte against their committed HEAD Git objects and remained unchanged. No original archive was rewritten.

Further containment detached 212 potentially mutable paths, retaining byte equality: reusable Web build files and legacy shortcut captures, runtime shader/editor caches outside archived artifact copies, and generated source-before/source-after metadata. This used 611,708,832 bytes, rather than undoing the entire approximately 4.8 GB deduplication. Numbered historical results, frozen assets, and archives remain deduplicated where no live producer was identified. Any future producer reusing a historical output directory must detach shared files before writing; this repair does not make arbitrary hardlinked directories safe to overwrite.

The final audit covers all 1,870 unique paths named by the original inventory. Both restored historical paths and every other historical path match their original expected SHA-256. The sole expected difference is the current reusable compatibility output, whose new content was deliberately preserved. This custody audit does not replace gameplay validation or establish any new gameplay acceptance result.

`repair-receipt.json` contains the final measured results. `custody-originals01.zip` preserves the original deduplication inventory, observed failure, restoration receipts, inode detach receipts, final audit, and the newly generated raw output. `inventory.json` records each archived member's exact size and hash.
