# Forest ambience saturation fixture repair — native verification pending

Only `tests/forest_bible_ambience_runner.gd` is changed. The original failure remains attributed to PR130/head9ba7/run41679005631, with the original audit and native capture retained. Its click stream lasts10.023ms; cumulative accepted cue count does not establish12 simultaneously occupied voices.

The existing pool case now makes a clearly marked local fixture from each actually loaded stream. It duplicates the resource and only changes the duplicate's loop configuration, before any play call. WAV copies retain actual sample data/format/rate/stereo and a valid full-stream loop interval; Ogg copies retain the original imported packet sequence. Original stream loop settings are captured before copying and checked again after playback. No disk asset, GameAudio, CUES, production stream, pooling policy or other native case is modified.

All39 original check statements remain verbatim and in order, including actual regional source paths, all12 cue play/count/live-playback/stream-pointer checks, the original13th rejection and zero note count, twelve nodes, tags, and all later cases. All six original case append statements remain; the original wrapper therefore keeps its exact six-case contract. New observations are nested only within the existing pool record.

Additional checks establish12 actual playing/has-playback voices before and after an explicit bounded50ms hold, verify unchanged original stream flags/payloads and all12 unique cue identities, then stop exactly the click voice. The original note must subsequently be accepted/counted once by that same existing node, with11 other slots still occupied and no thirteenth node allocated. This tests saturation and legitimate free-slot reuse separately without weakening the original rejection.

No Godot/browser was started by this child; root owns the engine lease. Static statement retention, unchanged non-pool suffix, unchanged GameAudio/wrapper/assets and unchanged original Harness210s/native90s contract are checked in fixture-static-02.json. Actual parsing, playback and strict cleanup remain unverified.

Root reproduction: `GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains python3 tools/run_forest_bible_ambience.py --skip-import --output-dir build/mapgen041/ambience-fixture-01`, after root's normal lockedGodot4.7.2 import. Then retain the original forest-bible-ambience Harness check and independent review. Do not reuse an existing capture directory or rewrite old failures.
