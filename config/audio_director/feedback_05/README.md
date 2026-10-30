# AUDIO-FEEDBACK-05 sampled feedback revision

Version `audio-feedback-v1` is a new candidate revision for two real-play feedback failures: player hurt C and the Freedoom wall/floor impact. It does not rewrite the retained selection or old candidates. Pleasantness and the real-game mix require listening; successful rendering is not aesthetic acceptance.

## Material choices

- `hurt_1`: Kenney `impactPunch_medium_000.ogg` + short `cloth1.ogg` crop. `hurt_2`: Kenney `impactSoft_heavy_000.ogg` + another cloth crop. No old wood layer, reward jingle, piano note, or added voice.
- `wall_1/2/3`: rubberduck `stones_01/02/03.ogg` (three original takes), each with a very light short cloth texture. No Freedoom sample, military casing, metal ricochet, or reward bell. The intended metaphor is a small magical projectile breaking up on stone; the source recordings themselves are not claimed to be recorded magic.
- Each cue has two sampled layers at most, explicit crop/pitch/filter/envelope/timing, and a bounded final gain. No oscillator or random noise synthesis is used. Hurt uses two different original body samples; cloth crops are from one original take, not separate recording sessions.

The six used originals, their authors, URLs, license terms, commercial use/attribution requirements, original download dates, review date, source/archive SHA256, and retained proof paths are recorded in `sources.json` and embedded in the output manifest. Existing raw originals and license evidence are referenced at their exact Git paths, not redownloaded or relabeled with a new download date.

| Original family | Author / page | License proof |
| --- | --- | --- |
| Punch and soft impact | Kenney, https://kenney.nl/assets/impact-sounds | Original `kenney-impact-sounds/LICENSE.txt`, CC0-1.0, commercial use permitted, attribution optional |
| Cloth | Kenney, https://kenney.nl/assets/rpg-audio | Original `kenney-rpg-audio/LICENSE.txt`, CC0-1.0, commercial use permitted, attribution optional |
| Three stone takes | rubberduck, https://opengameart.org/content/80-cc0-rpg-sfx | Original source HTML + CC0 legal text; original archive SHA `1c2f06ff4e8563b5b8b745b23cf213c1474142a69bb82bd8f5e10d9b3f7a7bbd`, no attribution condition |

## Reproduction and protection

```sh
python3 tools/audio_feedback_design.py build
python3 tools/audio_feedback_design.py validate
```

The wrapper calls the existing V3 `layer_pcm`/`render` implementation and fingerprints that unmodified processor. Sources, licenses and the inherited registry are checked before and after rendering. Staging prevents failed source-drift attempts from replacing the existing candidates. Validation rerenders every take and checks its exact bytes and full DSP trace; event IDs, variant order, sample identity and provenance are bound to the recipe.

The eleven protected inputs include the original selected mapping, old V3 manifest/recipe/source registry/processor, rejected hurt C original, and five supplied BGM files. They are read-only SHA locks; no BGM is generated or processed. The manifest remains awaiting-user and original by default; actual feedback integration is an explicit runtime change owned by the main implementation.

## Gain and audition

Sources target approximately −26 dBFS whole-cue RMS, with a −6 dBFS sample-peak ceiling. The source file level is not the level heard in the game:

| Event | Source target | Existing runtime attenuation | Session volume | Approximate output RMS |
| --- | --- | --- | --- | --- |
| Hurt | −26 dBFS | −8 dB | 0.7 (−3.10 dB) | −37.10 dBFS |
| Wall | −26 dBFS | −17 dB | 0.7 (−3.10 dB) | −46.10 dBFS |

Peak limiting can make the measured RMS lower than the target; each WAV's actual metrics are in the manifest. These are arithmetic estimates before other bus/device settings, not measured in-game audibility. Wall is intended to remain below enemy-hit feedback at its actual runtime gain. A first −9 dBFS ceiling made stone bodies too low against the intended runtime attenuation; its five WAVs/manifest/log are retained under `build/audio_feedback_05/first-render/`, and the current recipe uses −6 dBFS while keeping the same −26 RMS target. This is a technical gain correction, not a claim that the material sounds good.

The model has not performed human hearing. Check softness, damage clarity, a possible wooden or percussive association, whether wall impacts still suggest ordinary gunfire, repetition fatigue, and BGM masking in the actual Godot player/enemy scene. If the material is still wrong, replace the source or design rather than equating loudness or a passing checksum with quality.
