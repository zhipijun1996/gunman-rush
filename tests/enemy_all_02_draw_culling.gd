extends SceneTree
## Isolated culling/lifecycle fixtures, not combat or route video evidence.
## --verify-pixels adds real SubViewport GPU images; run with the root GL lease.
const BODY: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/beetle.png")
const BOUNDS := Rect2(-18,-12,36,24)
var checks := 0
var failures: Array[String] = []
var pixel_cases: Array[Dictionary] = []
var viewport: SubViewport
var world: Node2D
var actor: EnemyActor

class MeshProbe extends Node2D:
	var family := "forest"
	var actor: EnemyActor
	var forest := ForestMotion02.new()
	var plains := PlainsMotion02.new()
	var boss := BossMotionPresentation.new()
	func _draw() -> void:
		if family=="forest":
			var influences: Array[Dictionary] = [{"region":BOUNDS,"margin":Vector2(6,6),"pivot":Vector2.ZERO,"angle":0.10}]
			forest.set("_joints",influences)
			forest.call("_draw_connected",self,actor,BODY,BOUNDS,Transform2D.IDENTITY,Color.WHITE)
		elif family=="plains": plains.draw_body(self,actor,BODY,BOUNDS,Color.WHITE)
		else: boss.draw_body(self,BODY,BOUNDS,&"bellstrider",Color.WHITE)

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)
func ticks(count: int) -> void:
	for _index: int in count: await process_frame
func visible(family: String,canvas: Node2D,bounds := BOUNDS) -> bool:
	if family=="forest": return ForestMotion02.body_mesh_visible(canvas,bounds)
	if family=="plains": return PlainsMotion02.body_mesh_visible(canvas,bounds)
	return BossMotionPresentation.body_mesh_visible(canvas,bounds)

func geometry_and_skips() -> void:
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	for family: String in ["forest","plains","boss"]:
		var margin := 128.0 if family=="boss" else 64.0
		canvas.position = Vector2(160,90)
		check(visible(family,canvas),family+" center is retained")
		canvas.scale = Vector2(-1,1)
		check(visible(family,canvas),family+" mirrored center is retained")
		canvas.rotation = 0.37
		canvas.position = Vector2(-10,90)
		check(visible(family,canvas),family+" rotated mirrored edge is retained")
		canvas.rotation = 0.0;canvas.scale = Vector2.ONE
		canvas.position = Vector2(320+18+margin,90)
		check(visible(family,canvas),family+" exact conservative margin border is retained")
		canvas.position.x += 2.0
		check(not visible(family,canvas),family+" wholly outside padded viewport is culled")
		viewport.canvas_transform = Transform2D(0,Vector2(-2000,-700))
		canvas.position = Vector2(2160,790)
		check(visible(family,canvas),family+" camera canvas transform brings body into view")
		viewport.canvas_transform = Transform2D.IDENTITY
	canvas.position = Vector2(5000,5000)
	var forest := ForestMotion02.new()
	forest.tension = 0.7
	forest.set("_last_body_pose",Vector2(.94,1.06))
	forest.call("_draw_connected",canvas,actor,BODY,BOUNDS,Transform2D.IDENTITY,Color.WHITE)
	check((forest.get("_mesh") as ArrayMesh).get_surface_count()==0 and forest.tension==0.7 and forest.get("_last_body_pose")==Vector2(.94,1.06),"forest cull skips only prepare/vertices and retains sampled pose")
	var plains := PlainsMotion02.new()
	plains.draw_body(canvas,actor,BODY,BOUNDS,Color.WHITE)
	check(int(plains.get("_epoch"))==actor.health.epoch and plains.get("_source")==null,"plains synchronizes epoch before skipping prepare")
	var boss := BossMotionPresentation.new()
	boss.draw_body(canvas,BODY,BOUNDS,&"bellstrider",Color.WHITE)
	check((boss.get("_meshes") as Dictionary).is_empty() and canvas.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"boss keeps nearest assignment then skips cache/vertices")
	# Forest regions' farthest authored pivot-to-corner radius is <39wu.
	# Normalized rotation deltas <=2r, gain=.35, accepted pose <=1.1 and
	# fixed-foot translation+body mirror asymmetry <4wu => <35wu total.
	check(2.0*39.0*ForestMotion02.MOTION_GAIN*1.1+4.0<64.0,"forest full rotation/accepted-hit envelope is inside 64wu padding")
	# Largest current Boss body is 184x236wu. Arm/forearm have disjoint
	# left/right weights; crown can overlap arms only below uv.y=.24.
	var arm := 2.0*Vector2(.27*184,.42*236).length()*sin(.42*.5)
	var forearm := 2.0*Vector2(.35*184,.26*236).length()*sin(.42*.65*.5)
	var crown_overlap := .14*236*.38
	var other := 6.0+3.0+184*.035+236*.08
	check(arm+forearm+crown_overlap+other<128.0 and .38*236*.38+other<128.0,"Boss compound limb/crown/leg/death envelope is inside 128wu padding")
	canvas.queue_free()

func lifecycle_offscreen() -> void:
	var host := actor.motor.get_node("Presentation") as ForestEnemyPresentation
	var motion := host.motion
	actor.motor.position = Vector2(5000,5000)
	actor.attack_behavior = EnemyAttackBehavior.new()
	actor.attack_behavior.state = &"telegraph"
	actor.add_child(actor.attack_behavior)
	var context := {"event_id":"culling/real-hit","amount":1.0,"source_faction":&"player","source_actor_id":-1,"target_actor_id":actor.damageable.actor_id,"target_epoch":actor.damageable.damage_epoch,"hit_point":actor.motor.global_position,"hit_direction":Vector2.RIGHT}
	check(actor.damageable.receive_damage(context),"offscreen real Damageable accepts fixture hit")
	var sample := host.hit_template.sample
	var hurt_before := sample.hurt_remaining
	var clock_before := motion.clock
	await ticks(8)
	check(motion.clock>clock_before and motion.tension>0.0,"offscreen host clock/current telegraph pose continue")
	check(sample.hurt_remaining<hurt_before and sample.accepted_hit_count==1,"offscreen original accepted hurt continues without replay")
	paused = true
	motion.tension = 1.0
	actor.brain.direction = -1
	check(actor.restore_instance_health(actor.health.capacity),"offscreen actual paused initialize succeeds")
	check(motion.clock==0.0 and motion.tension==0.0 and float(motion.get("_facing"))==-1.0,"offscreen paused epoch synchronizes immediately")
	paused = false
	actor.set_physics_process(false)
	actor.motor.position = Vector2(100,70)
	check(ForestMotion02.body_mesh_visible(host,ForestBibleActors.ECOLOGY_BODIES[&"forest_lantern"].bounds),"return to viewport is retained without cached visibility debt")

func pixels() -> void:
	for family: String in ["forest","plains","boss"]:
		var probe := MeshProbe.new()
		probe.family = family;probe.actor = actor
		viewport.add_child(probe)
		for entry: Dictionary in [{"id":"center","point":Vector2(160,90),"flip":false},{"id":"left-edge","point":Vector2(-10,90),"flip":false},{"id":"right-edge","point":Vector2(330,90),"flip":false},{"id":"mirrored","point":Vector2(160,90),"flip":true},{"id":"outside","point":Vector2(5000,90),"flip":false}]:
			probe.position = entry.point
			probe.scale = Vector2(-1,1) if entry.flip else Vector2.ONE
			probe.queue_redraw()
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var count := 0
			for y: int in image.get_height():
				for x: int in image.get_width():
					if image.get_pixel(x,y).a>16.0/255.0: count += 1
			check(count==0 if entry.id=="outside" else count>0,family+" GPU "+str(entry.id)+" retains expected visible pixels")
			var path := "res://build/enemy_all_02/draw-culling/%s-%s.png" % [family,entry.id]
			image.save_png(path)
			pixel_cases.append({"family":family,"case":entry.id,"nontransparent_pixels":count,"path":path})
		probe.queue_free()
		await ticks(2)

func run() -> void:
	world = Node2D.new()
	world.set_meta(ForestBibleActors.METADATA,true)
	root.add_child(world)
	var motor := preload("res://scenes/enemies/forest_lantern.tscn").instantiate() as EnemyMotor
	world.add_child(motor)
	actor = motor.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	viewport = SubViewport.new();viewport.size = Vector2i(320,180)
	viewport.transparent_bg = true;viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	geometry_and_skips()
	await lifecycle_offscreen()
	DirAccess.make_dir_recursive_absolute("res://build/enemy_all_02/draw-culling")
	if "--verify-pixels" in OS.get_cmdline_user_args(): await pixels()
	world.queue_free();viewport.queue_free()
	await ticks(2)
	var file := FileAccess.open("res://build/enemy_all_02/draw-culling/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"body mesh culling fixtures; no AI/combat budget changes","checks":checks,"failures":failures,"gpu_cases":pixel_cases},"\t"));file.close()
	print("ENEMY ALL 02 DRAW CULLING: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
