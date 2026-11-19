# Kenney CC0 game sounds

Unmodified OGG files downloaded from Kenney's official Interface Sounds, Impact Sounds, Digital Audio and RPG Audio packs on 2026-10-11. Each file's original name, pack URL, CC0 license and SHA256 are recorded in [sources.json](sources.json). The four original license texts are included in this directory and copied beside Web/Windows exports by `tools/build.py`.

Runtime uses `GameAudio` for real events and the licensed bell cue for standalone latch fixtures. No synthetic gameplay outcome is produced by audio; successful collection is played after an accepted transaction. Twelve central voices, per-event cooldown, separate session volume, existing Master mute and pausable world voices keep overlapping events bounded. UI clicks remain available in paused menus. The older generated WAV files stay for historical assets/tests, but the current formal consumer uses these CC0 OGG cues.
