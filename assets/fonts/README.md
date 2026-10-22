Noto Sans SC, Google Fonts / SIL Open Font License 1.1 (OFL.txt).

Source: https://github.com/google/fonts/tree/main/ofl/notosanssc
Downloaded 2026-10-11. `windkeeper_ui.ttf` is a fontTools static weight-600 instance and compatibility subset containing ASCII and recorded Chinese UI literals. It was prepared for the original Windkeeper HUD, Boss objectives, item cards and Plains resource feedback. Current formal `UnderworldUI` consumers, including item cards/acquisition feedback and Windkeeper HUD, use `foundry_notes.otf`; this compatibility font is licensed separately from game art. The source copyright belongs to Adobe, with reserved name "Source"; the subset retains the Noto Sans SC naming and does not use "Source" as its font name. Web and Windows exports include the full copyright/license beside the runtime.

D073: subset expanded to all current Boss, ammunition rejection and session-volume Chinese feedback. Rebuild with `python3 tools/subset_plains_ui_font.py <original-variable-ttf>`. The committed subset is used directly at runtime; fontTools is only a preparation dependency. Full ASCII is retained. Original source file SHA256: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`.

D077: subset also covers Bellstrider Chinese display name and all roll/ring/lob/core cues. Its formal Boss HUD has one actual half-health intensity marker. The original OFL source and runtime usage are unchanged.

D079: subset includes all actual item resources and shared item-card/acquisition UI, plus formal energy feedback. Runtime consumers now include reward/shop/build cards; OFL license and original font source remain unchanged.

FOREST-PLAYABLE-01: rebuilt by the same tool from the same SHA-verified OFL source to cover all current item-card literals, including `forest_heart_gold.tres`. Glyph coverage is checked against actual runtime item resources; user/device typography approval remains unverified.

FOREST-DEPTH-02: the same SHA-verified OFL source now also covers actual encounter objectives and names across `scripts/bosses/*.gd` and `resources/bosses/*.tres`. The existing codepoints are preserved when rebuilding; new forest cues must not display missing-character boxes. This is UI readability work, not final typography or art approval.

FOREST-DEPTH-02 Canopy: preserve all462 prior codepoints and their exact metrics/decomposed outlines; add `岸` for the actual phase3 objective using the same SHA-verified OFL source and weight600 tool. The new463 subset fixes portable glyph availability, without signing pixel, device or typography approval.

FONT-499 compatibility repair (2026-10-21): use the unchanged tool and SHA-verified original source to preserve all463 prior codepoints, exact metrics and decomposed outlines, and expand to499 (+36) from all current declared UI/Boss/item inputs. The actual compatibility guard was triggered by8 unique glyphs in `forest_old_badge.tres` and `forest_spiral_core.tres` (依徽照片螺衬质配); the unchanged input collection also requests28 other codepoints. Current formal Underworld UI already covers these literals through `foundry_notes.otf`. Candidate/committed subset SHA256: `3bf7b6feba4846ffab733aa19650b9be26c4ea469b59e2f8b22a0fa3542034ab`. The existing OFL is retained; glyph coverage and static preservation do not establish device, typography or final art approval.
