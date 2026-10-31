extends RefCounted
## Compatibility entry for existing tests. Production owns the only drain logic.
const Lifecycle = preload("res://game/presentation/audio/world_audio_lifecycle.gd")

static func drain_world(world: Node, timeout_msec: int = 1000) -> bool:
	return await Lifecycle.drain_world(world, timeout_msec)

static func stop_fallback_voices(world: Node) -> Dictionary:
	return Lifecycle.stop_fallback_voices(world)

static func wait_fallback_release(receipt: Dictionary, timeout_msec: int = 1000) -> bool:
	return await Lifecycle.wait_fallback_release(receipt, timeout_msec)
