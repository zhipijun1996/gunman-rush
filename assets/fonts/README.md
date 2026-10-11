Noto Sans SC, Google Fonts / SIL Open Font License 1.1 (OFL.txt).

Source: https://github.com/google/fonts/tree/main/ofl/notosanssc
Downloaded 2026-10-11. `windkeeper_ui.ttf` is a fontTools static weight-600 instance and subset containing ASCII and the Chinese glyphs used by WindkeeperHud/WindkeeperEncounter. Used only in Boss UI, including the original name layout; font is licensed separately from game art. The source copyright belongs to Adobe, with reserved name "Source"; the subset retains the Noto Sans SC naming and does not use "Source" as its font name. Web and Windows exports include the full copyright/license beside the runtime.

D073: subset expanded to all current Boss, ammunition rejection and session-volume Chinese feedback. Rebuild with `python3 tools/subset_plains_ui_font.py <original-variable-ttf>`. The committed subset is used directly at runtime; fontTools is only a preparation dependency. Full ASCII is retained. Original source file SHA256: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`.

D077: subset also covers Bellstrider Chinese display name and all roll/ring/lob/core cues. Its formal Boss HUD has one actual half-health intensity marker. The original OFL source and runtime usage are unchanged.
