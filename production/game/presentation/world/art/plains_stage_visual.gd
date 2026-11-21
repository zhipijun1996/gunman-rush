class_name PlainsStageVisual
extends Node2D
## Cosmetic consumer only; collection and transitions remain stage/App owned.
var pixel_style := false
var stage: Node2D
var _time := 0.0
var _pickups: Array[Sprite2D] = []
var _pickup_by_id: Dictionary = {}
var _claimed_times:Dictionary={}
var _coin_parts:Dictionary={}
var _coin_history:Dictionary={}
var _coin_bounce:Dictionary={}
var _coin_flashes:Array[Dictionary]=[]
const LOOT_SHADER := preload("res://shaders/plains_loot_02.gdshader")
var _loot_material := ShaderMaterial.new()
const LIFE_ORB := preload("res://assets/plains_loot_02/life_orb.png")
func _init() -> void:
	# No per-pickup uniforms: texture and tint remain CanvasItem inputs.
	_loot_material.shader = LOOT_SHADER
func configure(source: Node2D) -> void:
	stage = source
func _ready() -> void:
	_sync_pickups()
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
				sprite.material=_loot_material
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
			_coin_history.erase(key);_coin_bounce.erase(key)
func _process(delta: float) -> void:
	if not is_instance_valid(stage):
		return
	_time += delta
	for flash:Dictionary in _coin_flashes:flash.age+=delta
	_coin_flashes=_coin_flashes.filter(func(row:Dictionary)->bool:return float(row.age)<.24)
	_sync_pickups()
	queue_redraw()
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
			var bounces:=int(data.get("loot_bounces",0))
			if _coin_bounce.has(data.id) and bounces>int(_coin_bounce[data.id]):
				if _coin_flashes.size()<24:_coin_flashes.append({"at":sprite.position,"age":0.0})
				if bounces==1:GameAudio.cue(self,&"coin_bounce")
			_coin_bounce[data.id]=bounces
			var history:Array=_coin_history.get(data.id,[])
			if history.is_empty() or (history[-1] as Vector2).distance_squared_to(sprite.position)>4:
				history.append(sprite.position)
				if history.size()>5:history.pop_front()
			_coin_history[data.id]=history
			var cluster:Dictionary=_coin_parts[data.id]
			var at:=sprite.position
			for part_index:int in cluster.sprites.size():
				var part:Sprite2D=cluster.sprites[part_index]
				var value:int=cluster.denominations[part_index]
				part.visible=sprite.visible
				part.position=at+Vector2((part_index-(cluster.sprites.size()-1)*.5)*9,0)
				part.rotation=0
				part.modulate=sprite.modulate
				var frames:SpriteFrames=PixelVfx.CLIPS[&"coin-turn"]
				var spin:=fposmod(_time*(1.2 if value==5 else 1.65)+index*.27+part_index*.2,1)
				part.texture=frames.get_frame_texture(&"default",mini(frames.get_frame_count(&"default")-1,floori(spin*frames.get_frame_count(&"default"))))
				part.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				part.scale=Vector2.ONE*(1.3 if value==5 else 1.0)

func _texture(kind: StringName) -> Texture2D:
	return UnderworldActors.icon_texture(kind)

func _draw() -> void:
	if not is_instance_valid(stage):return
	for index:int in _pickups.size():
		var data:Dictionary=stage.pickups[index]
		var sprite:=_pickups[index]
		if not sprite.visible:continue
		if data.kind=="coin":
			var history:Array=_coin_history.get(data.id,[])
			if history.size()>1 and (not bool(data.get("loot_settled",false)) or data.claimed):
				for i:int in range(1,history.size()):
					draw_line((history[i-1] as Vector2).round(),(history[i] as Vector2).round(),Color(1,.76,.25,float(i)/history.size()*.32),1,false)
		if data.claimed:
			var duration:=PlainsLootMotion.COLLECT_SECONDS if bool(data.get("loot_motion",false)) else .25
			var progress:=(_time-float(_claimed_times.get(data.id,-1000)))/duration
			PixelVfx.clip(self,&"collect",sprite.position,progress,0,Color(1,1,1,.8))
	for flash:Dictionary in _coin_flashes:
		PixelVfx.glint(self,flash.at,3,Color("ffe8a0"),1-float(flash.age)/.24)
