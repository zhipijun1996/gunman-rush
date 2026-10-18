# Canopy font glyph delta — bounded ACCEPT

Reviewer: `/root/forest_runtime_review`, independent of the font rebuild. This review covers font data and literal coverage only. It does not approve pixel rendering, typography, devices, gameplay, or release readiness.

I independently loaded the old and rebuilt TTF with fontTools and recomputed the comparison in `audit.py`. Old SHA256: `53c279ff4dd2d12956ca81fa7893ca8458a5b34bba4568dbc7cc8e5f8cbd2b91`; new SHA256: `10f1b70436e051bca13db2ded17f40771b72beeb96a5cb7e3347711eef0b6e12`. All audited inputs remained unchanged during the run.

The cmap grows from 462 to 463 codepoints, adding only U+5CB8 (`岸`). Every previous Unicode mapping retains its glyph name, exact decomposed outline, horizontal metrics and vertical metrics. The audited font-wide layout metrics remain exact. All previous glyph outline/metric signatures, including unmapped glyphs, remain present with multiplicity. Anonymous `glyphNNNN` names can be renumbered when the subset grows; those unmapped glyphs were compared by decomposed geometry and metrics rather than incidental generated names.

All three actual Canopy objective strings and its resource display name have full coverage. An additional scan of every non-ASCII character in the current Boss script/resource glob finds no missing codepoint. This checks available glyph data, not runtime fallback, shaping, actual HUD pixels or readability.

The existing subset tool is unchanged at SHA256 `23a5d60d54c8764b2cc93ac399d5466c5e78bd90897513fd0aa7ccf7a3d99a91`; it preserves the previous cmap, instantiates weight 600, and includes Boss scripts/resources. The original-source SHA `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da` is the rebuilder's verified provenance, repeated in the source README; I did not independently rebuild or re-download that original variable font in this audit. License and asset-record maintenance remain the implementing author's responsibility. The runtime TTF has one hard link.

No engine or browser ran. The pre-fix CI/build cannot prove this new binary's export or delivery. A new source commit and its actual CI/artifact validation remain necessary. The result is limited ACCEPT for preservation of the old font data and addition of the missing glyph at the exact SHA above.
