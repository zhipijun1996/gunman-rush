class_name PlainsStageVisual
extends Node2D
## Cosmetic consumer only; collection and transitions remain stage/App owned.
var pixel_style := false
var stage: Node2D
var _time := 0.0
var _pickups: Array[Sprite2D] = []
var _pickup_by_id: Dictionary = {}
var _doors: Array[Sprite2D] = []
var _boss_door: Sprite2D
var _claimed_times:Dictionary={}
var _coin_parts:Dictionary={}
const LOOT_SHADER := preload("res://shaders/plains_loot_02.gdshader")
const LIFE_ORB := preload("res://assets/plains_loot_02/life_orb.png")
var _boss_loot:Sprite2D
var _boss_origin:=Vector2.ZERO
var _boss_born:=-1.0
func configure(source: Node2D) -> void:
	stage = source
func _ready() -> void:
	_sync_pickups()
	for location: Vector2 in stage.exit_positions:
		_doors.append(_make_door(location))
	if stage.stage_type == &"boss":
		_boss_door = _make_door(stage.reward_position)
func _pickup_size(kind: String) -> Vector2:
	if kind == "coin":
		return Vector2(16, 16)
	if kind == "heart":
		return Vector2(27, 27)
	return Vector2(14, 21)
func _sync_pickups() -> void:
	# Drops can arrive after ready. Stable IDs retain their sprite when the
	# consumer reorders or removes entries; presentation never claims a reward.
	var live_ids: Dictionary = {}
	_pickups.clear()
	for index: int in stage.pickups.size():
		var pickup: Dictionary = stage.pickups[index]
		var key := str(pickup.get("id", "initial_%s" % index))
		live_ids[key] = true
		if not _pickup_by_id.has(key):
			var sprite := Sprite2D.new()
			if pickup.kind == "heart" and pickup.get("loot_motion",false):
				var atlas := AtlasTexture.new()
				atlas.atlas=LIFE_ORB
				atlas.region=Rect2(285,236,701,740)
				sprite.texture=atlas
			else: sprite.texture = _texture(StringName(pickup.kind))
			if pickup.get("loot_motion",false):
				var shader_material:=ShaderMaterial.new()
				shader_material.shader=LOOT_SHADER
				sprite.material=shader_material
				sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = _pickup_size(pickup.kind) / sprite.texture.get_size()
			sprite.set_meta("initially_claimed",bool(pickup.claimed))
			add_child(sprite)
			_pickup_by_id[key] = sprite
			if pickup.kind=="coin":
				var parts:Array[Sprite2D]=[sprite]
				var values:Array[int]=[]
				# The pre-existing visual-only preview contract omits a value.
				# Its single icon cannot grant money; real App pickups own amounts.
				var visual_amount:=int(pickup.get("amount",1))
				for _i:int in visual_amount/5:values.append(5)
				for _i:int in visual_amount%5:values.append(1)
				for part_index:int in maxi(0,values.size()-1):
					var extra:=Sprite2D.new()
					extra.texture=sprite.texture
					extra.material=sprite.material
					extra.texture_filter=sprite.texture_filter
					add_child(extra);parts.append(extra)
				_coin_parts[key]={"sprites":parts,"denominations":values}
		_pickups.append(_pickup_by_id[key])
	for key: String in _pickup_by_id.keys():
		if not live_ids.has(key):
			if _coin_parts.has(key):
				for part:Sprite2D in _coin_parts[key].sprites:
					if part!=_pickup_by_id[key]:part.queue_free()
				_coin_parts.erase(key)
			(_pickup_by_id[key] as Sprite2D).queue_free()
			_pickup_by_id.erase(key)
func _make_door(location: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _texture(&"door")
	sprite.scale = Vector2(60, 80) / sprite.texture.get_size()
	sprite.position = location + Vector2(0, -22)
	add_child(sprite)
	return sprite
func _process(delta: float) -> void:
	if not is_instance_valid(stage):
		return
	_time += delta
	_sync_pickups()
	for index: int in _pickups.size():
		var data: Dictionary = stage.pickups[index]
		var sprite := _pickups[index]
		var dynamic:bool=bool(data.get("loot_motion",false))
		var collect_seconds:=PlainsLootMotion.COLLECT_SECONDS if dynamic else .25
		if data.claimed and not _claimed_times.has(data.id):_claimed_times[data.id]=_time if not bool(sprite.get_meta("initially_claimed",false)) else -1000.0
		var collecting:bool=data.claimed and _time-float(_claimed_times.get(data.id,0))<collect_seconds
		sprite.visible=not data.claimed or collecting
		sprite.modulate=Color.WHITE
		sprite.position=data.position if dynamic else data.position+Vector2(0,sin(_time*2.8+index*.73)*2)
		sprite.rotation=float(data.get("loot_rotation",0.0)) if dynamic else 0.0
		var size:=_pickup_size(data.kind)
		if data.kind=="heart":
			if dynamic:size=Vector2(18,19.001427)
			var phase:=_time*3.2+index*.73
			var pulse:=1.0+.055*pow(maxf(0.0,sin(phase)),4.0)+.02*pow(maxf(0.0,sin(phase+.65)),8.0)
			sprite.scale=size/sprite.texture.get_size()*pulse
			if not dynamic:sprite.position=data.position+Vector2(0,sin(_time*2.4+index)*3)
		elif data.kind=="note":
			sprite.scale=size/sprite.texture.get_size()
			if not dynamic:sprite.rotation=sin(_time*2+index)*.10
		if not dynamic and not data.claimed and data.has("spawn_origin"):
			var age:float=stage.clock-float(data.born_at)
			if age<.65:sprite.position=PlainsCohesionArt.arrival(data.spawn_origin,data.position,age,.65)
		if collecting:
			var player_world:Vector2=stage.global_player_position() if stage.has_method("global_player_position") else stage.to_global(data.position-Vector2(0,40))
			var target:Vector2=stage.to_local(player_world)
			var age:float=_time-float(_claimed_times[data.id])
			var start:Vector2=data.get("claimed_position",data.position)
			var progress:=clampf(age/collect_seconds,0.0,1.0)
			sprite.position=start.lerp(target,1.0-pow(1.0-progress,3.0))
			sprite.modulate.a=1.0-progress*.6
			if data.kind!="coin":sprite.scale*=1.0-progress*.65
		if data.kind=="coin":
			var cluster:Dictionary=_coin_parts[data.id]
			var at:=sprite.position
			for part_index:int in cluster.sprites.size():
				var part:Sprite2D=cluster.sprites[part_index]
				var value:int=cluster.denominations[part_index]
				part.visible=sprite.visible
				part.position=at+Vector2((part_index-(cluster.sprites.size()-1)*.5)*9,0)
				part.rotation=sprite.rotation
				part.modulate=sprite.modulate
				var width:=24.0 if value==5 else 16.0
				var spin:=.42+.58*absf(cos(_time*(3.2 if value==5 else 4.6)+index+part_index))
				part.scale=Vector2(width*spin,width)/part.texture.get_size()
	if is_instance_valid(_boss_loot):
		_boss_loot.visible=stage.reward_available and _pressure_rewards_visible()
		_boss_loot.position=PlainsCohesionArt.arrival(_boss_origin,stage.reward_position-Vector2(0,16),stage.clock-_boss_born,.85)+Vector2(0,sin(_time*3)*3)
		_boss_loot.rotation=sin(_time*2)*.06
	for door: Sprite2D in _doors:
		door.modulate = Color(1, 1, 1, 1) if stage.completed else Color(0.63, 0.67, 0.60, 1)
	if is_instance_valid(_boss_door):
		_boss_door.visible = stage.reward_available and _pressure_rewards_visible()
		_boss_door.position = stage.reward_position + Vector2(0, -22)

func play_boss_defeat(origin:Vector2,mini:bool,animate:bool=true)->void:
	# Bellstrider's articulated failure and persistent wreck own its death art.
	# Other Bosses retain the existing generic burst and reward presentation.
	var mechanical_remains := mini and is_instance_valid(stage.boss) and stage.boss.get_node_or_null("Encounter") is BellstriderEncounter
	if animate and not mechanical_remains:
		var burst:=DefeatBurst.new();burst.mini=mini;burst.set_meta("pixel_style",pixel_style);burst.position=origin;stage.add_child(burst)
	if mechanical_remains: return # Physical coins are the actual map1 reward.
	if is_instance_valid(_boss_loot):return
	_boss_origin=origin;_boss_born=stage.clock if animate else stage.clock-.85
	_boss_loot=Sprite2D.new();_boss_loot.texture=UnderworldActors.icon_texture(&"chest") if UnderworldActors.enabled(self) else PixelFormalActors.icon_texture(&"chest") if pixel_style else PlainsV3Assets.texture("objects.json","chest")
	_boss_loot.scale=Vector2(38,32)/_boss_loot.texture.get_size();_boss_loot.modulate=Color("ffe7a0");add_child(_boss_loot)

func _texture(kind: StringName) -> Texture2D:
	return UnderworldActors.icon_texture(kind) if UnderworldActors.enabled(self) else PixelFormalActors.icon_texture(kind) if pixel_style else PlainsRefreshAssets.object_texture(kind)

func set_pixel_style(enabled: bool) -> void:
	pixel_style = enabled
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if enabled else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	for index: int in _pickups.size():
		var kind := StringName(stage.pickups[index].kind)
		if kind == &"heart" and stage.pickups[index].get("loot_motion",false): continue
		_pickups[index].texture = _texture(kind)
		_pickups[index].scale = _pickup_size(str(kind)) / _pickups[index].texture.get_size()
		if kind == &"coin" and _coin_parts.has(stage.pickups[index].id):
			for part: Sprite2D in _coin_parts[stage.pickups[index].id].sprites:
				part.texture = _pickups[index].texture
	for door: Sprite2D in _doors:
		door.texture = _texture(&"door")
		door.scale = Vector2(60,80) / door.texture.get_size()
	if is_instance_valid(_boss_door):
		_boss_door.texture = _texture(&"door")
		_boss_door.scale = Vector2(60,80) / _boss_door.texture.get_size()
	if is_instance_valid(_boss_loot):
		_boss_loot.texture=UnderworldActors.icon_texture(&"chest") if UnderworldActors.enabled(self) else PixelFormalActors.icon_texture(&"chest") if pixel_style else PlainsV3Assets.texture("objects.json","chest")
		_boss_loot.scale=Vector2(38,32)/_boss_loot.texture.get_size()


func _pressure_rewards_visible() -> bool:
	if not is_instance_valid(stage.boss): return true
	var encounter := stage.boss.get_node("Encounter") as WindkeeperPressureEncounter
	if encounter == null or not encounter.health.terminal: return true
	if not encounter.physical_reward_expected: return stage.clock >= stage.reward_ready_at
	return stage.clock >= stage.reward_ready_at and float(encounter.combat_metrics().get("death_age", 0)) >= (encounter.definition as WindkeeperPressureDefinition).death_seconds
