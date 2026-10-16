# Actual Web raw PNG closure repair

The original native Web export omitted all seven original PNG files required by actual FileAccess SHA contracts. Every preset already listed them in include_filter; Godot exported their normal texture import derivatives instead. The original failure log, original 71,190,496-byte pack directory and SHA are preserved without relabeling that failed build.

The added editor-only plugin reads the existing explicit PNG list from each shipping preset. It accepts canonical family source paths only, reads each real family.json, verifies its source path and SHA, and rejects conflicting export exclusions. It adds original bytes with remap=false while leaving the standard imported Texture2D export intact. project.godot only enables this plugin. Each preset only adds exclusion of the editor plugin directory; existing includes and STOP-family exclusions remain intact. No build.py, runtime FileAccess consumer, closure checker, or original test assertion changed.

Actual checks:

- Existing Web closure tests: 43 tests passed, original file byte-for-byte unchanged.
- New preset/source binding tests: 2 passed. Actual runtime_contract(raw=true) is compared against all three preset lists, rather than copying another asset list.
- Real Godot source-plan runner: 16 assertions, 0 failures, including exclusion, traversal, wildcard and absent-family rejections across three shipping presets.
- Actual tools/build.py web: exit 0, 17.776 seconds, using the shared locked Godot binary. Export printed seven preserved source PNGs; before/after source inventories matched exactly.
- Original tools/check_web_bundle.py build/web: failed=0. Actual pack contains 8 JSON contracts, 7 raw PNGs (14,127,738 bytes), 12 texture consumers with their required import mappings/derivatives, and no STOP-family or editor-plugin resources.
- A real derived pack removes the workshop raw path from the native directory while retaining the entire original payload and every other directory entry, including imported textures. The original closure checker exited 1 for that exact missing raw resource. The inaccessible old data bytes remain in the payload; FileAccess can no longer address them. Mutation code, hashes and actual rejection logs are retained.

Actual pack: build/web/index.42cdac2ee80e.pck, 85,319,148 bytes, SHA256 `42cdac2ee80e885da58f97cd251a2cf0d2c6a03a51575f4da6bc32a27e41b3dc`. This was built from Git base 7e253830129770fa8f9b4caaabd0b76c3ef275b5 plus the documented dirty overlay, not a clean commit.

Source inventory fingerprint: `4dd4bbc4427019d29aad6a31f9132fa72e070f8bb756f3fac6ba6b5d8f581611`. summary.json includes its exact inventory/algorithm, commands, real exit codes, original/new artifacts and scope. Windows/Android use the same plugin and were included in source-plan tests; this record does not claim actual Windows/Android exports. Browser execution, deployment, appearance and device acceptance remain separate. Independent review is performed by a different agent.

The different-agent independent review accepted this limited technical repair after rechecking the actual native pack and seven separate missing-raw negatives. See ../web_raw_closure_independent/review.json (SHA256 c894ded837ae31a1fd5646dcafdada13acbe0f2ce4e88f7e2c594c5cf22a1d02). It does not grant deployment, device or visual acceptance.
