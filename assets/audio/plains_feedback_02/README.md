# Plains material feedback 02

Nine short, recorded-source cues distinguish a light accepted hurt, lethal
fracture/disassembly and subsequent physical contact for shell, copper wing and
plant bodies. Only the seven revised plains species and their patrol alias opt
in. Root Bell keeps its existing recorded low-bell contact as its single landing
voice, with no additional generic thump layered over it.

All layers are preserved rubberduck CC0 recordings from the existing reviewed
OpenGameArt library. `provenance.json` includes original author, URL, original
file/archive/source-page SHA, commercial conditions and exact recorded inputs.
`recipes.json` records every speed/filter/crop/offset/gain. There are no generated
oscillator or noise layers, and no commercial-game audio is used.

Rebuild with `python3 tools/build_plains_feedback_02_audio.py`. The generator
checks each source SHA and license before decoding with ffmpeg. Output is mono
48 kHz/16-bit PCM with bounded peak and short fades; source audio is unchanged.

`PlainsEnemyAudio` consumes accepted Actor events. `GameAudio` still owns the
same12voice pool; death is capped at3 simultaneous voices and may preempt only
lower-priority cues, preserving critical player/warning sounds. Hurt and landing
are separately bounded. Origin ownership uses existing weak-reference cleanup;
restored corpse state never plays a death or landing sound. Coin/heal selections,
other species/Boss sounds and all BGM bytes are untouched.

Waveform/source validation is technical evidence only. Final timbre, normal-speed
mix, AV sync, fatigue and physical-device listening remain for actual review.
