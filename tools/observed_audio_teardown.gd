extends RefCounted
## Observer cleanup only, after the last recorded gameplay/assertion frame.
static func drain_service(audio: Node, timeout_msec: int = 1000) -> bool:
	if audio.has_method("shutdown"):
		return bool(await audio.call("shutdown", timeout_msec))
	# Frozen v9 intentionally keeps its original GameAudio bytes and old API.
	var started := Time.get_ticks_msec()
	var pending: Array[WeakRef] = []
	var owners: Array[Dictionary] = []
	for voice: AudioStreamPlayer in audio.find_children("*", "AudioStreamPlayer", true, false):
		if voice.has_stream_playback():
			owners.append({"node":str(voice.get_path()),"stream":voice.stream.resource_path if voice.stream != null else "","playback_id":voice.get_stream_playback().get_instance_id()})
			pending.append(weakref(voice.get_stream_playback()))
		voice.stop()
		voice.stream = null
	# Old play() checks volume before emitting cues during transport-only frames.
	audio.set("volume", 0.0)
	while pending.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		if Time.get_ticks_msec()-started >= timeout_msec:
			print("OBSERVED AUDIO TEARDOWN: ",JSON.stringify({"legacy":true,"released":false,"owners":owners,"seconds":float(Time.get_ticks_msec()-started)/1000.0}))
			return false
		await audio.get_tree().process_frame
	print("OBSERVED AUDIO TEARDOWN: ",JSON.stringify({"legacy":true,"released":true,"owners":owners,"seconds":float(Time.get_ticks_msec()-started)/1000.0}))
	return true
