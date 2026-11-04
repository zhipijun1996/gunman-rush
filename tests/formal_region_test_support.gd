extends RefCounted
## Loading duration follows the cooperative source, not a fixed frame count.
static func ready(app: DemoApp, tree: SceneTree, timeout_ms: int = 120000) -> bool:
	var started := Time.get_ticks_msec()
	while app.lifetime.active and app._stage_pending and Time.get_ticks_msec()-started<timeout_ms:
		await tree.process_frame
	return app.lifetime.active and not app._stage_pending and is_instance_valid(app.stage) and app.stage.assembly_ok
