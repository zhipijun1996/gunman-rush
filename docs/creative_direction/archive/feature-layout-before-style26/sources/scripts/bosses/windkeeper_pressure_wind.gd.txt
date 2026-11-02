class_name WindkeeperPressureWind
extends Node
## Local visual consumer of the exact accepted gust. Never moves an actor,
## changes environmental placement, or edits the shared foreground shader.
@export var encounter: WindkeeperPressureEncounter
const FOREGROUND_SHADER := preload("res://shaders/windkeeper_pressure_foreground.gdshader")
const MAX_SCENERY := 32
const MAX_FOREGROUND := 64
const MAX_HISTORY := 128
const TIP_ENVELOPE := 2.8 # Below the existing foreground's3wu mask margin.
var _stage: Node
var _grass: Dictionary = {}
var _foregrounds: Dictionary = {}
var _grass_owned: Dictionary = {}
var _materials_owned: Dictionary = {}
var _ever_grass: Dictionary = {}
var _ever_foreground: Dictionary = {}
var _max_root_error := 0.0
var _active := false

func _ready() -> void:
	process_priority = 2100 # After resident projection/protection upload at2000.
	if encounter == null: return
	_stage = encounter.motor.get_parent()
	_inventory(get_tree().root)
	get_tree().node_added.connect(_observe)
	encounter.presentation_event.connect(_event)

func _inventory(node: Node) -> void:
	_observe(node)
	for child: Node in node.get_children(): _inventory(child)

func _observe(node: Node) -> void:
	if node is UnderworldForeground:
		var foreground := node as UnderworldForeground
		if foreground._world == _stage:
			_foregrounds[node.get_instance_id()] = weakref(node)
	elif node is Sprite2D and node.get_parent() is UnderworldScenery:
		if _grass.size() >= MAX_SCENERY or not is_instance_valid(_stage): return
		if not _stage.is_ancestor_of(node): return
		if not str(node.name).begins_with("Underworld_grass"): return
		if not node.has_meta("grounded_render_root"): return
		# Spend the bounded cache on this encounter's surroundings, rather than
		# the first thirty-two grass clumps near the map entrance.
		if _stage is GeneratedDemoStage:
			var stage := _stage as GeneratedDemoStage
			var root_world := (node.get_parent() as Node2D).to_global(node.get_meta("grounded_render_root"))
			var reach := (encounter.definition as WindkeeperPressureDefinition).wind_pressure_range
			var bounds := stage.global_transform * stage.boss_arena.grow(reach)
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
	var touched_foreground: Dictionary = {}
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
	for key: int in _foregrounds.keys():
		var foreground := (_foregrounds[key] as WeakRef).get_ref() as UnderworldForeground
		if not is_instance_valid(foreground):
			_foregrounds.erase(key)
			continue
		for resident: Dictionary in foreground._residents.values():
			if _materials_owned.size() >= MAX_FOREGROUND and not _materials_owned.has(int(resident.instance_id)): continue
			if str(resident.kind) == "branch": continue
			var root_world: Vector2 = resident.anchor_world
			if not _inside(root_world): continue
			var sprite := resident.sprite as Sprite2D
			if not is_instance_valid(sprite): continue
			var id := sprite.get_instance_id()
			if not _materials_owned.has(id):
				var original := sprite.material as ShaderMaterial
				if original == null or original.shader != UnderworldForeground.ART_SHADER: continue
				var clone := original.duplicate() as ShaderMaterial
				clone.shader = FOREGROUND_SHADER
				_copy_parameters(original,clone)
				_materials_owned[id] = {"sprite":weakref(sprite),"original":original,"clone":clone}
				sprite.material = clone
				if _ever_foreground.size() < MAX_HISTORY: _ever_foreground[id] = true
			var saved: Dictionary = _materials_owned[id]
			if sprite.material != saved.clone: continue
			(saved.clone as ShaderMaterial).set_shader_parameter("boss_wind",Vector2(encounter.locked_direction,0))
			touched_foreground[id] = true
	for id: int in _grass_owned.keys():
		if not touched_grass.has(id): _restore_grass(id)
	for id: int in _materials_owned.keys():
		if not touched_foreground.has(id): _restore_material(id)

func _copy_parameters(source: ShaderMaterial, target: ShaderMaterial) -> void:
	# Includes all64 protection rects/count/overflow/root visibility, crop,
	# attachment, fine-pixel scale and live wind clock. No fixed mask snapshot.
	for parameter: Dictionary in UnderworldForeground.ART_SHADER.get_shader_uniform_list():
		var key := StringName(parameter.name)
		target.set_shader_parameter(key,source.get_shader_parameter(key))

func _restore_grass(id: int) -> void:
	var saved: Dictionary = _grass_owned[id]
	var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
	if is_instance_valid(sprite): sprite.transform = saved.base
	_grass_owned.erase(id)

func _restore_material(id: int) -> void:
	var saved: Dictionary = _materials_owned[id]
	var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
	if is_instance_valid(sprite) and sprite.material == saved.clone:
		var clone := saved.clone as ShaderMaterial
		clone.set_shader_parameter("boss_wind",Vector2.ZERO)
		# Foreground wrote this frame's masks onto the clone. Carry those live
		# values back before restoring, so there is no stale-mask return frame.
		_copy_parameters(clone,saved.original as ShaderMaterial)
		sprite.material = saved.original
	_materials_owned.erase(id)

func _clear() -> void:
	for id: int in _grass_owned.keys(): _restore_grass(id)
	for id: int in _materials_owned.keys(): _restore_material(id)
	_active = false

func receipt() -> Dictionary:
	var scenery: Array[Dictionary] = []
	var foreground: Array[Dictionary] = []
	for id: int in _grass_owned:
		var saved: Dictionary = _grass_owned[id]
		var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
		if not is_instance_valid(sprite): continue
		var root := (sprite.get_parent() as Node2D).to_global(sprite.transform*(saved.attachment as Vector2))
		scenery.append({"instance_id":id,"name":str(sprite.name),"visible":sprite.is_visible_in_tree(),"root_before":saved.root_world,"root_after":root,"transform":sprite.transform})
	for id: int in _materials_owned:
		var saved: Dictionary = _materials_owned[id]
		var sprite := (saved.sprite as WeakRef).get_ref() as Sprite2D
		if not is_instance_valid(sprite): continue
		var clone := saved.clone as ShaderMaterial
		var masks: Variant = clone.get_shader_parameter("protection_rects")
		var capacity: int = masks.size() if masks is PackedVector4Array else 0
		foreground.append({"instance_id":id,"visible":sprite.is_visible_in_tree(),"owned_material_current":sprite.material==clone,"boss_wind":clone.get_shader_parameter("boss_wind"),"protection_count":clone.get_shader_parameter("protection_count"),"protection_overflow":clone.get_shader_parameter("protection_overflow"),"root_visibility":clone.get_shader_parameter("root_visibility"),"protection_capacity":capacity})
	return {"active":_active,"actual_gust":_gust_live(),"scenery":scenery,"foreground":foreground,"active_scenery":scenery.size(),"active_foreground":foreground.size(),"ever_scenery":_ever_grass.size(),"ever_foreground":_ever_foreground.size(),"maximum_root_error":_max_root_error,"tip_envelope":TIP_ENVELOPE,"original_shader_sha256":FileAccess.get_sha256("res://shaders/underworld_foreground.gdshader")}

func _exit_tree() -> void:
	_clear()
	if get_tree()!=null and get_tree().node_added.is_connected(_observe): get_tree().node_added.disconnect(_observe)
	if is_instance_valid(encounter) and encounter.presentation_event.is_connected(_event): encounter.presentation_event.disconnect(_event)
