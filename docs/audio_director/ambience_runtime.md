# Environment ambience audition transport · AUDIO-AMBIENCE-01

`GameAudio.configure_ambience(manifest_path)` explicitly creates an app-owned `GameAmbience` component. The formal default remains original and allocates no ambience voices. The existing original forest short wind cue and the 12 transient SFX voices keep their behavior. Long Vorbis beds require **two additional streaming players** for crossfades; up to two additional detail players are allocated only with this explicit development component. Maximum opt-in app budget is therefore 12 transient + 2 beds + 2 details, plus the existing two music voices. This is a sustained-media transport with the same app, volume, Ambience bus and shutdown; it is not another gameplay event system.

```gdscript
audio.configure_ambience("res://assets/audio/ambience_v1/manifest.json")
audio.set_ambience_region("plains", "A", stage, player)
audio.ambience.play_detail("plains_chime", actual_bell.global_position)
audio.set_ambience_region("forest", "B", stage, player)
audio.set_ambience_region("forest", "original", stage, player)
```

The manifest `regions.<region>.profiles.<A|B>` is the runtime authority: `bed`, `gain_db`, optional `details` with `id/path/gain_db/min_interval/max_distance`. The duplicate `events` catalogue serves browsing. Resource paths are confined to `assets/audio/ambience_v1`; malformed, missing, nonfinite or unbounded values reject the entire proposal before changing the active configuration. Vorbis resources are duplicated before enabling loop so imported resources remain untouched. The producer authors the loop seam; setting the loop flag does not prove its audio quality.

Bed changes use a 1.2 second linear gain crossfade. Same owner/listener/region/profile requests do not restart it; rapid switches remain inside the two-player bound. Gain is session volume × authored gain × fade gain. The new bed files are already quiet by design; the runtime does not apply a second large attenuation. No music bytes, music gain, bus gain or gameplay timescale is changed.

Details require an actual source coordinate from a real scene object; there is no invented whole-map source, periodic unconditional chime or gameplay RNG use. Listener distance controls linear attenuation to zero at `max_distance`; positions update while the listener moves. This implementation provides distance attenuation **without stereo panning, obstruction or reverb**. It does not claim 2D acoustic simulation. Cooldowns are per detail ID within a stage context and use a presentation real-time clock. Only two simultaneous detail players are available; excess requests are refused, without stealing combat voices.

Paused trees pause both beds and details and freeze the fade/cooldown clock. Zero session volume pauses continuous audio immediately. A real user key/pointer/touch/gamepad gesture unlocks Web playback, following the music service pattern; canceled touch and key echo do not unlock it. Browser/audio-device validation remains separate from native transport tests.

The actual DemoApp `player` is a `PlayerMotor`, which does not expose `died`. The audition lab therefore also binds the accepted `PlayerController.died` event to `clear_ambience`, and disconnects that binding when replacing the controller. Other consumers must provide that real death hook; the optional listener signal alone does not cover a PlayerMotor. The native lifecycle fixture calls the formal Controller death entry explicitly; it does not claim a natural enemy-caused death route.

The component retains weak references to its stage owner and listener. Their unload clears all new playback on the next processing tick. An accepted listener `died` signal clears it immediately; replacement disconnects the old listener signal. `GameAudio.stop_regional_cues`, `clear_ambience`, original comparison and app shutdown stop the component. Shutdown uses weak backend playback references and a wall-clock bound, retaining failures. No health, movement, rewards, ability, save or gameplay RNG state is written.

`snapshot()` exposes actual stream paths, candidate IDs, playing/paused state, linear fade gain, volume dB and backend playback positions, plus start counts. These are diagnostic receipts, not proof that the intended media reached the encoded recording or that the user likes its sound.

Targeted native command (run by the main integration owner under the engine lease):

```sh
bash tools/godot.sh --headless --path . --script res://tests/audio_ambience_runtime.gd
```

Tests cover actual imported streams, original default, atomic rejection, cross-region idempotence, bounded voices, positioned detail/cooldown/distance, pause/mute, listener replacement/death, owner unload, old region cleanup and backend shutdown. User hearing, real-phone speakers, Web latency and commercial polish remain unverified.
