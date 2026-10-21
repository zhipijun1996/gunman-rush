# Exact historical JSON lossless storage relocation

This is storage maintenance only: no engine, gameplay, test suite, source, documentation, Git, AVI, actual CI ZIP, CI-H workspace or running804MB directory changes.

The approved original selection was exactly 71 terminal complete JSONs plus 14 complete JSONs already present in portable ZIPs. All 85 originals passed fresh stat/fullSHA, enclosing terminal receipt and no-open-FD checks. The new ZIP and existing ZIPs passed CRC, complete decompressed SHA and original-byte comparisons. A real original raw path was restored, a repeated restore was idempotent, and a different-byte existing destination was refused without mutation before raw relocation.

A later additional consumer review found no current tools/tests/quality-record full-path input requirement, but historical archived audit.py files still directly/dynamically consume six selected raws. Those six were restored exactly, including original mtime/mode/owner, and remain present. **Final state: 79 selected raw JSONs relocated; six retained.** execution.json is the earlier initial85 operation receipt; final-closeout.json and consumer-review.json record the later conservative retention and final capacity. Original logs and receipts are unchanged.

- index.json maps every one of the 85 original paths, original full SHA/bytes/permissions/owner/timestamps to the complete archive member. It includes each external portable ZIP's exact repository path, complete archive bytes and SHA, with no symlink or short-lived URL.
- exact71-terminal-json.zip retains all 71 complete original JSON members, including failed and negative samples.
- verification.json records all85 complete member SHA/CRC/bytewise equality with still-present originals, before relocation.
- restore-probes.json records real canonical-path restore, repeated idempotence and the refused overwrite negative control.
- consumer-review.json records full-path searches and the six restored historical audit inputs; current-path-reference-matches.txt retains exact search output.
- final-closeout.json records final measured free space, retained raws, archive hashes and actual/accounted storage recovery. Original source/capture identity remains the indexed original receipts, not current source.

From the repository root, restore any indexed original:

```sh
python3 build/region_bible_v2/storage-terminal-json-lossless-next/restore_json.py --path build/forest_revision04/corpus80-W4/00-map1-fast/capture.json
```

Restore every indexed original (including the six retained, checked idempotently):

```sh
python3 build/region_bible_v2/storage-terminal-json-lossless-next/restore_json.py --all
```

The script verifies complete archive SHA, complete member SHA/CRC/bytes and refuses to overwrite nonidentical existing bytes. Restored original paths are needed before manually replaying historical raw-path consumers. Preserve this directory's ZIP/index/restore script and the indexed docs portable ZIPs together; moving only a receipt or index cannot preserve the original bytes. No new native/gameplay or user/release acceptance is claimed.
