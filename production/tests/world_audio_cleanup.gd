extends RefCounted
## A fixed-FPS test can end before the audio mixer has retired its last loop.
## Keep the shell alive until each owner confirms that its playbacks are gone.
static func drain(shell: WorldShell) -> bool:
	var scene_ok := true
	if is_instance_valid(shell.world) and is_instance_valid(shell.world.active):
		scene_ok = await shell.world.active.audio_service.shutdown()
	var audio := shell.get_node("WorldAudio") as PlayableWorldAudio
	var music_ok := await audio.music.shutdown()
	var ambience_ok := await audio.ambience.shutdown()
	return scene_ok and music_ok and ambience_ok
