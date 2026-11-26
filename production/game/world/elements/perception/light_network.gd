class_name WorldLightNetwork
extends Node
## One room owns its light sources, visual occluders and the optical update order.
const EQUIPMENT_LIGHT := preload("res://config/equipment_lamp.json")
var lamps: Dictionary = {}
var flowers: Dictionary = {}
var reeds: Array[Node] = []
var controller: PlayerController
var order: Array = []

static func of(room: Node) -> WorldLightNetwork:
	var existing := room.get_node_or_null("RoomPerception") as WorldLightNetwork
	if existing != null: return existing
	var created := WorldLightNetwork.new()
	created.name = "RoomPerception"
	created.process_physics_priority = 1190
	room.add_child(created)
	return created

func register_light_object(id: String, object: Node, registry: Dictionary) -> void:
	registry[id] = object
	object.tree_exiting.connect(func(): registry.erase(id), CONNECT_ONE_SHOT)

static func intensity(distance: float, radius: float, brightness: float, edge: float) -> float:
	if distance > radius: return 0.0
	if edge == 0.0: return brightness
	return brightness * clampf((radius-distance)/(radius*edge),0.0,1.0)

func clear_light_ray(start: Vector2, end: Vector2) -> bool:
	if start.is_equal_approx(end): return true
	var room := get_parent() as Node2D
	var ray := PhysicsRayQueryParameters2D.create(start,end,1)
	ray.hit_from_inside = true
	return room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func active_sources(types: Array) -> Array:
	var result := []
	if "local_light" in types:
		for lamp: Node in lamps.values():
			if lamp.active:
				result.append({"center":lamp.light_center(),"radius":lamp.light_radius,"brightness":lamp.brightness,"edge":lamp.edge_falloff})
	var room := get_parent() as FixedWorldRoom
	if "equipped_light" in types and is_instance_valid(controller) and room.services != null and room.services.active("EQ_LAMP"):
		var profile: Dictionary = EQUIPMENT_LIGHT.data
		result.append({"center":controller.motor.global_position,"radius":profile.radius,"brightness":profile.brightness,"edge":profile.edge_falloff})
	return result

func sample_sources(at: Vector2, sources: Array) -> float:
	var level := 0.0
	for lamp: Dictionary in sources:
		var value := intensity(at.distance_to(lamp.center),lamp.radius,lamp.brightness,lamp.edge)
		if value > level and clear_light_ray(lamp.center,at): level = value
	return level

func sample(at: Vector2, types: Array) -> float:
	return sample_sources(at,active_sources(types))

## Positive interior length. A tangent contact or two identical points do not obscure vision.
static func passes_through(a: Vector2, b: Vector2, box: Rect2) -> bool:
	if a.is_equal_approx(b): return false
	var lo := 0.0
	var hi := 1.0
	for axis: int in 2:
		var delta := b[axis]-a[axis]
		if is_zero_approx(delta):
			if a[axis] <= box.position[axis] or a[axis] >= box.end[axis]: return false
			continue
		var enter := (box.position[axis]-a[axis])/delta
		var leave := (box.end[axis]-a[axis])/delta
		lo = maxf(lo,minf(enter,leave)); hi = minf(hi,maxf(enter,leave))
		if hi <= lo: return false
	return true

static func sight_blocked(room: Node, a: Vector2, b: Vector2) -> bool:
	var network := room.get_node_or_null("RoomPerception") as WorldLightNetwork
	if network == null: return false
	for reed: Node2D in network.reeds:
		if reed.active and passes_through(reed.to_local(a),reed.to_local(b),reed.bounds): return true
	return false

static func possible_track(p: Dictionary) -> PackedVector2Array:
	var origin := FixedWorldProvider.point(p.position)
	var result := PackedVector2Array([origin])
	if p.light_mode == "guide":
		var offsets: Array = p.route if not p.route.is_empty() else [p.endpoint]
		for offset: Array in offsets: result.append(origin+FixedWorldProvider.point(offset))
	return result

static func rectangle_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func track_reaches(a: Vector2, b: Vector2, flower: Vector2, radius: float) -> bool:
	var closest := a if a == b else Geometry2D.get_closest_point_to_segment(flower,a,b)
	return flower.distance_to(closest) <= radius

static func in_light_cone(rect: Rect2, a: Vector2, b: Vector2, flower: Vector2) -> bool:
	if rect.has_point(flower) or rect.has_point(a) or rect.has_point(b): return true
	if passes_through(a,flower,rect) or passes_through(b,flower,rect) or passes_through(a,b,rect): return true
	if a.is_equal_approx(b) or is_zero_approx((a-flower).cross(b-flower)): return false
	for corner: Vector2 in rectangle_points(rect):
		if Geometry2D.point_is_inside_triangle(corner,a,b,flower): return true
	return false

static func occlusion_envelope(row: Dictionary) -> Rect2:
	var p: Dictionary = row.properties
	var origin := FixedWorldProvider.point(p.get("position",[0,0]))
	match str(row.definition_id):
		"gate.masonry", "terrain.breakable": return FixedWorldProvider.rect(p.bounds)
		"platform.moving","platform.crumble","platform.shot_rail","platform.windchime_dandelion":
			var size := FixedWorldProvider.point(p.platform_size)
			var box := Rect2(origin-size/2.0,size)
			var offsets: Array = p.get("stations",p.get("route",[]))
			if offsets.is_empty(): offsets = [p.get("endpoint",[0,0])]
			for offset: Array in offsets: box = box.merge(Rect2(origin+FixedWorldProvider.point(offset)-size/2.0,size))
			return box
		"platform.rotating_beam":
			var radius: float = p.beam_length*maxf(p.pivot_fraction,1.0-p.pivot_fraction)+p.beam_thickness*0.5
			return Rect2(origin,Vector2.ZERO).grow(radius)
		"hazard.falling_weight":
			var size := FixedWorldProvider.point(p.body_size)
			var box := Rect2(origin-size/2.0,size)
			return box.merge(Rect2(box.position+FixedWorldProvider.point(p.landing_offset),size))
	return Rect2()

## Additional incoming edges for the room's typed control graph.
static func control_dependencies(doc: Dictionary) -> Dictionary:
	var incoming := {}
	for flower: Dictionary in doc.entities.values():
		if flower.definition_id != "switch.light": continue
		var sources: Array = flower.properties.light_source_types
		var center := FixedWorldProvider.point(flower.properties.position)
		var deps := {}
		for lamp: Dictionary in doc.entities.values():
			if lamp.definition_id != "environment.local_light" or "local_light" not in sources: continue
			var track := possible_track(lamp.properties)
			for i: int in track.size():
				var a := track[maxi(i-1,0)]
				var b := track[i]
				if not track_reaches(a,b,center,lamp.properties.light_radius): continue
				deps[lamp.id] = true
				for blocker: Dictionary in doc.entities.values():
					var box := occlusion_envelope(blocker)
					if box.has_area() and in_light_cone(box,a,b,center): deps[blocker.id] = true
		if "equipped_light" in sources:
			for blocker: Dictionary in doc.entities.values():
				var box := occlusion_envelope(blocker)
				if box.has_area() and center.distance_to(center.clamp(box.position,box.end)) <= float(EQUIPMENT_LIGHT.data.radius):
					deps[blocker.id] = true
		incoming[flower.id] = deps.keys()
	return incoming

func _ready() -> void:
	order = get_parent().get_meta("mechanism_control_order",[])

func _physics_process(delta: float) -> void:
	for id: String in order:
		if lamps.has(id): lamps[id].advance_light(delta)
		if flowers.has(id): flowers[id].sample_light(delta)
