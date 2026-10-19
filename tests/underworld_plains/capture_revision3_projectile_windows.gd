extends SceneTree
## Real formal DemoApp combat windows, NOT natural acquisition/traversal proof.
## Exactly one initialized player position; subsequent movement/shots are actual
## InputEvents. No health, energy, AI mode, weapon, cadence or epoch injection.
var app: DemoApp
var stage: PlainsRegionStage
var focus := "enemy"
var seed := "level-design-v2-baseline/08"
var frame_budget := 900
var output := "res://build/underworld_r3/projectiles/formal_window.json"
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var inventory: Array[Dictionary] = []
var failures: Array[String] = []
var initialization: Dictionary = {}
var target: Node2D
var pointer := Vector2.ZERO
var hostile_created := 0
var accepted_shots := 0
var accepted_damage := 0
var held: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func pair(p: Vector2) -> Array: return [p.x,p.y]
func key(code: Key,value: bool) -> void:
	if bool(held.get(code,false))==value: return
	held[code]=value
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=value
	Input.parse_input_event(event)
	events.append({"kind":"key","key":OS.get_keycode_string(code),"pressed":value,"row":rows.size()})
func mouse(value: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=pointer;event.global_position=pointer;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=value
	Input.parse_input_event(event)
	events.append({"kind":"mouse","pressed":value,"point":pair(pointer),"row":rows.size()})
func aim_at(point: Vector2) -> void:
	pointer=app.player.get_canvas_transform()*point
	var event:=InputEventMouseMotion.new();event.position=pointer;event.global_position=pointer;event.relative=Vector2(1,0)
	Input.parse_input_event(event)
func tick() -> void:
	await physics_frame
	await RenderingServer.frame_post_draw
	observe()
func observe() -> void:
	if not is_instance_valid(app.player) or not is_instance_valid(stage): return
	var projectiles: Array[Dictionary]=[]
	for child: Node in stage.get_children():
		if child is PlayerProjectile:
			projectiles.append({"type":"player","id":child.shot_id,"point":pair(child.global_position),"direction":pair(child.direction),"radius":child.radius,"spent":child.spent,"kind":str(child.art_kind),"skin":child.presentation.get_class() if is_instance_valid(child.presentation) else "native_draw","trail_samples":child.trail.size()})
		elif child is EnemyAttackProjectile:
			projectiles.append({"type":"enemy_seed","id":str(child.event_id),"source":str(child.behavior.source_id),"point":pair(child.global_position),"direction":pair(child.direction),"radius":child.radius,"spent":child.spent,"trail_samples":child._visual_trail.size()})
		elif child is BossProjectile:
			projectiles.append({"type":"ballistic_bell" if child is BellstriderBellProjectile else "boss","id":str(child.event_id),"point":pair(child.global_position),"direction":pair(child.direction),"radius":child.radius,"spent":child.spent,"visible_projectile":child._visible_attack(),"trail_samples":child._visual_trail.size()})
	var effects: Array[Dictionary]=[]
	for node: Node in get_nodes_in_group(&"underworld_projectile_vfx"):
		if node is UnderworldProjectileVisual:
			effects.append({"point":pair(node.global_position),"age":node.age,"friendly":node.friendly,"physical_contact":node.impact})
	var boss:=stage.boss.get_node("Encounter") as WindkeeperEncounter
	rows.append({"frame":rows.size(),"physics_frame":Engine.get_physics_frames(),"drawn_frame":Engine.get_frames_drawn(),"position":pair(app.player.global_position),"velocity":pair(app.player.velocity),"health":app.controller.actor_resources.health.current,"stamina":app.controller.actor_resources.stamina.current,"combat_energy":app.controller.combat_energy.current,"grounded":app.player.is_on_floor(),"boss_mode":str(boss.mode),"boss_health":boss.health.current,"boss_active":boss.active,"projectiles":projectiles,"effects":effects,"run_epoch":app.lifetime.epoch,"stage_epoch":app.lifetime.stage_epoch,"actor_epoch":app.lifetime.actor_epoch})
func enemy_window() -> Vector2:
	var selected := Vector2.INF
	for i: int in stage.enemies.size():
		var body:=stage.enemies[i]
		var actor:=body.get_node("Actor") as EnemyActor
		var id:=str(stage.enemy_manifest[i].id)
		inventory.append({"source_id":id,"position":pair(body.global_position),"behavior":str(actor.definition.behavior_id),"activation_range":actor.definition.activation_range,"protected_radius":actor.definition.protected_radius,"projectile_speed":actor.definition.projectile_speed,"projectile_lifetime":actor.definition.projectile_lifetime})
		if target!=null or actor.definition.behavior_id not in [&"sentry",&"fan_sentry"]: continue
		for slab: Rect2 in PlainsRegionScenery.solid_supports(stage):
			if slab.size.x<210 or not Rect2(slab.position-Vector2(0,80),slab.size+Vector2(0,80)).has_point(body.global_position): continue
			var x:=clampf(body.position.x-180,slab.position.x+30,slab.end.x-30)
			var candidate:=Vector2(x,slab.position.y-18)
			if candidate.distance_to(body.position)<65 or candidate.distance_to(body.position)>actor.definition.activation_range-20: continue
			var protected := false
			for p: Vector2 in actor.attack_behavior.protected_points:
				if candidate.distance_to(p)<actor.definition.protected_radius+5: protected=true
			if protected: continue
			target=body;selected=candidate
			initialization["selected_source_id"]=id
			initialization["selected_shooter_position"]=pair(body.position)
			initialization["initial_solid_support"]=[slab.position.x,slab.position.y,slab.size.x,slab.size.y]
			initialization["trigger"]="ordinary actual AI idle -> telegraph -> attack with line of sight and unprotected target; no _fire/state invocation"
			break
	return selected
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--focus="):focus=argument.trim_prefix("--focus=")
		if argument.begins_with("--seed="):seed=argument.trim_prefix("--seed=")
		if argument.begins_with("--frames="):frame_budget=int(argument.trim_prefix("--frames="))
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	root.size=Vector2i(1280,720)
	app=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false;root.add_child(app)
	for i: int in 8: await tick()
	if not app.start_plains(seed): failures.append("formal ordinary start failed")
	if focus=="windkeeper":
		app.director.stage_index=2;app._load_stage()
	stage=app.stage as PlainsRegionStage
	if stage==null:
		printerr("FORMAL PROJECTILE WINDOW failed to create actual formal stage");quit(1);return
	initialization={"scope":"real formal consumer combat window, initialized fixture position; not natural route or acquisition proof","operation":"DemoApp.start_plains(seed)","seed":seed,"focus":focus,"map_index":app.director.stage_index,"manifest_hash":stage.generated.manifest.manifest_hash,"source_actors_and_AI_unchanged":true,"resource_or_health_injection":false,"AI_state_injection":false,"after_initialization":"actual Input.parse_input_event mouse/keyboard, original KeyboardMouseAdapter/Router/PlayerMotor and AI"}
	var at:=enemy_window() if focus=="enemy" else Vector2(stage.boss_arena.position.x+125,stage.boss_arena.end.y-18)
	if focus!="enemy":
		target=stage.boss
		initialization["selected_source_id"]=str((stage.boss.get_node("Encounter") as WindkeeperEncounter).definition.stable_id)
		initialization["selected_shooter_position"]=pair(stage.boss.position)
		initialization["trigger"]="normal DemoApp._in_boss_core -> _start_generated_boss; natural attack pattern, no activate/_enter invocation"
	if at==Vector2.INF or target==null:
		failures.append("no supported unprotected formal ranged actor in this manifest")
	else:
		app.player.global_position=at
		initialization["single_initialized_player_position"]=pair(at)
		app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2,id: int):
			accepted_shots+=1;events.append({"kind":"accepted_shot","direction":pair(direction),"shot":id,"row":rows.size(),"stamina_after":app.controller.actor_resources.stamina.current}))
		app.controller.shoot_ability.projectile_impacted.connect(func(point: Vector2,direction: Vector2):events.append({"kind":"physical_contact_only","point":pair(point),"direction":pair(direction),"row":rows.size()}))
		app.policy.batch_resolved.connect(func(results: Array[DamageResult]):
			for result: DamageResult in results:
				accepted_damage+=1
				events.append({"kind":"committed_damage","event":str(result.request.event_id),"source":str(result.request.source_id),"target":str(result.request.target_id),"amount":result.request.amount,"health":result.health.current,"direction":pair(result.request.hit_direction),"row":rows.size()}))
		var boss:=stage.boss.get_node("Encounter") as WindkeeperEncounter
		boss.projectile_created.connect(func(shot: BossProjectile):
			hostile_created+=1;events.append({"kind":"actual_boss_projectile_created","event":str(shot.event_id),"direction":pair(shot.direction),"row":rows.size()}))
		for body: EnemyMotor in stage.enemies:
			var actor:=body.get_node("Actor") as EnemyActor
			if actor.attack_behavior!=null:
				actor.attack_behavior.state_changed.connect(func(state: StringName):events.append({"kind":"actual_enemy_state","state":str(state),"row":rows.size()}))
		for i: int in frame_budget:
			if not is_instance_valid(app.player) or not app.lifetime.active or app.controller.actor_resources.health.terminal: break
			var aim:=target.global_position if is_instance_valid(target) else at+Vector2(200,-20)
			if target==stage.boss: aim+=(stage.boss.get_node("Encounter") as WindkeeperEncounter).core_offset()
			aim_at(aim)
			# Slow repeated ordinary clicks let standing recovery/refunds follow
			# their original rules; no hold-to-auto-fire/resource injection.
			if i%66==10: mouse(true)
			if i%66==11: mouse(false)
			# Real jump input supplies an ordinary dodge; it is not phase forcing.
			key(KEY_SPACE,focus!="enemy" and i%95<12)
			await tick()
	for code: Variant in held.keys(): key(code,false)
	mouse(false)
	if accepted_shots==0:failures.append("no actual accepted player shot")
	if focus!="enemy" and hostile_created==0:failures.append("no actual Boss projectile; current window insufficient")
	var seeds:=0
	for row: Dictionary in rows:
		for projectile: Dictionary in row.projectiles:
			if projectile.type=="enemy_seed":seeds+=1
	if focus=="enemy" and seeds==0:failures.append("no actual enemy ranged projectile; current candidate/window insufficient")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"initialization":initialization,"formal_actor_inventory":inventory,"accepted_shots":accepted_shots,"accepted_damage":accepted_damage,"boss_projectiles_created":hostile_created,"enemy_seed_visible_rows":seeds,"failures":failures,"events":events,"frames":rows,"capture":"MovieMaker 60fps normal simulation/playback; software wall-clock not device FPS; audio not listening acceptance"},"  "));file.close()
	if not await load("res://tests/audio_teardown.gd").drain_world(app): failures.append("audio teardown")
	app.queue_free()
	for i: int in 5: await process_frame
	print("R3 FORMAL PROJECTILE WINDOW: ",focus," frames=",rows.size()," shots=",accepted_shots," accepted_damage=",accepted_damage," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
