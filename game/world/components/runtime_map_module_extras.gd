class_name RuntimeMapModuleExtras
extends Node2D
## Source-bound special objects beside the shared latch consumer. Existing actor
## factories, reward ledgers, collision motors and damage policy stay authoritative.
var error: String=""
var _stage: PlainsRegionStage
var _player: PlayerController
var _lifetime: DemoLifetime
var _state: PlainsRegionState
var _rows: Array[Dictionary]=[]
var _turrets: Array[Dictionary]=[]
var _starts: Array[Dictionary]=[]
var _rewards: Array[Dictionary]=[]
var _waves: Array[Dictionary]=[]
var _releases: Array[Dictionary]=[]
var _cancelled:=false
func setup(rows: Array[Dictionary],stage: PlainsRegionStage,player: PlayerController,lifetime: DemoLifetime,state: PlainsRegionState) -> bool:
	if stage==null:return true # An explicit legacy slice has no full-map extras.
	_stage=stage;_player=player;_lifetime=lifetime;_state=state;_rows=rows;process_physics_priority=800
	for row: Dictionary in rows:
		var content: Dictionary=row.content
		var saved: Dictionary=state.mechanisms.get(str(row.instance_id)+"/runtime",{})
		var enemies: Dictionary={}
		for index: int in stage.enemies.size():
			var id: String=str(stage.enemy_manifest[index].id)
			for raw: Dictionary in content.get("enemies",[]):
				if id=="plains/map_%s/%s/%s" % [stage.map_index,row.instance_id,raw.id]:enemies[str(raw.id)]=stage.enemies[index]
		for spec: Dictionary in content.get("approved_hq_cells",[]):
			match str(spec.kind):
				"hit_turret":
					var target: RuntimeMapRelayLatch=row.latches.get(str(spec.latch_id))
					if target==null:error="missing bound turret receiver";return false
					var turret:=RuntimeMapTurret.new();turret.position=row.module.position;add_child(turret);turret.setup(spec,player,lifetime,target)
					var previous: Dictionary=saved.get("turrets",{}).get(str(spec.id),{})
					if not previous.is_empty():
						if not LevelContentValidation.number(previous.get("clock")) or not LevelContentValidation.number(previous.get("next_hit")) or not LevelContentValidation.number(previous.get("serial")):error="invalid turret snapshot";return false
						turret.clock=float(previous.clock);turret.next_hit=float(previous.next_hit);turret.serial=int(previous.serial)
					_turrets.append({"instance_id":row.instance_id,"id":str(spec.id),"node":turret})
				"support_start_motion":
					var platform: ModuleMovingPlatform=row.carriers[str(spec.id)]
					var started: bool=saved.get("support_started",[]).has(str(spec.id))
					if not saved.get("platforms",{}).has(str(spec.id)):platform.bind_bell_control()
					_starts.append({"instance_id":row.instance_id,"id":str(spec.id),"platform":platform,"started":started})
				"reward_pair":
					var latch: RuntimeMapPairedLatch=row.latches[str(spec.id)]
					_rewards.append({"latch":latch,"claim":_claim_key(row,str(spec.reward_id))})
		if content.has("review040_release"):
			var release: Dictionary=content.review040_release
			var claim:=_claim_key(row,str(release.reward_id))
			_releases.append({"module":row.module,"index":int(release.platform_index),"claim":claim})
			if _state.claimed.get(claim,false):row.module.release_platform(int(release.platform_index))
		for binding: Dictionary in content.get("refresh_carried_enemies",[]):
			if not enemies.has(str(binding.enemy)):error="missing carried enemy";return false
			var support:=RuntimeMapCarrierSupport.new();add_child(support)
			support.setup(enemies[str(binding.enemy)].get_node("Actor"),row.carriers[str(binding.carrier)],int(content.get("refresh_carrier_warmup_frames",2)))
		if content.has("review029_wave"):
			var wave: Dictionary={"instance_id":row.instance_id,"module":row.module,"spec":content.review029_wave,"enemies":enemies.values(),"triggered":bool(saved.get("wave_triggered",false)),"pending":false}
			for enemy: EnemyMotor in enemies.values():_set_enemy_active(enemy,wave.triggered)
			var area:=Area2D.new();area.position=row.module.position+RuntimeMapShotLatchAdapter.rectangle(content.review029_wave.rect).get_center();area.collision_layer=0;area.collision_mask=player.motor.collision_layer
			var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=RuntimeMapShotLatchAdapter.rectangle(content.review029_wave.rect).size;shape.shape=box;area.add_child(shape);add_child(area)
			area.body_entered.connect(func(body:Node2D) -> void:
				if body==player.motor and not wave.triggered and not wave.pending:wave.pending=true;_trigger_wave.call_deferred(wave))
			_waves.append(wave)
	return true
func _claim_key(row: Dictionary,id: String) -> String:
	var key: String="plains/map_%s/%s/%s" % [_stage.map_index,row.instance_id,id]
	for cache: Dictionary in _stage.chests:
		if str(cache.id)==key+"/item":return str(cache.id)
	return key
func _live() -> bool:
	return not _cancelled and _lifetime!=null and _lifetime.active and is_instance_valid(_player) and _player.active and not _player.actor_resources.health.terminal
func _set_enemy_active(enemy: EnemyMotor,value: bool) -> void:
	if not enemy.has_meta("mapgen_active_layer"):enemy.set_meta("mapgen_active_layer",enemy.collision_layer)
	var actor:=enemy.get_node("Actor") as EnemyActor
	var active:=value and not actor.health.terminal
	enemy.collision_layer=int(enemy.get_meta("mapgen_active_layer")) if active else 0
	enemy.process_mode=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	enemy.visible=active
func _trigger_wave(wave: Dictionary) -> void:
	wave.pending=false
	if not _live() or wave.triggered:return
	wave.triggered=true
	for enemy: EnemyMotor in wave.enemies:_set_enemy_active(enemy,true)
	capture_state()
func _physics_process(delta: float) -> void:
	if not _live():return
	for row: Dictionary in _releases:
		if _state.claimed.get(row.claim,false):row.module.release_platform(row.index)
	for row: Dictionary in _starts:
		if row.started or not _player.motor.is_on_floor():continue
		for index: int in _player.motor.get_slide_collision_count():
			var collision:=_player.motor.get_slide_collision(index)
			if collision.get_collider()==row.platform and collision.get_normal().y<-.5:row.started=true;row.platform.set_motion_running(true);break
	for row: Dictionary in _rewards:
		if _state.claimed.get(row.claim,false) and row.latch.open_a:row.latch.accept_claim(str(row.claim))
	for wave: Dictionary in _waves:
		if not wave.triggered:continue
		for enemy: EnemyMotor in wave.enemies:
			var actor:=enemy.get_node("Actor") as EnemyActor
			if actor.health.terminal or actor._damage_stun_remaining>0 or actor._stagger_remaining>0:continue
			var offset: float=wave.module.to_global(Vector2(float(wave.spec.targetX),0)).x-enemy.global_position.x
			if absf(offset)>1:enemy.move_attack(Vector2(signf(offset)*minf(absf(offset),float(wave.spec.speed)*delta),0),false,delta)
func capture_state() -> void:
	if _state==null:return
	for source: Dictionary in _rows:
		var key:=str(source.instance_id)+"/runtime"
		var saved: Dictionary=_state.mechanisms.get(key,{})
		var turrets: Dictionary={}
		for row: Dictionary in _turrets:
			if row.instance_id==source.instance_id and is_instance_valid(row.node):turrets[str(row.id)]={"clock":row.node.clock,"next_hit":row.node.next_hit,"serial":row.node.serial}
		if not turrets.is_empty():saved["turrets"]=turrets
		var started: Array=[]
		for row: Dictionary in _starts:
			if row.instance_id==source.instance_id and row.started:started.append(str(row.id))
		if not started.is_empty():saved["support_started"]=started
		for wave: Dictionary in _waves:
			if wave.instance_id==source.instance_id:saved["wave_triggered"]=wave.triggered
		_state.mechanisms[key]=saved
func cancel_pending() -> void:
	for row: Dictionary in _turrets:
		if is_instance_valid(row.node):row.node.cancel_pending()
func cancel() -> void:
	_cancelled=true;cancel_pending();process_mode=Node.PROCESS_MODE_DISABLED
func _exit_tree() -> void:cancel()
