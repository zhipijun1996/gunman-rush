class_name WindkeeperPressureWind
extends Node
## Local visual consumer of the exact accepted gust. Never moves an actor,
## or changes authored environmental placement.
@export var encounter: WindkeeperPressureEncounter
const MAX_SCENERY := 32
const TIP_ENVELOPE := 2.8 # Bounded tip displacement; each painted root stays fixed.
var _stage: Node
var _grass: Dictionary = {}
var _grass_owned: Dictionary = {}
var _ever_grass: Dictionary = {}
var _max_root_error := 0.0
var _active := false

func _ready() -> void:
	process_priority = 2100
	if encounter == null: return
	_stage = encounter.motor.get_parent()
	_inventory(get_tree().root)
	get_tree().node_added.connect(_observe)
	encounter.presentation_event.connect(_event)

func _inventory(node: Node) -> void:
	_observe(node)
	for child: Node in node.get_children(): _inventory(child)

func _observe(node: Node) -> void:
	# Renderer-owned name/root metadata identifies planted grass without
	# importing the legacy generated-stage coordinator into the formal game.
	if node is Sprite2D and node.get_parent() is Node2D:
		if _grass.size() >= MAX_SCENERY or not is_instance_valid(_stage): return
		if not _stage.is_ancestor_of(node): return
		if not str(node.name).begins_with("Underworld_grass"): return
		if not node.has_meta("grounded_render_root"): return
		# Spend the bounded cache on this encounter's surroundings, rather than
		# the first thirty-two grass clumps near the map entrance.
		var legacy_arena: Variant = _stage.get("boss_arena")
		if legacy_arena is Rect2:
			var root_world := (node.get_parent() as Node2D).to_global(node.get_meta("grounded_render_root"))
			var reach := (encounter.definition as WindkeeperPressureDefinition).wind_pressure_range
			var bounds: Rect2 = (_stage as Node2D).global_transform * (legacy_arena as Rect2).grow(reach)
			if not bounds.has_point(root_world): return
		_grass[node.get_instance_id()] = weakref(node)

func _event(row: Dictionary) -> void:
	if row.get("event",&"") in [&"windkeeper_death",&"windkeeper_audio_cancel"]:
		_clear()

func _gust_live() -> bool:
	return is_instance_valid(encounter) and encounter.active and not encounter.health.terminal and encounter.mode == &"gust"

func _inside(point: Vector2) -> bool:
	var delta := point-encounter.motor.global_position
	var config := encounter.definition as WindkeeperPressureDefinition
	return delta.x*encounter.locked_direction >= -35 and absf(delta.x) <= config.wind_pressure_range and delta.y > -config.wind_pressure_height and delta.y < 100

func _process(_delta: float) -> void:
	if not _gust_live():
		_clear()
		return
	_active = true
	var touched_grass: Dictionary = {}
	for id: int in _grass.keys():
		var sprite := (_grass[id] as WeakRef).get_ref() as Sprite2D
		if not is_instance_valid(sprite):
			_grass.erase(id)
			continue
		var root_parent: Vector2 = sprite.get_meta("grounded_render_root")
		var parent := sprite.get_parent() as Node2D
		var root_world := parent.to_global(root_parent)
		if not _inside(root_world): continue
		if not _grass_owned.has(id):
			var initial_transform := sprite.transform
			var initial_attachment := initial_transform.affine_inverse()*root_parent
			_grass_owned[id] = {"sprite":weakref(sprite),"base":initial_transform,"attachment":initial_attachment,"root_world":root_world}
			_ever_grass[id] = true
		var saved: Dictionary = _grass_owned[id]
		var base: Transform2D = saved.base
		var attachment: Vector2 = saved.attachment
		var height_world := maxf(1,sprite.texture.get_height()*base.y.length())
		var shear := float(encounter.locked_direction)*minf(.28,TIP_ENVELOPE/height_world)
		var bend := Transform2D(Vector2(1,0),Vector2(-shear,1),Vector2(shear*attachment.y,0))
		sprite.transform = base*bend
		var actual_root := parent.to_global(sprite.transform*attachment)
		_max_root_error = maxf(_max_root_error,actual_root.distance_to(saved.root_world))
		touched_grass[id] = true
	for id: int in _grass_owned.keys():
		if not touched_grass.has(id): _restore_grass(id)

func _restore_grass(id: int) -> void:
	var saved: Dictionary = _grass_owned[id]
	var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
	if is_instance_valid(sprite): sprite.transform = saved.base
	_grass_owned.erase(id)

func _clear() -> void:
	for id: int in _grass_owned.keys(): _restore_grass(id)
	_active = false

func receipt() -> Dictionary:
	var scenery: Array[Dictionary] = []
	for id: int in _grass_owned:
		var saved: Dictionary = _grass_owned[id]
		var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
		if not is_instance_valid(sprite): continue
		var root := (sprite.get_parent() as Node2D).to_global(sprite.transform*(saved.attachment as Vector2))
		scenery.append({"instance_id":id,"name":str(sprite.name),"visible":sprite.is_visible_in_tree(),"root_before":saved.root_world,"root_after":root,"transform":sprite.transform})
	return {"active":_active,"actual_gust":_gust_live(),"scenery":scenery,"active_scenery":scenery.size(),"ever_scenery":_ever_grass.size(),"maximum_root_error":_max_root_error,"tip_envelope":TIP_ENVELOPE}

func _exit_tree() -> void:
	_clear()
	if get_tree()!=null and get_tree().node_added.is_connected(_observe): get_tree().node_added.disconnect(_observe)
	if is_instance_valid(encounter) and encounter.presentation_event.is_connected(_event): encounter.presentation_event.disconnect(_event)
