class_name VisualLanguageSample
extends Node2D
## Explicit visual-language candidate. All simulation remains in the original stage.
var _stage: PlainsRegionStage
var _design: Dictionary
var _catalog: Dictionary
var _atlas: Texture2D
var _app: DemoApp
var _hero: PaintedHero
var _old_background: CanvasLayer
var _wind: Array[Dictionary] = []
var _reeds: Array[Dictionary] = []
var _event_receipts: Array[Dictionary] = []
var _distant: Array[Dictionary] = []
var _clock := 0.0
var _last_anchor: StringName = &""
var _coverage: Dictionary = {}
var _ui_restore: Array[Dictionary] = []

func configure(source: PlainsRegionStage, design: Dictionary) -> void:
	_stage = source
	_design = design

func _ready() -> void:
	var catalog_path := str(_stage.get_meta("visual_language_sample_path", ""))
	if catalog_path.is_empty() or not FileAccess.file_exists(catalog_path):
		push_error("Visual language candidate catalog missing: "+catalog_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not parsed is Dictionary:
		push_error("Visual language candidate catalog is invalid")
		return
	_catalog = parsed
	_atlas = _texture(str(_catalog.get("atlas", "")))
	_app = _stage.get_parent() as DemoApp
	if _design.get("presentation_scope","")=="formal_second_space":
		_coverage={"catalog_path":catalog_path,"catalog_sha256":FileAccess.get_sha256(catalog_path),"hero_states":[],"root_body":false,"saw":false,"scope":"existing B actor and UI presentation on unchanged formal stage; no candidate placements or golden geometry"}
		_install_hero();_install_enemy_and_saw();_style_ui()
		_bind_accepted_events.call_deferred()
		return
	_coverage = {"catalog_path":catalog_path,"catalog_sha256":FileAccess.get_sha256(catalog_path),"hero_states":[],"root_body":false,"root_warning_and_burst":"original","saw":false,"input_geometry_contract_sha256":_design.contract_sha256,"derived_manifest_hash":_stage.generated.manifest.manifest_hash,"layout_variant":_design.get("layout_variant","original"),"actual_solid_count":_design.solid_polygons.size(),"hud_scope":"Palette only; original functional controls and layout"}
	_background()
	_terrain()
	for entry: Dictionary in _catalog.get("placements", []): _place(entry)
	_install_hero()
	_install_enemy_and_saw()
	_style_ui()
	_bind_accepted_events.call_deferred()
	print("VISUAL LANGUAGE SAMPLE: ",JSON.stringify(_coverage))

func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

func _region(entry: Dictionary, fallback: Texture2D = null) -> Texture2D:
	var source := _texture(str(entry.get("texture", "")))
	if source == null: source = fallback
	if source == null: return null
	if not entry.has("region"): return source
	var a: Array = entry.region
	var result := AtlasTexture.new()
	result.atlas=source;result.region=Rect2(a[0],a[1],a[2],a[3]);result.filter_clip=true
	return result

func _background() -> void:
	_old_background = _app.get_node_or_null("PlainsBackground") as CanvasLayer
	if _old_background != null: _old_background.hide()
	var layer := CanvasLayer.new()
	layer.layer=-95
	add_child(layer)
	var color := ColorRect.new()
	color.color=Color(str(_catalog.get("sky_color", "a9c1bc")))
	color.size=Vector2(1280,720);color.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(color)
	for entry: Dictionary in _catalog.get("background_layers", []):
		var sprite := Sprite2D.new()
		sprite.texture=_region(entry,_atlas)
		if sprite.texture == null: continue
		sprite.centered=false
		var pivot: Array=entry.get("pivot",[0,0])
		sprite.offset=-Vector2(pivot[0],pivot[1])
		sprite.z_as_relative=false;sprite.z_index=int(entry.get("layer",-50))
		sprite.scale=Vector2.ONE*float(entry.get("scale",1.0))
		sprite.modulate.a=clampf(float(entry.get("opacity",1.0)),0.0,1.0)
		add_child(sprite)
		var a: Array=entry.position
		_distant.append({"node":sprite,"anchor":Vector2(a[0],a[1]),"parallax":float(entry.get("parallax",1.0))})

func _terrain() -> void:
	var grammar: Dictionary=_catalog.get("terrain",{}).get("grammar",{})
	if not grammar.is_empty():
		var script := load("res://scripts/art/painted_terrain_grammar.gd") as Script
		var painted: Node2D=script.new()
		painted.call("configure",_design,grammar)
		add_child(painted)
		_coverage["painted_terrain_grammar"]=painted.call("measured_nodes")
		return
	var specification: Dictionary = _catalog.get("terrain", {})
	_coverage["terrain_missing"]=specification.get("missing",[])
	var texture := _texture(str(specification.get("texture", "")))
	if texture == null:
		push_error("Visual language terrain texture missing; no placeholder accepted")
		return
	for row: Dictionary in _design.solid_polygons:
		var polygon := Polygon2D.new()
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for p: Array in row.points:
			var point := Vector2(p[0],p[1])
			points.append(point);uv.append(point*float(specification.get("pixels_per_world_unit",1.0)))
		polygon.polygon=points;polygon.uv=uv;polygon.texture=texture
		polygon.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		polygon.color=Color(str(specification.get("tint","ffffff")))
		polygon.z_as_relative=false;polygon.z_index=-2 if row.material=="chalk" else -7
		polygon.name="CandidateSolid_"+str(row.id)
		add_child(polygon)
	# Painted boundary pieces follow the actual top contour. Native source pixels
	# retain one scale; only the final repeated strip segment is cropped.
	var lip: Dictionary=specification.get("lip",{})
	if lip.is_empty():
		_coverage["terrain_missing_painted_lip"]=true
		return
	for row: Dictionary in _design.top_polylines:
		var raw: Array=row.points
		var first := Vector2(raw[0][0],raw[0][1])
		var second := Vector2(raw[1][0],raw[1][1])
		var last := Vector2(raw[-1][0],raw[-1][1])
		var penultimate := Vector2(raw[-2][0],raw[-2][1])
		var left_inset := _terrain_cap(specification.get("left_cap",{}),first,second-first)
		var right_inset := _terrain_cap(specification.get("right_cap",{}),last,last-penultimate)
		for index: int in raw.size()-1:
			var a := Vector2(raw[index][0],raw[index][1])
			var b := Vector2(raw[index+1][0],raw[index+1][1])
			var direction := (b-a).normalized()
			if index==0:a+=direction*left_inset
			if index==raw.size()-2:b-=direction*right_inset
			if (b-a).dot(direction)<=0:continue
			var edge := PaintedEdge.new()
			edge.texture=_texture(str(lip.texture));edge.specification=lip
			edge.length=a.distance_to(b);edge.position=a;edge.rotation=direction.angle()
			edge.z_as_relative=false;edge.z_index=0
			add_child(edge)

func _terrain_cap(cap: Dictionary, at: Vector2, tangent: Vector2) -> float:
	if cap.is_empty() or not cap.has("outer_standing_anchor") or not cap.has("inner_socket"):return 0.0
	# These finite caps were painted horizontal. Do not rotate a whole bank end
	# into an unpainted corner; the sloped world boundary remains unsupported.
	if absf(tangent.normalized().y)>.01:return 0.0
	var texture := _region(cap)
	if texture==null:return 0.0
	var sprite := Sprite2D.new()
	sprite.texture=texture;sprite.centered=false
	var outer: Array=cap.outer_standing_anchor
	var inner: Array=cap.inner_socket
	sprite.offset=-Vector2(outer[0],outer[1]);sprite.position=at
	sprite.scale=Vector2.ONE*float(cap.scale)
	sprite.z_as_relative=false;sprite.z_index=1
	add_child(sprite)
	_coverage["cap_outer_edge_calibration"]="unverified source-pixel candidate; actual screen review required"
	return absf(float(outer[0])-float(inner[0]))*float(cap.scale)

func _place(entry: Dictionary) -> void:
	var component: Dictionary = _catalog.get("components",{}).get(str(entry.component),{})
	var texture := _region(component,_atlas)
	if texture == null:
		push_error("Visual language component missing: "+str(entry.component));return
	var sprite := Sprite2D.new()
	sprite.texture=texture;sprite.centered=false
	var pivot: Array=component.get("pivot",[0,0])
	sprite.offset=-Vector2(pivot[0],pivot[1])
	var at: Array=entry.position
	sprite.position=Vector2(at[0],at[1]);sprite.scale=Vector2.ONE*float(entry.get("scale",1.0))
	sprite.rotation=float(entry.get("rotation",0.0));sprite.z_as_relative=false;sprite.z_index=int(entry.get("layer",0))
	add_child(sprite)
	if str(entry.get("motion",""))=="cloth": _wind.append({"node":sprite,"rest":sprite.rotation,"phase":sprite.position.x*.01,"angle":0.0,"velocity":0.0})
	if str(entry.get("motion",""))=="reed": _reeds.append({"node":sprite,"rest":sprite.rotation,"angle":0.0,"velocity":0.0})

func _install_hero() -> void:
	var specification: Dictionary = _catalog.get("hero", {})
	var texture := _texture(str(specification.get("texture", "")))
	if texture == null or not specification.has("states"):
		push_error("Visual language hero animation asset missing");return
	var visual := _app.player.get_node("CourierVisual") as CourierVisual
	_hero=PaintedHero.new();_hero.visual=visual;_hero.catalog=specification;_hero.texture=texture
	_hero.position=visual.position
	_app.player.add_child(_hero)
	visual.hide() # Its original state adapter and muzzle transforms still run.
	_coverage.hero_states=specification.states.keys()
	var missing: Array[String] = []
	for state: StringName in CourierVisual.STATES:
		if not specification.states.has(str(state)): missing.append(str(state))
	_coverage.hero_missing_states=missing

func _install_enemy_and_saw() -> void:
	var root: Dictionary = _catalog.get("root_bell", {})
	var texture := _texture(str(root.get("texture", "")))
	for body: Node2D in _stage.enemies:
		var presentation := body.get_node_or_null("Presentation") as RootBellPresentation
		if presentation != null and texture != null and root.has("frames"):
			presentation.set("_atlas",texture)
			presentation.set("_manifest",root)
			_coverage.root_body=true
	var saw: Dictionary=_catalog.get("saw",{})
	if saw.is_empty():return
	var saw_texture := _region(saw,_atlas)
	if saw_texture == null: return
	for module: PlatformingModule in _stage.assembler.modules:
		for hazard: ModuleSawHazard in module.hazards:
			var sprite := Sprite2D.new()
			sprite.texture=saw_texture
			sprite.scale=Vector2.ONE*(hazard.definition.radius*2.0/maxf(saw_texture.get_width(),saw_texture.get_height()))
			hazard.add_child(sprite)
			hazard.self_modulate.a=0.0 # Only its old drawing; physics and child stay active.
			_coverage.saw=true
			_coverage["saw_source"]=saw.get("texture",_catalog.get("atlas",""))
			_coverage["saw_actual_radius"]=hazard.definition.radius

func _style_ui() -> void:
	var palette: Dictionary = _catalog.get("ui", {})
	if palette.is_empty(): return
	_ui_restore.append({"node":_app._hud_frame,"kind":"style","key":"panel","value":_app._hud_frame.get_theme_stylebox("panel")})
	var panel := _app._hud_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel.bg_color=Color(str(palette.get("panel","263b36")))
	panel.border_color=Color(str(palette.get("border","a8ad83")))
	if palette.has("corner_radius"):panel.set_corner_radius_all(int(palette.corner_radius))
	if palette.has("border_width"):panel.set_border_width_all(int(palette.border_width))
	_app._hud_frame.add_theme_stylebox_override("panel",panel)
	var labels: Array[Node]=[]
	if bool(palette.get("recursive_labels",false)):labels.assign(_app._canvas.find_children("*","Label",true,false))
	else:labels.assign(_app._canvas.get_children())
	for node: Node in labels:
		if node is Label:
			_ui_restore.append({"node":node,"kind":"color","key":"font_color","value":(node as Label).get_theme_color("font_color")})
			(node as Label).add_theme_color_override("font_color",Color(str(palette.get("ink","f0ead4"))))
			if palette.has("shadow"):
				_ui_restore.append({"node":node,"kind":"color","key":"font_shadow_color","value":(node as Label).get_theme_color("font_shadow_color")})
				(node as Label).add_theme_color_override("font_shadow_color",Color(str(palette.shadow)))
	for row: Array in [[_app._resources_hud.health_bar,"health"],[_app._resources_hud.stamina_bar,"energy"],[_app._resources_hud.combat_bar,"combat"]]:
		var bar := row[0] as ProgressBar
		if bar == null or not palette.has(row[1]): continue
		_ui_restore.append({"node":bar,"kind":"style","key":"fill","value":bar.get_theme_stylebox("fill")})
		var fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill.bg_color=Color(str(palette.get(row[1],"c7ab65")))
		bar.add_theme_stylebox_override("fill",fill)
		if palette.has("track"):
			_ui_restore.append({"node":bar,"kind":"style","key":"background","value":bar.get_theme_stylebox("background")})
			var track := bar.get_theme_stylebox("background").duplicate() as StyleBoxFlat
			track.bg_color=Color(str(palette.track));track.border_color=Color(str(palette.get("track_border",palette.get("border","a8ad83"))))
			bar.add_theme_stylebox_override("background",track)
	if palette.has("button_panel"):
		for button: Button in [_app._pause_button,_app._debug_button]:
			if button==null:continue
			for key: String in ["normal","hover","pressed"]:
				var original := button.get_theme_stylebox(key)
				_ui_restore.append({"node":button,"kind":"style","key":key,"value":original})
				var style := original.duplicate() as StyleBoxFlat
				if style==null:style=StyleBoxFlat.new()
				style.bg_color=Color(str(palette.get("button_"+key,palette.button_panel)))
				style.border_color=Color(str(palette.get("button_border",palette.get("border","a8ad83"))))
				style.set_border_width_all(int(palette.get("border_width",1)));style.set_corner_radius_all(int(palette.get("corner_radius",2)))
				button.add_theme_stylebox_override(key,style)
			for key: String in ["font_color","font_hover_color","font_pressed_color"]:
				_ui_restore.append({"node":button,"kind":"color","key":key,"value":button.get_theme_color(key)})
				button.add_theme_color_override(key,Color(str(palette.get("ink","37413e"))))

func _bind_accepted_events() -> void:
	if not is_inside_tree() or not is_instance_valid(_app.controller):return
	_app.controller.shoot_ability.shot_fired.connect(_accepted_shot)
	for body: Node2D in _stage.enemies:
		var actor := body.get_node("Actor") as EnemyActor
		if actor.attack_behavior is RootBellBehavior:
			(actor.attack_behavior as RootBellBehavior).pulse_committed.connect(_accepted_pulse)

func _accepted_shot(_direction: Vector2, shot_id: int) -> void:
	if not is_inside_tree():return
	_react("accepted_shot",str(shot_id),_app.player.global_position,.55)

func _accepted_pulse(event_id: StringName, at: Vector2) -> void:
	if not is_inside_tree():return
	_react("committed_root_pulse",str(event_id),at,1.4)

func _react(kind: String, event_id: String, at: Vector2, impulse: float) -> void:
	_event_receipts.append({"kind":kind,"id":event_id,"time":_clock,"position":[at.x,at.y]})
	if _event_receipts.size()>16:_event_receipts.pop_front()
	for row: Dictionary in _reeds:
		var node := row.node as Sprite2D
		row.velocity=float(row.velocity)+impulse*clampf(1.0-node.global_position.distance_to(at)/650.0,0,1)

func _observe_anchor_receipt() -> void:
	var binding: Dictionary = _catalog.get("anchor_device",{})
	if binding.is_empty() or _app.segment==null or _app.segment._history.is_empty():return
	# This history is only written by the original strict activate_anchor().
	# Distance alone never drives this visual/audio acceptance.
	var activated: StringName = _app.segment._history.back()
	if activated==_last_anchor:return
	_last_anchor=activated
	if activated!=StringName(binding.anchor_id):return
	var at: Vector2 = _app.segment._anchors[activated]
	_react("accepted_safe_anchor",str(activated),at,.9)
	GameAudio.cue(self,&"confirm")
	_coverage["automatic_checkpoint_activated"]=str(activated)

func _process(delta: float) -> void:
	if get_tree().paused:return
	_clock+=delta
	_observe_anchor_receipt()
	for row: Dictionary in _wind:
		var target_angle := sin(_clock*.9+float(row.phase))*.018-.012
		row.velocity=float(row.velocity)+((target_angle-float(row.angle))*14.0-float(row.velocity)*5.0)*delta
		row.angle=float(row.angle)+float(row.velocity)*delta
		(row.node as Sprite2D).rotation=float(row.rest)+float(row.angle)
	for row: Dictionary in _reeds:
		row.velocity=float(row.velocity)+(-80.0*float(row.angle)-9.0*float(row.velocity))*delta
		row.angle=clampf(float(row.angle)+float(row.velocity)*delta,-.10,.10)
		(row.node as Sprite2D).rotation=float(row.rest)+float(row.angle)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		for row: Dictionary in _distant: (row.node as Sprite2D).position=Vector2(row.anchor)*float(row.parallax)+camera.global_position*(1.0-float(row.parallax))

func _exit_tree() -> void:
	if is_instance_valid(_app) and is_instance_valid(_app.controller) and _app.controller.shoot_ability.shot_fired.is_connected(_accepted_shot):
		_app.controller.shoot_ability.shot_fired.disconnect(_accepted_shot)
	for row: Dictionary in _ui_restore:
		if not is_instance_valid(row.node):continue
		if row.kind=="style":(row.node as Control).add_theme_stylebox_override(row.key,row.value)
		else:(row.node as Control).add_theme_color_override(row.key,row.value)
	if is_instance_valid(_hero):
		if is_instance_valid(_hero.visual):_hero.visual.show()
		_hero.queue_free()
	if is_instance_valid(_old_background):_old_background.show()

func measured_nodes() -> Dictionary:
	var result := _coverage.duplicate(true)
	result["accepted_event_receipts"]=_event_receipts.duplicate(true)
	if is_instance_valid(_hero):result["observed_hero_states"]=_hero.observed_states.duplicate(true)
	return result

class PaintedHero extends Node2D:
	var visual: CourierVisual
	var catalog: Dictionary
	var texture: Texture2D
	var gun: Sprite2D
	var observed_states: Dictionary = {}
	var painted_gun: AtlasTexture
	func _ready() -> void:
		process_priority=20
		gun=Sprite2D.new();gun.centered=false;add_child(gun)
		if catalog.has("weapon"):
			var region: Array=catalog.weapon.region
			var weapon_texture := texture
			var weapon_path := str(catalog.weapon.get("texture",""))
			if not weapon_path.is_empty():
				weapon_texture=load(weapon_path) as Texture2D if ResourceLoader.exists(weapon_path) else null
				if weapon_texture==null:
					push_error("Visual language independent weapon source missing: "+weapon_path)
					return
			painted_gun=AtlasTexture.new();painted_gun.atlas=weapon_texture
			painted_gun.region=Rect2(region[0],region[1],region[2],region[3]);painted_gun.filter_clip=true
	func _process(_delta: float) -> void:
		if not is_instance_valid(visual):return
		observed_states[str(visual.state)]=int(observed_states.get(str(visual.state),0))+1
		modulate=visual.modulate
		gun.texture=visual.arm.texture;gun.offset=visual.arm.offset
		gun.global_transform=visual.arm.global_transform
		if painted_gun!=null:
			var muzzle: Array=catalog.weapon.muzzle
			var base: Array=catalog.weapon.barrel_base
			var source_length := Vector2(float(muzzle[0])-float(base[0]),float(muzzle[1])-float(base[1])).length()
			var at := visual.visible_muzzle_position()
			var factor := at.distance_to(visual.arm.global_position)/maxf(1.0,source_length)
			gun.texture=painted_gun;gun.offset=-Vector2(muzzle[0],muzzle[1])
			gun.global_transform=Transform2D(visual.arm.global_rotation,Vector2(factor,factor*signf(visual.arm.scale.y)),0.0,at)
		gun.visible=visual.arm.visible
		queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(visual):return
		var states: Dictionary=catalog.states
		var animation: Dictionary=states.get(str(visual.state),states.get("idle",{}))
		var frames: Array=animation.get("frames",[])
		if frames.is_empty():return
		var index := int(visual.elapsed*float(animation.get("fps",8.0)))
		index=index%frames.size() if bool(animation.get("loop",false)) else mini(index,frames.size()-1)
		var frame: Dictionary=frames[index]
		var region: Array=frame.region
		var pivot: Array=frame.pivot
		var factor := float(catalog.get("uniform_scale",float(catalog.get("display_height",40.0))/float(catalog.get("reference_height",region[3]))))
		var squash := Vector2(1.0+visual.landing_pose*.07,1.0-visual.landing_pose*.07)
		draw_set_transform(Vector2.ZERO,0.0,Vector2(visual.facing,1)*squash)
		draw_texture_rect_region(texture,Rect2(-Vector2(pivot[0],pivot[1])*factor,Vector2(region[2],region[3])*factor),Rect2(region[0],region[1],region[2],region[3]))
		draw_set_transform(Vector2.ZERO)


class PaintedEdge extends Node2D:
	var texture: Texture2D
	var specification: Dictionary
	var length := 0.0
	func _draw() -> void:
		if texture==null:return
		var region: Array=specification.region
		var sockets: Array=specification.usable_x
		var factor := float(specification.scale)
		var source_width := float(sockets[1])-float(sockets[0])
		if factor<=0.0 or source_width<=0.0:return
		var advance := 0.0
		while advance<length-.001:
			var slice_width := minf(source_width,(length-advance)/factor)
			var source := Rect2(float(region[0])+float(sockets[0]),float(region[1]),slice_width,float(region[3]))
			var destination := Rect2(advance,-float(specification.surface_y)*factor,slice_width*factor,float(region[3])*factor)
			draw_texture_rect_region(texture,destination,source)
			advance+=slice_width*factor
