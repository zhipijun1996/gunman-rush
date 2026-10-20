# Mobile ACTIONS screenshot candidate: limited independent review

SCOPED_CANDIDATE_ACCEPT for the four source hashes recorded in the JSON, atop Q `4aec8b56743d1a14d1b44ba43d795e56811d7615`. Independently ran the unchanged pure-test entry once: **25/25 passed in 40.274s**, exit0. Two additional targeted negative controls passed.

I actually viewed the original failed observer PNG: the complete bilingual label is visible. The raw fixture is byte-identical to that PNG. Complete colored-border extraction remains unchanged; only a missing OCR label permits a single measured, closed inner-fill crop with fixed 8x Lanczos/psm7. Complete-word/unique-glyph parsing remains unchanged. First-pass ambiguity cannot fall back. Removing the inner fill’s top boundary also refuses the crop while preserving its text.

Independent AST comparison preserves all prior21 test methods and every original helper function except the intended ACTIONS OCR function. Six original browser CLIs, five observations, original caps, real inputs and gameplay assertions remain unchanged. No new fixed click coordinates, label spelling tolerance or runtime parameter search were introduced.

This accepts the bounded screenshot parser candidate only. It does not pass a live mobile click, any original browser consumer, slowtime behavior, public delivery or a device. Both the original Q upward-hook failure and the observer’s later ACTIONS failure/slowtime false remain failures. The production sampling clock has a separate review.
