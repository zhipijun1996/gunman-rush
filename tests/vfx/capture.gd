extends SceneTree
## Native drawing snapshots of actual consumers; not a gameplay/quest proof.
var page := "combat"
var output := "res://build/vfx/native"
var movie := false
var leaves: Array[Node2D] = []
var elapsed := 0.0
var backdrop: Board

class Board extends Node2D:
	var labels: Array[String] = []
	func _draw() -> void:
		for i: int in 16:
			var at:=Vector2((i%4)*320,(i/4)*180)
			var bright:=i>=8
			draw_rect(Rect2(at,Vector2(320,180)),Color("b4c2ad") if bright else Color("152028"))
			draw_line(at+Vector2(0,150),at+Vector2(320,150),Color("89967d") if bright else Color("39413a"),1)
			draw_string(ThemeDB.fallback_font,at+Vector2(12,22),labels[i%8]+(" / sky" if bright else " / dark"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("27372f") if bright else Color("dfd5b4"))
			draw_rect(Rect2(at,Vector2(320,180)),Color("59665a"),false,1)

class IceSnapshot extends Node2D:
	var age:=0.0
	var flight:=false
	func _draw() -> void:
		if flight: IceCastVisual.projectile(self,Vector2.RIGHT,age,[])
		else: IceCastVisual.burst(self,Vector2.ZERO,Vector2.RIGHT,age,true)

class BlastSnapshot extends PlayerWeaponVfxV2:
	var snapshot_age:=0.0
	var collapse:=false
	func _ready() -> void: set_process(false)
	func _draw() -> void:
		var fx:={"start":global_position,"age":snapshot_age,"radius":64.0}
		if collapse: _draw_collapse(fx)
		else: _draw_explosion(fx)

class FocusSnapshot extends WorldFocusHeal:
	func _exit_tree() -> void: pass # Drawing snapshot has no controller ownership.
	func _ready() -> void:
		set_process(false);set_physics_process(false)

class BossSnapshot extends Node2D:
	var age:=0.0
	var wind:=false
	func _draw() -> void: PlainsBossEffects.paint(self,&"wind" if wind else &"bell",2,age/.32)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):page=arg.trim_prefix("--page=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--movie":movie=true
	run.call_deferred()

func make_leaf(index: int) -> Node2D:
	if page=="combat":
		match index:
			0,1:
				var leaf:=UnderworldProjectileVisual.new();leaf.impact=index==1;return leaf
			2,3:
				var leaf:=IceSnapshot.new();leaf.flight=index==3;return leaf
			4,5:
				var leaf:=BlastSnapshot.new();leaf.collapse=index==5;return leaf
			_:
				var leaf:=EnemyFeedback01Particles.new()
				var health:=HealthState.new();health.configure(HealthDefinition.new())
				leaf.sample=EnemyFeedback01.new(health)
				leaf._epoch=leaf.sample.epoch()
				if index==7:leaf._material_family=&"shell"
				return leaf
	elif page=="world":
		match index:
			0,1:
				var leaf:=FocusSnapshot.new()
				leaf.settings=JSON.parse_string(FileAccess.get_file_as_string("res://config/world/player.json")).focus_heal
				return leaf
			2:return WorldChargingStation.new()
			3:return WorldRecoilGuardVisual.new()
			4,5:
				var leaf:=WorldDamageSequence.new();leaf.kind="death" if index==5 else "hit";leaf.active=true;return leaf
			_:
				var leaf:=BossSnapshot.new();leaf.wind=index==6;return leaf
	else:
		var leaf:=ItemEffectView.new();leaf._settings=leaf._read_settings();return leaf

func update_leaves(t: float) -> void:
	for i: int in leaves.size():
		var leaf:=leaves[i];var index:=i%8
		if page=="combat":
			if leaf is UnderworldProjectileVisual:leaf.age=fposmod(t,.8)
			elif leaf is IceSnapshot:leaf.age=fposmod(t,.8)
			elif leaf is BlastSnapshot:leaf.snapshot_age=fposmod(t,1.0)
			else:
				leaf._bursts.assign([{"point":leaf.global_position,"direction":Vector2.RIGHT,"age":fposmod(t,.8),"lethal":false,"serial":1,"hold_remaining":0.0}])
		elif page=="world":
			if leaf is FocusSnapshot:
				leaf.elapsed=fposmod(t,1.0) if index==0 else 0.0
				leaf.flash=0.0 if index==0 else maxf(0,float(leaf.settings.presentation.release_seconds)-fposmod(t,1.0))
			elif leaf is WorldChargingStation:leaf.charge=.8;leaf.age=t;leaf.success=maxf(0,1-fposmod(t,1))
			elif leaf is WorldRecoilGuardVisual:
				leaf.protecting=true;leaf.glow=1.0;leaf.trail.assign([leaf.global_position,leaf.global_position-Vector2(8,2),leaf.global_position-Vector2(16,3),leaf.global_position-Vector2(24,3)])
			elif leaf is WorldDamageSequence:leaf.impact=leaf.global_position;leaf.age=fposmod(t,1.3)
			else:leaf.age=fposmod(t,.8)
		else:
			var kinds: Array[StringName]=[&"arc",&"cloud",&"ring",&"mark",&"item_blast",&"coin",&"barrier",&"heal"]
			leaf._entries.assign([{"kind":kinds[index],"origin":&"", "point":leaf.global_position,"finish":leaf.global_position+Vector2(50,-12),"age":fposmod(t,1),"duration":1.0,"radius":32.0,"sequence":1,"evolution":1,"amount":1,"magnet_bonus":true,"direction":Vector2.RIGHT}])
		leaf.queue_redraw()

func run() -> void:
	root.size=Vector2i(1280,720)
	backdrop=Board.new()
	backdrop.labels.assign(["muzzle","contact","ice shatter","ice flight","blast","collapse","accepted hit","shell chips"] if page=="combat" else ["resonance gather","resonance release","charge station","recoil guard","player hit","player death","wind impact","bell impact"] if page=="world" else ["item arc","cloud","ring","mark","item blast","coin","barrier","heal"])
	root.add_child(backdrop)
	for i:int in 16:
		var leaf:=make_leaf(i%8)
		leaf.position=Vector2((i%4)*320+160,(i/4)*180+105)
		if leaf is WorldChargingStation:leaf.position.y+=35
		root.add_child(leaf);leaf.set_process(false);leaf.set_physics_process(false)
		leaves.append(leaf)
	DirAccess.make_dir_recursive_absolute(output)
	for frame: int in (120 if movie else 4):
		var t:float=float(frame)/60 if movie else float([0.0,.033,.10,.22][frame])
		update_leaves(t)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+page+"-%03d.png"%frame)
	for leaf:Node2D in leaves:
		if leaf is EnemyFeedback01Particles:leaf.sample.dispose()
		leaf.free()
	backdrop.free()
	print("VFX NATIVE CAPTURE: ",page," -> ",output)
	quit()
