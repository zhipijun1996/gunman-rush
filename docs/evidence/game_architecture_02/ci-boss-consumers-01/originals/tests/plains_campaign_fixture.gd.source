extends RefCounted
## Explicit outcome fixture; physical exploration is covered by the Motor traces.
static func second_map(app: DemoApp, tree: SceneTree) -> bool:
	var stage:=app.stage as PlainsRegionStage
	app.player.reset_at(stage.boss_arena.position+Vector2(540,202))
	for i: int in 3: await tree.physics_frame
	if not app._boss_started: return false
	var boss:=stage.boss.get_node("Encounter") as WindkeeperEncounter
	var request:=DamageRequest.new()
	request.token=app.lifetime.token()
	request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=boss.health.epoch
	request.target_id=&"boss"
	request.source_id=&"explicit_campaign_fixture"
	request.event_id=&"mini_fixture_defeat"
	request.amount=boss.health.current
	if not app.policy.submit(request): return false
	for i: int in 3: await tree.physics_frame
	for i:int in 60:await tree.physics_frame
	app.player.reset_at(stage.reward_position)
	for i: int in 2: await tree.physics_frame
	if not app.exit_modal.opened or not app._confirm_generated_exit(): return false
	for i: int in 8: await tree.physics_frame
	return app.director.stage_index==2 and app.stage is PlainsRegionStage and app.stage.assembly_ok
