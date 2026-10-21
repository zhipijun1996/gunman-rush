# Forest Bible v2 asset record repair — source frozen

Only 28 new `docs/quality/asset_records/forest-bible-v2-*.json` files were written to production documentation. Assets, runtime, source artwork, checker, tests, thresholds and manifests were unchanged by this repair. No engine/import, asset compilation, Git mutation or image generation ran.

The validator only recognizes quality asset cards. The existing family manifest was informative but was not a substitute for `validate_asset` / `check_quality_diff.provenance_paths`. Every card now carries an exact producer original or synthesis-generator SHA, literal file associations with SHA/role, actual consumer paths where applicable, and an explicit disposition.

Coverage: **175 forest files**, including all source PNGs, rows, palettes, encoders, generation receipts, contracts and offline JSON metadata. **21 genuine runtime assets** (18 PNGs and 3 WAVs) appear in runtime_paths and map to literal production loaders. Source originals under `.gdignore` are retained production or failure records; they are not misrepresented as direct runtime sampling. Thorn atlas JSON is offline metadata: the renderer uses embedded constants. The material/discovery original imagegen sources remain producers of current limited native derivatives, despite withdrawal of full-atlas sampling. Retired white_thorns is retained production material, not a runtime consumer.

All 28 cards retain **license_status=unknown, visual_status=unverified**, with no user acceptance evidence. Existing project-authorship and custom publisher permission statements are attributed to their retained provenance; they do not become a new blanket license. Scoped independent static acceptance of native thorn v2 is described without declaring final user, animation, device or whole-forest acceptance. Earlier native bark v1/v3 and thorn v1 failures remain explicitly rejected evidence.

Commands actually run, with tool-captured exits in check-receipt.json:

- `python3 tools/check_quality.py` — exit 0, static metadata PASS.
- `python3 tools/check_quality_diff.py --base 7be8c340` — exit 1, **zero asset provenance errors**. Sole remaining failure: independent review/test_change_justification for the removed guard in `tests/test_level_region_context.py`; root owns that fix.

`inventory.json` lists every file classification, SHA, role and owning cards. The local ignored register.py reproduces the card assembly from exact current sources; it does not compile or alter any artwork.

Per-file classifications: production_record_only: 76, rejected_evidence_only: 78, runtime_candidate: 21.
