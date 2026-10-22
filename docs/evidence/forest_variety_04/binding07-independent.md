# Corrective follow-up: creative-v8 / style-v4 binding

My earlier loader conclusion was wrong. Registry authority selection does not overwrite a stored creative-direction binding: load_direction calls validate_bible_binding, which compares the complete current binding and rejects stale style/registry hashes. I inferred runtime acceptance from registry lookup without actually calling the full loader. The original report remains unchanged at `/tmp/forest-v18-style-v4-rebind-review.md` (SHA ca1d9bb83745eb114b599e5106cc7fda31c6b816269efec333ad17ef2c903fb7); its corresponding script/JSON also remain as the original evidence, not corrected in place.

The real harness20261022T054736.439436Z remains FAILED: its32 Bible tests ended failures=2/errors=3. Although five checks were requested, the retained receipt shows only three reached before failure. This was a real blocked consumer, not an unrun concern.

Completed bounded read-only follow-up:

- Actually called production load_direction for current windchime_plains and thorn_forest: both accepted creative-v8 with their recorded full hashes d7ffc860dfd9ba08e2e162fe136456dc50488bc4e5d1dce8144f4d3b5e7ac1a8 and0745f57ac51ec03f253eb909154fae27f53731d2fb240cb8ac758b4ca1f09fd3.
- Old Plains creative-v6 archive bytes equal the prior HEAD current file, SHA5e2076c848899b350a25b8b666f970c6f4ffe418f7fa69466333d7bde6f7f28e. Old Forest creative-v7 likewise equals prior HEAD current bytes, SHAba717b942c1847fb8e71df3eba38e088f36da08229fed52633a1220ebfa467ed. Both complete before/after identities match style-continuity-rebind-v4.json.
- Exactly four top-level fields differ in each current direction: version, region_bible, authority_sources, historical_direction. All other content is structurally identical, including creative intent, user evidence, acceptance, gameplay/emotional/material requirements. This is explicit versioning and source rebinding, not new creative approval.
- Actually called validate_bible_binding on each old full binding and load_direction on each archived previous direction: all reject with binding-changed. Also called current bindings with isolated old style-v2 or style-v3 refs while retaining the otherwise current binding: both versions reject for each region.
- Production loader source is byte-identical to HEAD; no bypass or automatic refresh was added.
- Test diff changes only one Bible-test method and one creative-test expected version. Bible expects finite style4; creative expects creative-v8. Prior v2 rejection, missing-body-role checks and actual body/source/quote/registry drift guards remain. New stale-v3 rejection was added. The explicit v2→current reference comparison now also excludes the already separately proven boundary_sides change; it retains all other reference comparisons. All other test methods have identical ASTs to HEAD.

Read the separate fresh harness20261022T055129.880429Z receipt: all six checks passed (docs, Bible contract,32 Bible tests, creative tests, original terrain plus mini-equivalence, original formal terrain). Its Bible log says32 tests/OK. These are actual fresh receipts, not a reinterpretation of the failed earlier run. I did not rerun those harness/engine checks.

CONFIRM corrected explicit creative-v8/style-v4 binding is usable by the actual loader and remains within the previously scoped equivalent-rendering rebind. This does not approve browser retry, final v18 art, fun, devices, timing or deployment. No source edits/engine/browser; no expanded review.

Reproduction and results: `/tmp/forest-v18-style-v4-followup-review.py` and `.json`.
