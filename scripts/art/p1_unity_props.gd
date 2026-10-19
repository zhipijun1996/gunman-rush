extends Node2D
## Explicit P1 ordinary-stage cosmetic adapter. Original objects retain all logic.
var _stage: Node
var _atlas: Texture2D
var _parts: Dictionary
var _chests: Dictionary = {}
var _notes: Dictionary = {}
var _latches: Array[Dictionary] = []
var _facts: Dictionary = {"scope":"actual chest/shot-latch bell/permanent-note presentations only","collision_changed":false,"state_or_reward_writes":false,"chests":0,"note_wind_icons":0,"shot_latches":0,"uncovered":["coin and heart retain original distinct reward art","diver and other non-RootBell enemies retain original readable art","thorn/pennant candidates rejected; not consumed","no RechargePoint exists in ordinary Plains consumer; no fake recharge interaction"]}
var _old_bell_size := Vector2.ZERO

func install(stage: Node) -> void:
	_stage=stage
	process_priority=40
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://resources/visual_development/p1_unity_components.json"))
	if not raw is Dictionary:return
	_parts=raw.components
	_atlas=load(str(raw.texture)) as Texture2D
	_facts["loaded_texture"]=str(raw.texture)
	_facts["loaded_texture_sha256"]=FileAccess.get_sha256(str(raw.texture))
	_facts["loaded_texture_size"]=[_atlas.get_width(),_atlas.get_height()]
	_facts["actual_regions"]={"chest":_parts.chest.region,"chime":_parts.chime.region,"wind":_parts.wind.region}
	_facts["display_rect_world"]={"chest":[62.4,45.6],"chime":[175.0*52.0/385.0,52],"note_wind":[20,270.0*20.0/260.0]}
	_facts["chest_foot_rule"]="original fallback foot=c.position+(0,18); claimed alpha and rarity tint remain native"
	var old := load("res://assets/plains_v3/windchime_switch.png") as Texture2D
	_old_bell_size=old.get_size()
	_facts["retired_bell_texture"]={"source":"res://assets/plains_v3/windchime_switch.png","dimensions":[old.get_width(),old.get_height()],"scope":"only this old texture draw; native gate labels/sigils/accepted feedback preserved; native pixels pending"}
	for chest: Dictionary in _stage.get("chests"):
		var sprite := chest.get("sprite") as Sprite2D
		if sprite==null:continue
		_chests[sprite.get_instance_id()]={"node":sprite,"texture":sprite.texture,"scale":sprite.scale,"position":sprite.position,"offset":sprite.offset,"centered":sprite.centered}
		var spec: Dictionary=_parts.chest
		sprite.texture=_texture("chest");sprite.centered=false
		sprite.offset=-Vector2(spec.pivot[0],spec.pivot[1]);sprite.scale=Vector2.ONE*.24
		sprite.position=chest.position+Vector2(0,18) # Original fallback chest's standing foot.
	_facts.chests=_chests.size()
	var enemies: Array=[]
	for body: Node in _stage.get("enemies"):
		var actor := body.get_node_or_null("Actor")
		if actor!=null:enemies.append({"node":str(body.get_path()),"definition":actor.get("definition").resource_path,"presentation":"existing P1 RootBell where available; other species unchanged, not restyled by props"})
	_facts["actual_enemy_consumers"]=enemies
	_process(0)

func _texture(id: String) -> AtlasTexture:
	var rect: Array=_parts[id].region
	var result := AtlasTexture.new()
	result.atlas=_atlas;result.region=Rect2(rect[0],rect[1],rect[2],rect[3]);result.filter_clip=true
	return result

func _install_latch(latch: Node2D) -> void:
	# Retire only the old bell's texture commands. Native gates, text, warning
	# marks, connection sigils and accepted-event effects keep their drawing.
	# Exact measured source sizes distinguish bell1141x1379 from gate837x1879.
	var shader := Shader.new()
	shader.code="shader_type canvas_item; uniform vec2 retired_texel; void fragment(){if(all(lessThan(abs(TEXTURE_PIXEL_SIZE-retired_texel),vec2(0.0000001)))){discard;}}"
	var material := ShaderMaterial.new();material.shader=shader
	material.set_shader_parameter("retired_texel",Vector2.ONE/_old_bell_size)
	var row := {"node":latch,"material":latch.material,"bells":[]}
	latch.material=material
	var points: Array[Vector2]=[latch.get("bell_position")]
	var second: Vector2=latch.get("sequence_offset")
	if not second.is_zero_approx():points.append(points[0]+second)
	for point: Vector2 in points:
		var sprite := Sprite2D.new()
		var spec: Dictionary=_parts.chime
		sprite.texture=_texture("chime");sprite.centered=false
		sprite.offset=-Vector2(spec.pivot[0],spec.pivot[1]);sprite.scale=Vector2.ONE*(52.0/385.0)
		sprite.position=point;sprite.name="P1ActualShotBell";latch.add_child(sprite)
		row.bells.append({"node":sprite,"point":point})
	_latches.append(row)
	_facts.shot_latches=_latches.size()

func _process(_delta: float) -> void:
	if not is_instance_valid(_stage) or _atlas==null:return
	# setup_shot_latches occurs after ordinary presentation install, so discover
	# actual new objects instead of inventing a separate switch or gate.
	for latch: Node2D in _stage.get("shot_latches"):
		var known := false
		for row: Dictionary in _latches:
			if row.node==latch:known=true;break
		if not known:_install_latch(latch)
	for row: Dictionary in _latches:
		var latch: Node2D=row.node
		if not is_instance_valid(latch):continue
		var opened_at := float(latch.get("_opened_at"))
		var age := float(latch.get("_clock"))-opened_at if opened_at>=0 else 1.0
		for index: int in row.bells.size():
			var sprite: Sprite2D=row.bells[index].node
			sprite.rotation=sin(age*28)*.16*maxf(0,1-age/.5) if bool(latch.get("is_open")) else 0.0
			sprite.modulate=Color.WHITE if index==0 or int(latch.get("sequence_step"))==1 else Color(.55,.55,.55)
	var visual := _stage.get("visual_layer") as Node
	if visual==null:return
	var actual: Dictionary=visual.get("_pickup_by_id")
	for pickup: Dictionary in _stage.get("pickups"):
		if str(pickup.kind)!="note":continue
		var id := str(pickup.id)
		var sprite := actual.get(id) as Sprite2D
		if sprite==null:continue
		if not _notes.has(id):
			_notes[id]={"node":sprite,"texture":sprite.texture,"centered":sprite.centered,"offset":sprite.offset,"scale":sprite.scale}
			sprite.texture=_texture("wind");sprite.centered=false
			sprite.offset=-Vector2(_parts.wind.pivot[0],_parts.wind.pivot[1])
		# Preserve native bob/arrival/claim alpha; only keep the new round source
		# at a uniform scale after the original visual's size update.
		sprite.scale=Vector2.ONE*(20.0/260.0)
	_facts.note_wind_icons=_notes.size()
	var coverage: Dictionary=_stage.get_meta("p1_random_coverage",{})
	coverage["props"]=_facts # The actual late-created consumers remain live in the capture receipt.
	_stage.set_meta("p1_random_coverage",coverage)

func measured_nodes() -> Dictionary:
	var result := _facts.duplicate(true)
	result["bell_source_size"]= [_old_bell_size.x,_old_bell_size.y]
	result["bell_retirement_scope"]="only old1141x1379texture commands; native gate/labels/sigils unchanged; GPU verification pending"
	return result

func _exit_tree() -> void:
	for row: Dictionary in _latches:
		if is_instance_valid(row.node):row.node.material=row.material
		for bell: Dictionary in row.bells:
			if is_instance_valid(bell.node):bell.node.hide();bell.node.queue_free()
	for row: Dictionary in _chests.values():
		if not is_instance_valid(row.node):continue
		row.node.texture=row.texture;row.node.scale=row.scale;row.node.position=row.position;row.node.offset=row.offset;row.node.centered=row.centered
	for row: Dictionary in _notes.values():
		if not is_instance_valid(row.node):continue
		row.node.texture=row.texture;row.node.offset=row.offset;row.node.centered=row.centered;row.node.scale=row.scale
