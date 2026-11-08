extends Node2D
## Editable art review stage. Uses production renderers/rigs and actual terrain.
## Animation poses are an explicit gallery fixture, not combat evidence.
class BodyView extends Node2D:
	var rig: PlainsRevisionSkin
	var age := 0.0
	func _process(delta: float) -> void:
		age += delta
		queue_redraw()
	func _draw() -> void:
		var stage := fmod(age,12.0)
		var pose := {"clock":age,"stride":age*7.0,"travel":.35,"load":clampf((stage-3.0)/2.0,0,1) if stage<5 else 0.0,"strike":sin((stage-5)*PI) if stage>=5 and stage<6 else 0.0,"hurt":0.0,"death":clampf((stage-9.0)/2.0,0,1),"dead":stage>=9,"death_clock":maxf(0,stage-9),"air":false}
		rig.draw_pose(self,pose)
class DiverView extends Node2D:
	var frames := EnemyFeedback01Frames.new(&"underworld",&"plains_diver",Vector2(36,31))
	var age := 0.0
	func _process(delta: float) -> void:
		age+=delta;queue_redraw()
	func _draw() -> void:
		var stage := fmod(age,12.0)
		var index := 3 if stage<6 else int((stage-6)/.15)%4 if stage<7 else 3 if stage<9 else mini(7,4+int(stage-9))
		draw_texture_rect(frames.texture(index),frames.bounds(index),false)
class CartView extends BellstriderPresentation:
	var age := 0.0
	func _ready() -> void: texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _process(delta: float) -> void: age+=delta;queue_redraw()
	func _draw() -> void:
		var modes := [&"observe",&"roll_warning",&"roll",&"ring_warning",&"rings",&"dead"]
		var step := fmod(age,12.0)
		var pose := BellstriderRigPose.sample({"mode":modes[int(step/2)],"state_age":fmod(step,2),"state_duration":2.0,"fight_age":age,"travel":age*70,"speed":70.0,"death_age":maxf(0,step-10),"ring_strike_age":fmod(step,.6)})
		draw_set_transform_matrix(pose.mast_transform);_draw_mast(pose)
		draw_set_transform_matrix(pose.body_transform);_draw_suspension(pose);_draw_hull(pose)
		draw_set_transform_matrix(pose.launcher_transform);_draw_launcher(pose)
		_draw_wheel(pose.left_wheel,false);_draw_wheel(pose.right_wheel,true)
		draw_set_transform_matrix(pose.bell_transform);_draw_main_bell(pose)
		draw_set_transform_matrix(Transform2D.IDENTITY)
class KeeperView extends WindkeeperPressurePresentation:
	var age := 0.0
	func _ready() -> void: texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _process(delta: float) -> void: age+=delta;queue_redraw()
	func _draw() -> void:
		var modes := [&"observe",&"approach",&"stomp_warning",&"sweep_warning",&"gust",&"dead"]
		var step := fmod(age,12.0)
		var pose := WindkeeperPressureRig.sample({"mode":modes[int(step/2)],"state_age":fmod(step,2),"state_duration":2.0,"fight_age":age,"travel":age*60,"speed":60.0,"death_age":maxf(0,step-10),"phase":2})
		_draw_sails(pose,Color.WHITE)
		for i: int in [3,1]: _draw_leg(pose,i,Color.WHITE.darkened(.18))
		_draw_body(pose,Color.WHITE);_draw_folded_leaves(pose,Color.WHITE)
		for i: int in [2,0]: _draw_leg(pose,i,Color.WHITE)
		_draw_head(pose,Color.WHITE);_draw_core(pose,Color.WHITE);_draw_bells(pose,Color.WHITE)
		if pose.mode==&"sweep_warning": _draw_attack_leaf(pose,Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)

func label_at(value: String, at: Vector2, size: int = 12) -> void:
	var label := Label.new(); label.text=value;label.position=at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("e4dec2"))
	label.add_theme_color_override("font_outline_color",Color("162433"))
	label.add_theme_constant_override("outline_size",3)
	add_child(label)

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var camera := Camera2D.new();camera.position=Vector2(426.6667,240);camera.zoom=Vector2(1.5,1.5);add_child(camera)
	var background := UnderworldParallax.new();background.configure(camera,Rect2(),{"seed":"redraw-02"});add_child(background)
	var platforms: Array[Rect2]=[Rect2(20,158,812,32),Rect2(20,438,812,70)]
	add_child(UnderworldTerrain.build(platforms))
	label_at("风铃平原 · 怪物美术重绘",Vector2(28,17),24)
	label_at("正式地形 / 生产表现与关节 · 陈列动作预览（非战斗录像）",Vector2(30,49),12)
	var kinds: Array[StringName]=[&"patrol",&"charger",&"hopper",&"sentry",&"fan_sentry",&"root_bell"]
	var names := ["巡逻体","冲锋体","跃击体","单发哨兵","扇射哨兵","根铃"]
	for i: int in kinds.size():
		var view := BodyView.new();view.rig=PlainsRevisionSkin.new(kinds[i]);view.position=Vector2(76+i*110,158)
		var mat:=ShaderMaterial.new();mat.shader=preload("res://game/enemies/presentation/plains_revision_skin.gdshader");view.material=mat
		add_child(view);label_at(names[i],Vector2(50+i*110,175))
	var diver:=DiverView.new();diver.position=Vector2(744,139);add_child(diver);label_at("俯冲体",Vector2(721,175))
	var cart:=CartView.new();cart.position=Vector2(230,373);add_child(cart)
	var keeper:=KeeperView.new();keeper.position=Vector2(615,373);add_child(keeper)
	label_at("鸣铃巡游机",Vector2(186,452),15);label_at("牧风者",Vector2(587,452),15)
	# Actual player factory appearance as a shared scale reference (no gameplay).
	var player: PlayerMotor=preload("res://game/player/player.tscn").instantiate()
	player.position=Vector2(418,420);add_child(player)
	var controller:=player.get_node("Controller") as PlayerController
	player.get_node("CourierVisual").hide();player.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED;player.get_node("PlayerFeedback").hide()
	player.add_child(PlayerPresentationRuntime.make_body(player,controller,"ReferenceBody"))
	player.process_mode=Node.PROCESS_MODE_DISABLED
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): _capture(argument.trim_prefix("--capture="))

func _capture(path: String) -> void:
	for i: int in 45: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	if "--still" in OS.get_cmdline_user_args(): get_tree().quit()
