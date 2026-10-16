extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var audio:=GameAudio.new()
 root.add_child(audio)
 if not audio.play(&"click"):quit(2);return
 var held: AudioStreamPlayback=audio._voices[0].get_stream_playback()
 var before:=Time.get_ticks_msec()
 var released: bool=await audio.shutdown(5)
 var elapsed:=Time.get_ticks_msec()-before
 if released or elapsed>250 or held==null:push_error("SHUTDOWN BOUND FALSE ACCEPT: "+str([released,elapsed]));quit(1);return
 held=null
 var retry: bool=await audio.shutdown(1000)
 audio.free()
 await process_frame
 print("AUDIO SHUTDOWN BOUND: held ref rejected in %sms; release retry=%s"%[elapsed,retry])
 quit(0 if retry else 1)
