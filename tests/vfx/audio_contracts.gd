extends "res://tests/world/plains35_fixture.gd"
## Real formal assembly, accepted shot routing and paused-owner teardown.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await app.review.begin("P-R10","","base");await ticks(12)
 if app.story.active:app.story.finish()
 await fixture(Vector2(896,2030))
 var audio:=GameAudio.for_origin(app) as PlayerWeaponFeelAudioV2
 check(audio!=null,"formal shared weapon audio exists")
 for event:StringName in [&"pulse",&"machine",&"hit",&"ion_start"]:
  check(str(audio.weapon_clips[event][0].resource_path).begins_with("res://assets/audio/vfx_renewal/"),"formal V2 bank replaces actual cue "+str(event))
 app.controller.router.request_action(&"shoot_release",Vector2.RIGHT);await ticks(5)
 check(audio._voices.any(func(voice:AudioStreamPlayer)->bool:return voice.playing and voice.stream!=null and voice.stream.resource_path.begins_with("res://assets/audio/vfx_renewal/shot")),"accepted live shot uses newly authored recording")
 for key:StringName in GameAudio.RENEWAL_CUES:
  check(audio._streams[key]==GameAudio.RENEWAL_CUES[key],"old cue cache is replaced: "+str(key))
 var origin:=Node2D.new();app.add_child(origin)
 GameAudio.cue(origin,&"boss_arrival_air");await process_frame
 var voices:Array[AudioStreamPlayer]=[]
 for voice:AudioStreamPlayer in audio._voices:
  if voice.get_meta("cue_id",&"")==&"boss_arrival_air" and voice.playing:voices.append(voice)
 check(voices.size()==1 and voices[0].stream.resource_path.ends_with("vfx_renewal/boss_air.wav"),"arrival uses one scoped new air cue")
 paused=true
 var count:=int(audio.played.get(&"loot_scatter",0))
 GameAudio.cue(origin,&"loot_scatter")
 check(int(audio.played.get(&"loot_scatter",0))==count,"paused battle rejects new loot audio")
 origin.queue_free();await process_frame;await process_frame
 check(voices.is_empty() or voices[0].stream==null,"owner unload clears paused renewal tail")
 paused=false
 check(audio._voices.size()==12,"renewal uses the existing twelve voices")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("VFX AUDIO: ",failures," failures")
 quit(failures)
