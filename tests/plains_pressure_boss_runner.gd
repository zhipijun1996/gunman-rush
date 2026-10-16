extends SceneTree
## New attacks use real physics/shot/damage; positions below are explicit fixtures.
var assertions:=0
var failures:=0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var boss: BossMotor
var encounter: WindkeeperEncounter
var life: DemoLifetime
var policy: FrameDamagePolicy
var created: Array[Dictionary]=[]
var armour_hits:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func fixture(mini: bool, at: Vector2=Vector2(350,582)) -> void:
	if is_instance_valid(world): world.free()
	world=Node2D.new();root.add_child(world)
	var module:=preload("res://scenes/generation/modules/plains_boss_arena.tscn").instantiate()
	world.add_child(module)
	player=preload("res://scenes/player/player.tscn").instantiate();player.position=at;world.add_child(player)
	controller=player.get_node("Controller")
	life=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	boss=load("res://scenes/bosses/bellstrider.tscn" if mini else "res://scenes/bosses/windkeeper.tscn").instantiate()
	if not mini: (boss.get_node("Encounter") as BossEncounter).definition=preload("res://resources/bosses/windkeeper_storm.tres")
	boss.position=Vector2(560,535);world.add_child(boss)
	encounter=boss.get_node("Encounter");encounter.configure_arena(125,995,player)
	policy.bind_damageable(&"boss",boss.get_node("Damageable"),encounter.health)
	created.clear()
	armour_hits=0
	encounter.armour_hit.connect(func(_p: Vector2) -> void: armour_hits+=1)
	encounter.projectile_created.connect(func(shot: BossProjectile) -> void:
		created.append({"id":String(shot.event_id),"aim":shot.direction})
		shot.hit.connect(func(body: Node2D,event: StringName,amount: float) -> void:
			if body!=player: return
			var request:=DamageRequest.new();request.token=life.token();request.actor_epoch=life.actor_epoch
			request.health_epoch=controller.actor_resources.health.epoch;request.target_id=&"player";request.source_id=&"boss_fixture"
			request.event_id=event;request.amount=amount;policy.submit(request))
	)
	await frames(3)
	check(encounter.activate(),"actual redesigned Boss activates")
func run() -> void:
	await fixture(true)
	check(encounter is BellstriderEncounter and encounter.health.capacity==16,"mini is independent machine with sixteen HP")
	check(is_equal_approx((encounter.definition as WindkeeperDefinition).phase_two_health,.5),"mini HUD threshold matches actual half-health intensity")
	var boss_font: Font=preload("res://assets/fonts/windkeeper_ui.ttf")
	var supported:=boss_font.get_supported_chars()
	var new_text: String=(encounter.definition as WindkeeperDefinition).display_name+encounter.objective()
	var covered:=true
	for c: String in new_text:
		if c.unicode_at(0)>=128 and not supported.contains(c): covered=false
	check(covered,"shipped Boss font covers redesigned Chinese name and introduction")
	encounter._enter(&"observe",5)
	await frames(2)
	check(controller.shoot_ability.try_fire(boss.position+encounter.core_offset()-player.position,true),"ordinary shot reaches closed machine armour")
	await frames(25)
	check(armour_hits>0 and encounter.health.current==16,"closed machine blocks a real shot with armour feedback, without damage")
	encounter._enter(&"neck",2)
	await frames(2)
	var hp:=encounter.health.current
	check(controller.shoot_ability.try_fire(boss.position+encounter.core_offset()-player.position,true),"ordinary real shot aims at machine core")
	await frames(25)
	check(encounter.health.current==hp-1,"redesigned actual core accepts one real shot")
	var mini:=encounter as BellstriderEncounter
	mini.pattern_index=2;mini.locked_point=Vector2(350,582);mini.volley=1
	mini._enter(&"lob",.5)
	var data: Dictionary=JSON.parse_string(JSON.stringify(mini.combat_snapshot()))
	mini.pattern_index=0;mini.volley=0;mini.restore_combat_state(data)
	check(mini.pattern_index==2 and mini.volley==1 and mini.locked_point==Vector2(350,582),"JSON restoration retains attack order and committed landing")
	mini.cancel_pending_attacks()
	check(mini.mode==&"observe" and mini._projectiles.is_empty(),"return cancels obsolete bell attacks")
	await fixture(true,Vector2(390,582))
	encounter._enter(&"ring_warning",.01)
	await frames(90)
	check(controller.actor_resources.health.current<5,"real ring wave damages grounded target")
	await fixture(true,Vector2(390,582))
	encounter._enter(&"ring_warning",.01)
	controller.router.set_jump_held(&"ring_dodge",true)
	await frames(70)
	check(controller.actor_resources.health.current==5,"unchanged one held jump clears ring wave")
	check(controller.motor.tuning.max_jumps==1 and controller.motor.tuning.max_air_shots==2,"mini dodge preserves original action budget")
	await fixture(true)
	mini=encounter as BellstriderEncounter
	mini.direction=-1;mini._enter(&"roll_warning",.01)
	var dash_start:=boss.position.x
	var warned:=mini.roll_warning_distance()
	await frames(100)
	check(boss.position.x<400 and mini.mode==&"neck" and mini.core_open,"physical rolling dash travels then exposes core")
	check(absf((boss.get_node("Presentation") as BellstriderPresentation).wheel_angle)>1,"wheel animation follows actual movement")
	check(warned>=dash_start-boss.position.x+mini.definition.collision_size.x*.5,"roll lane warning covers real dash and contact front")
	boss.position.x=190
	check(is_equal_approx(boss.position.x-mini.roll_warning_distance(),mini.arena.left_x-mini.definition.collision_size.x*.5),"warning at arena edge stops at actual contact boundary")
	await fixture(true)
	mini=encounter as BellstriderEncounter
	mini.health.apply_damage(ActorResourceRequest.new(&"half",mini.health.epoch,8,mini.health.get_instance_id()))
	mini._enter(&"ring_warning",.01)
	await frames(58)
	check(mini.stage_phase==2 and created.size()==4,"half-health ring pattern adds a separately timed second pair")
	mini.cancel_pending_attacks()
	mini.locked_point=Vector2(350,582);mini._enter(&"lob_warning",.01)
	await frames(2)
	mini._prune_attacks()
	check(mini._projectiles.any(func(p: BossProjectile): return p is BellstriderBellProjectile),"lob is a real swept ballistic bell, not a placeholder marker")
	var bell: BellstriderBellProjectile
	for p: BossProjectile in mini._projectiles:
		if p is BellstriderBellProjectile: bell=p;break
	var vy:=bell.flight_velocity.y
	await frames(12)
	check(not is_instance_valid(bell) or bell.flight_velocity.y>vy,"bell trajectory genuinely curves under gravity")
	await fixture(false)
	check(encounter.health.capacity==36 and (encounter.definition as WindkeeperDefinition).storm_profile,"formal main Boss has thirty-six HP and enhanced profile")
	encounter.health.apply_damage(ActorResourceRequest.new(&"second",encounter.health.epoch,13,encounter.health.get_instance_id()))
	await frames(80)
	check(encounter.stage_phase==2,"main Boss uses actual second threshold")
	encounter._enter(&"blade_warning",.1)
	var locked:=encounter._locked_aim
	controller.router.set_move_axis(-1)
	await frames(10)
	controller.router.set_move_axis(0)
	check(encounter._locked_aim==locked and created.size()==3,"phaseII warning locks aim and emits three-angle fan without retarget")
	var saved:=encounter.combat_snapshot()
	encounter.restore_combat_state(saved)
	var count:=created.size();await frames(3)
	check(created.size()==count,"restoring an emitted fan does not duplicate attacks")
	encounter.cancel_pending_attacks()
	check(player._local_duration==0 and encounter._projectiles.is_empty(),"main cancellation clears current and fan consumers")
	encounter.health.apply_damage(ActorResourceRequest.new(&"third",encounter.health.epoch,11,encounter.health.get_instance_id()))
	await frames(2)
	check(encounter.stage_phase==3,"third threshold preserves separate broken-bridge stage")
	encounter._enter(&"pier_warning",.01)
	await frames(18)
	check(encounter.mode==&"pier_open" and created.size()>=count+3,"phaseIII impact opens core and emits different two-angle counter-fire")
	await fixture(true,Vector2(405,582))
	encounter._enter(&"neck",8)
	await frames(2)
	var pointer:=boss.global_position+encounter.core_offset()
	var adapter:=KeyboardMouseAdapter.new();adapter.aim_origin=player
	var aim:=adapter.world_direction(player.get_canvas_transform()*pointer)
	var muzzle: Vector2=(player.get_node("CourierVisual") as CourierVisual).muzzle_position(aim)
	check(absf((pointer-muzzle).cross(aim))<.3,"actual pointer and offset muzzle share one accurate world ray")
	hp=encounter.health.current
	check(controller.shoot_ability.try_fire(aim,true),"mouse-derived actual shot fires at nearby exposed core")
	var emitted:=controller.shoot_ability.get_projectiles()[0]
	check(absf((pointer-(emitted.global_position+emitted.launch_motion)).cross(emitted.direction))<.3,"accepted shot snapshots the same accurate muzzle ray before recoil pose events")
	await frames(2)
	var live:=controller.shoot_ability.get_projectiles()
	check(not live.is_empty() and live[0].trail.size()>=2 and live[0].z_index==8,"real projectile retains visible independent trail after barrel sweep")
	await frames(20)
	check(encounter.health.current==hp-1,"mouse-derived ray genuinely damages nearby bell without enlarging its core")
	adapter.free()
	await fixture(false)
	encounter.stage_phase=2
	check(not encounter.accepts_core_direction({"hit_direction":Vector2.RIGHT}),"formal phaseII side shot rejected by upper aperture")
	check(encounter.accepts_core_direction({"hit_direction":Vector2.DOWN}),"formal phaseII downward shot accepted")
	encounter.health.apply_damage(ActorResourceRequest.new(&"wind_fixture",encounter.health.epoch,13,encounter.health.get_instance_id()))
	encounter._enter(&"blades",2)
	await frames(3)
	check(player._local_velocity.x==-70 and player._local_duration>0,"real wind consumer supplies continuous left velocity in arena")
	encounter.cancel_pending_attacks()
	check(player._local_velocity==Vector2.ZERO,"retreat cancels spatial wind without altering Motor tuning")
	await fixture(false,Vector2(490,340))
	encounter.health.apply_damage(ActorResourceRequest.new(&"upper_fixture",encounter.health.epoch,13,encounter.health.get_instance_id()))
	encounter.stage_phase=2;encounter._enter(&"back",8)
	await frames(2)
	adapter=KeyboardMouseAdapter.new();adapter.aim_origin=player
	pointer=boss.global_position+encounter.core_offset()
	aim=adapter.world_direction(player.get_canvas_transform()*pointer)
	hp=encounter.health.current
	check(controller.shoot_ability.try_fire(aim,false),"ordinary airborne mouse shot fires downward at phaseII aperture")
	await frames(15)
	check(encounter.health.current==hp-1,"actual upper-side projectile damages phaseII core before platform collision")
	adapter.free()
	var background:=PlainsBackground.new();background.shared_environment_enabled=false;world.add_child(background)
	await frames(2)
	check(background.continuous_panorama and background.panels.size()==1 and background.panels[0].texture==PlainsBackground.PANORAMA,"formal background uses cohesive AI panorama with no stacked image baselines")
	world.free();await process_frame
	await check_current_formal_background()
	print("PLAINS PRESSURE BOSS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func check_current_formal_background() -> void:
	# Preserve the complete historical Boss/one-panorama regression above.
	# This additional fixture exercises the default consumer on a real formal map.
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	root.add_child(viewport)
	var app:=DemoApp.new()
	app.meta_persistence_enabled=false
	viewport.add_child(app)
	check(app.start_plains("pressure-background-current-domain"),"current background test starts actual formal DemoApp")
	await frames(10)
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok,"current background receives a real assembled formal Manifest")
	if not app.stage is PlainsRegionStage:
		viewport.free()
		return
	var stage:=app.stage as PlainsRegionStage
	var manifest_before:=JSON.stringify(stage.generated.manifest)
	var background:=app.get_node_or_null("PlainsBackground") as PlainsBackground
	check(background!=null and background.shared_environment_enabled and background.panels.size()==2,"untouched formal default creates independent sky and ridge")
	if background==null or background.panels.size()!=2:
		viewport.free()
		return
	check(background.panels[0].texture==PlainsBackground.TEXTURES[0] and background.panels[1].texture==PlainsBackground.RIDGE,"actual formal planes use original sky and admitted ridge sources")
	check(background.panels[0].material is ShaderMaterial and background.panels[1].material is ShaderMaterial and background.panels[0].material!=background.panels[1].material,"actual formal planes retain independent ShaderMaterial instances")
	var bounds:Array=stage.generated.manifest.world_bounds
	var expected:=Rect2(bounds[0]-180.0,bounds[1]-180.0,bounds[2]+360.0,bounds[3]+360.0)
	var domain:=background._shared_domain()
	check(domain==expected,"actual formal background camera domain follows this Manifest bounds and overscan collar")
	var center:=domain.get_center()
	for size:Vector2i in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(2560,720)]:
		viewport.size=size
		var middle:Array[Vector2]=[]
		var horizontal:Array[Vector2]=[]
		var vertical:Array[Vector2]=[]
		for location:Vector2 in [center,center+Vector2(1000,0),center+Vector2(0,1000),domain.position,Vector2(domain.end.x,domain.position.y),domain.end,Vector2(domain.position.x,domain.end.y)]:
			viewport.canvas_transform=Transform2D(0.0,Vector2(size)*0.5-location)
			background._update_panels()
			var positions:Array[Vector2]=[]
			for index:int in background.panels.size():
				var panel:=background.panels[index]
				var rect:=Rect2(panel.position,panel.texture.get_size()*panel.scale)
				positions.append(panel.position)
				check(panel.visible and not panel.centered and is_equal_approx(panel.scale.x,panel.scale.y),"actual formal layer keeps visible uniform source geometry")
				check(rect.position.x<=0 and rect.end.x>=size.x and rect.end.y>=size.y,"actual formal layer covers horizontal domain corners and lower screen in three aspect ratios")
				check(rect.position.y<=0 if index==0 else rect.position.y<=size.y*0.5,"actual formal sky covers upper screen and ridge source reaches horizon at vertical extremes")
			if location==center:middle=positions
			elif location==center+Vector2(1000,0):horizontal=positions
			elif location==center+Vector2(0,1000):vertical=positions
		check(horizontal[0].x<middle[0].x and horizontal[1].x<middle[1].x and absf(horizontal[1].x-middle[1].x)>3.0*absf(horizontal[0].x-middle[0].x),"actual formal sky and ridge respond differently to horizontal camera travel")
		check(vertical[0].y<middle[0].y and vertical[1].y<middle[1].y and absf(vertical[1].y-middle[1].y)>3.0*absf(vertical[0].y-middle[0].y),"actual formal sky and ridge respond differently to vertical camera travel")
		check(is_equal_approx(horizontal[0].y,middle[0].y) and is_equal_approx(horizontal[1].y,middle[1].y) and is_equal_approx(vertical[0].x,middle[0].x) and is_equal_approx(vertical[1].x,middle[1].x),"actual formal background keeps both camera axes independent")
	check(JSON.stringify(stage.generated.manifest)==manifest_before,"camera-domain checks preserve the complete actual gameplay Manifest")
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	viewport.free()
