class_name WorldCoinDrops
extends Node2D
## Fixed-world adapter for existing PlainsLootMotion and PlainsStageVisual.
## Services own entitlement/money; this node only moves, displays and requests collection.
signal pickup_requested(id: String)
var services: WorldServices
var controller: PlayerController
var room_id: String
var arena_bounds:=Rect2()
var clock:=0.0
var pickups: Array[Dictionary]=[]
var exit_positions: Array[Vector2]=[]
var stage_type:=&"fixed_world"
var _revision:=-1
var _by_id: Dictionary={}
var _births:Array[Dictionary]=[]
var _sources:Dictionary={}
func _ready() -> void:
	set_meta(&"underworld_formal_style",true)
	z_index=2
	var visual:=PlainsStageVisual.new();visual.configure(self);add_child(visual)
func global_player_position() -> Vector2: return controller.motor.global_position
func sync() -> void:
	if _revision==services.state.revision: return
	var restoring:=_revision<0
	_revision=services.state.revision
	var drops: Dictionary=services.ledger().get("drops",{})
	for id: String in drops:
		var record: Dictionary=drops[id]
		if record.room!=room_id or _by_id.has(id): continue
		var unit:=PlainsLootMotion.restore(record,clock)
		_by_id[id]=unit;pickups.append(unit)
		var source:=str(unit.source)
		if not _sources.has(source):
			_sources[source]=true
			if not restoring and float(unit.loot_age)<.06 and source.begins_with("enemy:"):
				if _births.size()<12:_births.append({"at":unit.position,"age":0.0})
				GameAudio.cue(self,&"loot_scatter")
	for id: String in _by_id:
		var unit: Dictionary=_by_id[id]
		if not drops.has(id) and not unit.claimed:
			unit.claimed=true;unit.claimed_at=clock;unit.claimed_position=unit.position
func _physics_process(delta: float) -> void:
	clock+=delta;sync()
	for birth:Dictionary in _births:birth.age+=delta
	_births=_births.filter(func(row:Dictionary)->bool:return float(row.age)<.38)
	queue_redraw()
	for unit: Dictionary in pickups:
		if not unit.claimed and arena_bounds.has_area() and str(unit.source).begins_with("boss:") and not arena_bounds.has_point(unit.position): unit.loot_returning=true
		PlainsLootMotion.advance(unit,delta,self)
		if can_collect(str(unit.id)): pickup_requested.emit(str(unit.id))
	for i: int in range(pickups.size()-1,-1,-1):
		var unit: Dictionary=pickups[i]
		if unit.claimed and clock-float(unit.get("claimed_at",clock))>PlainsLootMotion.COLLECT_SECONDS+.1:
			_by_id.erase(str(unit.id));pickups.remove_at(i)
func can_collect(id: String) -> bool:
	if not _by_id.has(id): return false
	var unit: Dictionary=_by_id[id]
	if unit.claimed or clock<float(unit.ready_at) or controller.actor_resources.health.terminal: return false
	if controller.motor.position.distance_to(unit.position)>=float(services.definitions.coin_pickup_radius): return false
	var ray:=PhysicsRayQueryParameters2D.create(global_player_position(),to_global(unit.position),1)
	ray.collide_with_areas=false
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func persist_into(candidate: Dictionary) -> void:
	if not candidate.services.has("drops"): return
	for unit: Dictionary in pickups:
		var id:=str(unit.id)
		if unit.claimed or not candidate.services.drops.has(id): continue
		var row:=PlainsLootMotion.snapshot(unit);row.room=room_id
		candidate.services.drops[id]=row
static func create_units(source: String,amount: int,origin: Vector2,safe: Vector2,room: String) -> Array[Dictionary]:
	# Keep the current world's approved trial payout while using the existing service,
	# denominations, independent presentation stream, scatter and durable unit format.
	var service:=EnemyDropService.new()
	service.configure("fixed-world",room,{"version":1,"weights":{"coin":1,"heart":0,"note":0,"none":0},"amounts":{"coin":amount,"heart":1,"note":1}})
	var result: Array[Dictionary]=[]
	for unit: Dictionary in PlainsLootMotion.units(service.settle(StringName(source)),source,origin,safe,0):
		var record:=PlainsLootMotion.snapshot(unit);record.room=room;result.append(record)
	return result

func _draw() -> void:
	for birth:Dictionary in _births:
		PixelVfx.clip(self,&"loot-spill",birth.at,float(birth.age)/.38)

func _exit_tree() -> void:
	GameAudio.stop_origin(self,false)
