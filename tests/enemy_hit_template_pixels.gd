extends SceneTree
## Real GL body/cue isolation. Actors, AI clocks and contact particles are
## explicitly frozen/hidden after real accepted Damageable hits to isolate RGB.
## This is an isolated rendering fixture, not a naturally played Boss fight.
var checks := 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var world: Node2D
var view: SubViewport
const OUT := "res://build/enemy_hit_template/pixels/"

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)

func capture(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png(OUT+name+".png")
	return image

func delta_pixels(first: Image, second: Image, area: Rect2i) -> int:
	var changed := 0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			if first.get_pixel(x,y) != second.get_pixel(x,y): changed += 1
	return changed

func context(receiver: Damageable, id: String, at: Vector2) -> Dictionary:
	return {"event_id":id,"amount":1.0,"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"source_actor_id":-1,"source_faction":&"player","hit_point":at,"hit_direction":Vector2.DOWN}

func ordinary() -> void:
	var motor := (load("res://scenes/enemies/patrol_drone.tscn") as PackedScene).instantiate() as EnemyMotor
	var actor := motor.get_node("Actor") as EnemyActor
	actor.definition = load("res://resources/enemies/plains_sentry.tres") as EnemyDefinition
	motor.get_node("Presentation").free()
	var visual := UnderworldEnemy.new(); visual.name="Presentation"; visual.actor=actor
	var original_material := CanvasItemMaterial.new(); visual.material=original_material
	motor.add_child(visual); motor.position=Vector2(128,144); world.add_child(motor)
	actor.set_physics_process(false)
	actor.attack_behavior = EnemyAttackBehavior.new(); actor.add_child(actor.attack_behavior)
	actor.attack_behavior.state=&"telegraph"; actor.attack_behavior.locked_direction=Vector2.RIGHT
	visual.set_process(false); paused=true; visual.queue_redraw()
	var before := await capture("ordinary-before")
	check(actor.damageable.receive_damage(context(actor.damageable,"pixels/ordinary",motor.global_position)),"ordinary actual accepted hit")
	var hit := visual.hit_template
	hit.particles.visible=false
	visual.queue_redraw()
	var after := await capture("ordinary-after")
	var hp := Rect2i(120,144-int(actor.definition.collision_size.y*.5)-12,4,2)
	var cue := Rect2i(188,142,18,4)
	var body := Rect2i(100,112,56,54)
	var body_changes := delta_pixels(before,after,body)
	var hp_changes := delta_pixels(before,after,hp)
	var cue_changes := delta_pixels(before,after,cue)
	check(body_changes>20,"actual common body highlight/squash changes rendered sprite pixels")
	check(hp_changes==0,"surviving HP pip exact pixels retain their original color")
	check(cue_changes==0,"actual distant sentry aim cue exact pixels retain position and color")
	check(before.get_pixel(120,hp.position.y) != before.get_pixel(400,300),"HP preservation mask contains an actual rendered pip")
	check(visual.material==original_material,"existing host material stays identical through accepted hit")
	rows.append({"kind":"ordinary","body_changed":body_changes,"hp_changed":hp_changes,"world_cue_changed":cue_changes,"particles_hidden_for_body_ablation":true})
	paused=false; motor.queue_free(); await process_frame; await process_frame

func boss() -> void:
	var motor := (load("res://scenes/bosses/bellstrider.tscn") as PackedScene).instantiate() as BossMotor
	motor.position=Vector2(140,170); world.add_child(motor)
	var encounter := motor.get_node("Encounter") as BellstriderEncounter
	encounter.set_physics_process(false); encounter.active=true; encounter.core_open=true; encounter.mode=&"roll_warning"
	encounter.arena.configure(0,650,60)
	var visual := motor.get_node("Presentation") as BellstriderPresentation
	visual.set_process(false); paused=true; visual.queue_redraw()
	var before := await capture("boss-before")
	check((encounter.damageable as WindkeeperDamageable).receive_core(context(encounter.damageable,"pixels/boss",motor.global_position)),"Boss actual vulnerable receiver accepts hit")
	visual.hit_template.particles.visible=false; visual.queue_redraw()
	var after := await capture("boss-after")
	var body_changes := delta_pixels(before,after,Rect2i(60,79,160,157))
	var cue_changes := delta_pixels(before,after,Rect2i(270,212,80,12))
	var core := motor.position+encounter.core_offset()
	var ring_pixels := 0
	var ring_changes := 0
	for y: int in range(int(core.y)-22,int(core.y)+23):
		for x: int in range(int(core.x)-22,int(core.x)+23):
			if before.get_pixel(x,y).is_equal_approx(Color("ffe59b")):
				ring_pixels += 1
				if before.get_pixel(x,y)!=after.get_pixel(x,y):ring_changes += 1
	check(body_changes>20,"Boss real body pixels use common accepted-hit highlight")
	check(cue_changes==0,"Boss world-space roll warning exact pixels stay unchanged")
	check(ring_pixels>20 and ring_changes==0,"Boss opaque actual weakpoint ring pixels retain exact color and location")
	check(visual.hit_template.pose()==Vector2.ONE and visual.material==null,"Boss hit imposes no weakpoint/body transform or host material")
	rows.append({"kind":"boss","body_changed":body_changes,"world_cue_changed":cue_changes,"weakpoint_ring_pixels":ring_pixels,"weakpoint_ring_changed":ring_changes,"particles_hidden_for_body_ablation":true})
	paused=false; motor.queue_free(); await process_frame; await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	view=SubViewport.new();view.size=Vector2i(512,360);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	world=Node2D.new();world.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;world.set_meta("underworld_formal_style",true);view.add_child(world)
	var audio:=GameAudio.new();world.add_child(audio)
	await ordinary();await boss()
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"actual rendering fixture audio releases")
	view.queue_free();await process_frame;await process_frame
	var file:=FileAccess.open(OUT+"runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"scope":"actual GL body-only color isolation with clocks frozen and contact particles hidden; not device/player/battle approval"},"\t"));file.close()
	print("ENEMY HIT PIXELS: %s assertions, %s failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
