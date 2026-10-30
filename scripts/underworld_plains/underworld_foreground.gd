class_name UnderworldForeground
extends CanvasLayer
## Stable world objects; early whole-object fading and immediate local protection masks.
const BUILD := "res://assets/underworld_plains/foreground_fine_05/foreground_build.json"
const ART_SHADER := preload("res://shaders/underworld_foreground.gdshader")
const MAX_PROTECTION := 64
const WIND_MARGIN := 3.0
const RETIRE_MARGIN := 4.0 # Includes one extra unit for rounded camera projection.
const PARALLAX := Vector2(1.15,1.12)
const PREBUILD_MARGIN := 96.0
const ANTICIPATION_MARGIN := 64.0
const MASK_SOFT_MARGIN := 24.0
const ROOT_GUARD := 12.0
const ROOT_FADE_DISTANCE := 64.0
const SAFE_DELAY := .3
const FADE_OUT_SECONDS := .18
const FADE_IN_SECONDS := .7
const MAX_ALPHA := .9
const MAX_RESIDENTS := 64
const DYNAMIC_SOURCES := {"player":true,"muzzle":true,"aim_ray":true,"actual_grapple_guide":true,"actual_grapple_rope":true,"actual_actor_or_danger":true,"enemy_and_warning":true,"actual_attack_goal_path":true,"actual_attack_goal_warning":true,"actual_sentry_warning_ray":true,"projectile_and_actual_trail":true}
const MASTER := "res://assets/underworld_plains/foreground_fine_05/master_original.png"
var _world: Node
var _actor: PlayerMotor
var _seed := "home-fine-05"
var _assets: Array[Dictionary] = []
var _textures: Dictionary = {}
var _residents: Dictionary = {}
var _retired: Array[Dictionary] = []
var _advance_frame := -1
var _advance_count := 0
var _tracked: Dictionary = {}
var _trail_fields: Dictionary = {}
var _custom_draw_scripts: Dictionary = {}
var _fixed_world: Array[Rect2] = []
var _protect: Array[Rect2] = []
var _dynamic_protect: Array[Rect2] = []
var _static_protect: Array[Rect2] = []
var _source_counts: Dictionary = {}
var _protection_viewport := Rect2()
var _protection_canvas := Transform2D.IDENTITY
var _overflow := false
var _wind_time := 0.0
var _last: Dictionary = {}
var _receipt_pending := false
var _receipt_center := Vector2.ZERO
var _receipt_size := Vector2.ZERO
var _receipt_layer := 0
var _build: Dictionary = {}
var _spec_cache_key: Array = []
var _spec_cache_found: Array[Dictionary] = []
var _fixed_protection_cache: Dictionary = {}

static func attach(owner: Node,world: Node,actor: PlayerMotor) -> UnderworldForeground:
	var item:=UnderworldForeground.new()
	item.name="UnderworldForeground"
	item._world=world;item._actor=actor
	owner.add_child(item)
	return item

func _ready() -> void:
	_spec_cache_key.clear()
	_spec_cache_found.clear()
	layer=1
	follow_viewport_enabled=false
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_priority=2000
	if not FileAccess.file_exists(BUILD):
		push_error("Foreground art must be built with tools/build_underworld_foreground.gd")
		set_process(false)
		return
	_build=JSON.parse_string(FileAccess.get_file_as_string(BUILD))
	# Sample the original high-detail crops, never magnify the small 05 PNGs.
	# The shader resolves each crop onto the shared 1wu grid at its display size.
	var master:=load(MASTER) as Texture2D
	for source: Dictionary in _build.assets:
		var asset: Dictionary=source.duplicate(true)
		var raw: Array=asset.raw_crop
		var source_size:=Vector2(float(raw[2]),float(raw[3]))
		var native_size:=Vector2(float(asset.size[0]),float(asset.size[1]))
		asset["sample_size"]=source_size
		asset["sample_attachment"]=Vector2(float(asset.attachment[0]),float(asset.attachment[1]))/native_size*source_size
		var atlas:=AtlasTexture.new()
		atlas.atlas=master
		atlas.region=Rect2(Vector2(float(raw[0]),float(raw[1])),source_size)
		atlas.filter_clip=true
		_assets.append(asset)
		_textures[str(asset.id)]=atlas
	if _world is PlainsRegionStage: _seed=str((_world as PlainsRegionStage).generated.manifest.manifest_hash)
	_inventory(get_tree().root)
	get_tree().node_added.connect(_observe)
	get_tree().node_removed.connect(_forget)
	_rebuild_static()

	refresh()

func _exit_tree() -> void:
	if get_tree()==null: return
	if get_tree().node_added.is_connected(_observe):get_tree().node_added.disconnect(_observe)
	if get_tree().node_removed.is_connected(_forget):get_tree().node_removed.disconnect(_forget)

func _process(delta: float) -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_actor):queue_free();return
	_refresh(delta if not get_tree().paused else 0.0)

func _inventory(node: Node) -> void:
	_observe(node)
	for child: Node in node.get_children():_inventory(child)

func _discover_trail_fields(node: Node2D) -> Array[String]:
	var script := node.get_script() as Script
	# Plain Node2D has none of these trail properties. Query the current script
	# table (including script bases) without allocating native Node/CanvasItem
	# property dictionaries for every bullet and visual leaf. Dynamic providers,
	# validators and other native classes retain the complete instance contract.
	# No cached script schema: reloads and added fields take effect immediately.
	var script_only := script is GDScript and node.get_class()==&"Node2D" and script.get_instance_base_type()==&"Node2D" and not node.has_method(&"_get_property_list") and not node.has_method(&"_validate_property")
	var properties := script.get_script_property_list() if script_only else node.get_property_list()
	var trails: Array[String]=[]
	for property: Dictionary in properties:
		if str(property.name) in ["trail","_visual_trail","_trail"]:trails.append(str(property.name))
	return trails

func _observe(node: Node) -> void:
	if node==self or is_ancestor_of(node):return
	if node is Control or node is CollisionShape2D or node is EnemyActor:
		_tracked[node.get_instance_id()]=weakref(node)
	elif node is Node2D and node.get_script()!=null:
		var path:=str(node.get_script().resource_path).to_lower()
		if "projectile" in path or "weapon_entity" in path:
			_tracked[node.get_instance_id()]=weakref(node)
			_trail_fields[node.get_instance_id()]=_discover_trail_fields(node as Node2D)
	if node is UnderworldTerrain and is_instance_valid(_world):_rebuild_static.call_deferred()

func _forget(node: Node) -> void:
	_tracked.erase(node.get_instance_id())
	_trail_fields.erase(node.get_instance_id())

func _rebuild_static() -> void:
	_fixed_world.clear()
	if not is_instance_valid(_world):return
	if _world is PlainsRegionStage:
		_fixed_world.append_array(PlainsRegionScenery.protection(_world as PlainsRegionStage))
	_collect_edges(_world)

func _collect_edges(node: Node) -> void:
	if node is UnderworldTerrain:
		var terrain:=node as UnderworldTerrain
		for edge: Vector4 in terrain.union_edges:
			var a:=terrain.to_global(Vector2(edge.x,edge.y))
			var b:=terrain.to_global(Vector2(edge.z,edge.w))
			_fixed_world.append(Rect2(a.min(b),a.max(b)-a.min(b)).grow(9))
	for child: Node in node.get_children():_collect_edges(child)

func _visible(item: CanvasItem) -> bool:
	if not item.is_inside_tree() or not item.is_visible_in_tree():return false
	var ancestor: Node=item.get_parent()
	while ancestor!=null:
		if ancestor is CanvasLayer and not (ancestor as CanvasLayer).visible:return false
		ancestor=ancestor.get_parent()
	return true

func _drawn_control(item: Control) -> bool:
	if item is Container and not item is PanelContainer:return false
	if item is Label:return not (item as Label).text.is_empty()
	if item is RichTextLabel:return not (item as RichTextLabel).text.is_empty()
	if item is TextureRect:return (item as TextureRect).texture!=null
	if item is ColorRect:return (item as ColorRect).color.a>.02
	if item is BaseButton or item is Range or item is Panel or item is PanelContainer or item is LineEdit or item is TextEdit or item is ItemList or item is PlainsRegionMap:return true
	var script:=item.get_script() as Script
	if script==null:return false
	var key:=script.resource_path
	if not _custom_draw_scripts.has(key):
		var custom:=false
		for method: Dictionary in script.get_script_method_list():
			if str(method.name)=="_draw":custom=true;break
		_custom_draw_scripts[key]=custom
	return bool(_custom_draw_scripts[key])

func _add(rect: Rect2,source: String) -> void:
	if not rect.has_area() or not rect.intersects(_protection_viewport):return
	_source_counts[source]=int(_source_counts.get(source,0))+1
	var next:=rect.intersection(_protection_viewport)
	# Preserve source semantics before union merging: a permanent UI or terrain
	# border must not turn a small local mask into permanent whole-object fading.
	if DYNAMIC_SOURCES.has(source) or source.begins_with("actual_moving_"):
		_dynamic_protect.append(next)
	else:_static_protect.append(next)
	for i: int in range(_protect.size()-1,-1,-1):
		var existing:=_protect[i]
		if existing.encloses(next):return
		if next.encloses(existing):_protect.remove_at(i);continue
		if existing.intersects(next):
			var merged:=existing.merge(next)
			if merged.get_area()<1.25*(existing.get_area()+next.get_area()):next=merged;_protect.remove_at(i)
	_protect.append(next)
	if _protect.size()>MAX_PROTECTION:_overflow=true

func _world_rect(rect: Rect2,source: String) -> void:
	var projected:=_protection_canvas*rect
	if not projected.has_area() or not projected.intersects(_protection_viewport):return
	_add(projected,source)

func _touch_protection(overlay: TouchOverlay) -> void:
	if not overlay.enabled:return
	var transform:=overlay.get_global_transform_with_canvas()
	var circles: Array[Vector3]=[Vector3(overlay.left_center.x,overlay.left_center.y,overlay.radius),Vector3(overlay.right_center.x,overlay.right_center.y,overlay.radius),Vector3(overlay.jump_center.x,overlay.jump_center.y,overlay.jump_radius)]
	if overlay.router.grapple_available:circles.append(Vector3(overlay.hook_center.x,overlay.hook_center.y,overlay.hook_radius))
	if overlay.router.weapon_context_available:circles.append(Vector3(overlay.context_center.x,overlay.context_center.y,overlay.hook_radius*.8))
	if overlay.router.weapon_skill_available:circles.append(Vector3(overlay.skill_center.x,overlay.skill_center.y,overlay.hook_radius*.8))
	for circle: Vector3 in circles:
		var radius:=Vector2.ONE*circle.z
		_add((transform*Rect2(Vector2(circle.x,circle.y)-radius,radius*2)).grow(8),"actual_touch_hud")
	_add((transform*(overlay.get("_pause_rect") as Rect2)).grow(8),"actual_touch_hud")
	if not overlay.hide_reset_button:_add((transform*(overlay.get("_reset_rect") as Rect2)).grow(8),"actual_touch_hud")

func _fixed_protection() -> void:
	# Only reuse the fixed-geometry prefix. Exact inputs include camera/zoom,
	# viewport and geometry; every dynamic/UI mask still runs this frame, in
	# its original order. Copy arrays because the following union pass mutates.
	if not _fixed_protection_cache.is_empty() and _fixed_protection_cache.world==_fixed_world and _fixed_protection_cache.canvas==_protection_canvas and _fixed_protection_cache.viewport==_protection_viewport:
		_protect.assign(_fixed_protection_cache.protect)
		_static_protect.assign(_fixed_protection_cache.static_protect)
		_source_counts=_fixed_protection_cache.source_counts.duplicate()
		_overflow=bool(_fixed_protection_cache.overflow)
		return
	for rect: Rect2 in _fixed_world:_world_rect(rect,"actual_static_geometry_and_functions")
	_fixed_protection_cache={"world":_fixed_world.duplicate(),"canvas":_protection_canvas,"viewport":_protection_viewport,"protect":_protect.duplicate(),"static_protect":_static_protect.duplicate(),"source_counts":_source_counts.duplicate(),"overflow":_overflow}

func _protection() -> void:
	var viewport:=get_viewport()
	_protection_viewport=viewport.get_visible_rect()
	_protection_canvas=viewport.get_canvas_transform()
	_protect.clear();_dynamic_protect.clear();_static_protect.clear();_source_counts.clear();_overflow=false
	_fixed_protection()
	_world_rect(Rect2(_actor.global_position-Vector2(50,60),Vector2(100,120)),"player")
	var controller:=_actor.get_node_or_null("Controller") as PlayerController
	var courier:=_actor.get_node_or_null("CourierVisual") as CourierVisual
	if controller!=null and courier!=null and courier.is_node_ready():
		var muzzle:=courier.visible_muzzle_position()
		_world_rect(Rect2(muzzle-Vector2(22,22),Vector2(44,44)),"muzzle")
		if not controller.router.aim_direction.is_zero_approx():
			var finish:=muzzle+controller.router.aim_direction.normalized()*220.0
			_world_rect(Rect2(muzzle.min(finish),muzzle.max(finish)-muzzle.min(finish)).grow(18),"aim_ray")
	if controller!=null and controller.traversal!=null:
		var traversal:=controller.traversal
		var origin:=_actor.global_position+Vector2(0,-6)
		if traversal.guide_active:
			_world_rect(Rect2(origin.min(traversal.guide_point),origin.max(traversal.guide_point)-origin.min(traversal.guide_point)).grow(18),"actual_grapple_guide")
		if traversal.state in [&"hook_cast",&"hook_fly",&"hook_hang",&"hook_pull",&"hook_kick",&"hook_miss",&"hook_retract",&"hook_contact_kick"]:
			_world_rect(Rect2(origin.min(traversal.hook_tip),origin.max(traversal.hook_tip)-origin.min(traversal.hook_tip)).grow(18),"actual_grapple_rope")
	for reference: WeakRef in _tracked.values():
		var node:=reference.get_ref() as Node
		if node==null or not node.is_inside_tree():continue
		if node is Control:
			var control:=node as Control
			if not control.is_visible_in_tree():continue
			if control is TouchOverlay:
				if _visible(control):_touch_protection(control as TouchOverlay)
			else:
				var rect: Rect2=(control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)).grow(8)
				if not rect.intersects(_protection_viewport) or not _visible(control):continue
				if _drawn_control(control):_add(rect,"actual_visible_ui")
		elif node is CollisionShape2D:
			var collision:=node as CollisionShape2D
			if collision.disabled or collision.shape==null or not collision.is_visible_in_tree():continue
			var parent:=collision.get_parent() as CollisionObject2D
			if parent==null or parent.collision_layer==0:continue
			var rect: Rect2=collision.get_global_transform_with_canvas()*collision.shape.get_rect()
			# Every emitted platform edge or danger mask is inside this envelope.
			if not rect.grow(44).intersects(_protection_viewport) or not _visible(collision):continue
			if parent is StaticBody2D or parent is AnimatableBody2D:
				var edge_source:="actual_moving_platform_edge" if parent is AnimatableBody2D else "actual_platform_edge"
				if maxf(rect.size.x,rect.size.y)>180:
					_add(Rect2(rect.position,Vector2(rect.size.x,1)).grow(10),edge_source)
					_add(Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,1)).grow(10),edge_source)
					_add(Rect2(rect.position,Vector2(1,rect.size.y)).grow(10),edge_source)
					_add(Rect2(Vector2(rect.end.x,rect.position.y),Vector2(1,rect.size.y)).grow(10),edge_source)
				else:_add(rect.grow(18),"actual_moving_platform" if parent is AnimatableBody2D else "actual_mechanism_or_platform")
			else:_add(rect.grow(44),"actual_actor_or_danger")
		elif node is EnemyActor:
			var enemy:=node as EnemyActor
			if enemy.health.terminal or not is_instance_valid(enemy.motor) or not _visible(enemy.motor):continue
			var zone:=Rect2(enemy.motor.global_position-Vector2(100,100),Vector2(200,200))
			_world_rect(zone,"enemy_and_warning")
			_enemy_warning_protection(enemy)
		elif node is Node2D:
			var projectile:=node as Node2D
			if not _visible(projectile):continue
			var path_bounds:=Rect2(projectile.global_position-Vector2(28,28),Vector2(56,56))
			for field: String in _trail_fields.get(projectile.get_instance_id(),[]):
				var points: Variant=projectile.get(field)
				if points is Array or points is PackedVector2Array:
					for point: Variant in points:
						if point is Vector2:path_bounds=path_bounds.merge(Rect2(point-Vector2(24,24),Vector2(48,48)))
			_world_rect(path_bounds,"projectile_and_actual_trail")
	if _world is PlainsRegionStage:
		var stage:=_world as PlainsRegionStage
		_world_rect(stage.boss_arena.grow(32),"boss_arena_and_warnings")
		for pickup: Dictionary in stage.pickups:
			if bool(pickup.get("claimed",false)):continue
			var point: Vector2=pickup.position
			_world_rect(Rect2(point-Vector2(45,45),Vector2(90,90)),"actual_unclaimed_reward")

func _enemy_warning_protection(enemy: EnemyActor) -> void:
	var behavior:=enemy.attack_behavior
	if behavior==null or behavior.state not in [&"telegraph",&"attack"]:return
	var origin:=enemy.motor.global_position
	var kind:=enemy.definition.behavior_id
	if kind in [&"diver",&"hopper",&"root_bell"]:
		var goal:=behavior.attack_goal
		_world_rect(Rect2(origin.min(goal),origin.max(goal)-origin.min(goal)).grow(18),"actual_attack_goal_path")
		if kind==&"root_bell":
			var pulse:=enemy.definition.pulse_size
			_world_rect(Rect2(goal-Vector2(pulse.x*.5,pulse.y),pulse).grow(18),"actual_attack_goal_warning")
		else:_world_rect(Rect2(goal-Vector2(24,24),Vector2(48,48)),"actual_attack_goal_warning")
	elif kind in [&"sentry",&"fan_sentry"]:
		for angle: float in ([-.18,0.0,.18] if kind==&"fan_sentry" else [0.0]):
			var direction:=behavior.locked_direction.rotated(angle)
			var a:=origin+direction*25.0
			var b:=origin+direction*90.0
			_world_rect(Rect2(a.min(b),a.max(b)-a.min(b)).grow(12),"actual_sentry_warning_ray")

func _roll(category: String,x: int,y: int) -> int:
	# Avalanche the string hash: neighboring world cells must not become a
	# repeated diagonal sequence after the small placement moduli below.
	var value: int=(_seed+":"+category+":"+str(x)+":"+str(y)).hash()
	value=((value^(value>>16))*0x45d9f3b)&0xffffffff
	value=((value^(value>>16))*0x45d9f3b)&0xffffffff
	return posmod(value^(value>>16),1000000)

func _object_spec(id: String,kind: String,at: Vector2,roll: int) -> Dictionary:
	# All identity properties come from the cell, never from the current camera,
	# protection, admission order, or a fallback-size search.
	var branch:=kind=="branch"
	var asset: Dictionary=_assets[(3 if roll%2==1 else 4) if branch else roll%3]
	var source_size: Vector2=asset.sample_size
	var display_scale: float=(320.0+float((roll/193)%49))/source_size.x if branch else (148.0+float((roll/97)%29))/source_size.y
	return {"id":id,"asset":asset,"kind":kind,"anchor_world":at,"display_scale":display_scale,"wind_phase":float(_roll(id,0,0)%1000)*.01}

func _project(spec: Dictionary,center: Vector2,size: Vector2) -> Dictionary:
	var asset: Dictionary=spec.asset
	var screen: Vector2=(spec.anchor_world-center)*PARALLAX+size*.5
	var attachment: Vector2=asset.sample_attachment*float(spec.display_scale)
	var position: Vector2=(screen-attachment).round()
	var anchor:=position+attachment
	var bounds:=Rect2(position,(asset.sample_size as Vector2)*float(spec.display_scale))
	var clearance: float=size.y
	if str(spec.kind)=="branch":
		clearance=-anchor.x if str(asset.id)=="branch_left" else anchor.x-size.x
	else:clearance=anchor.y-size.y
	return {"position":position,"attachment":anchor,"bounds":bounds,"root_clearance":clearance}

func _specifications(center: Vector2,size: Vector2) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	var buffer:=Rect2(Vector2.ZERO,size).grow(PREBUILD_MARGIN)
	var home_floor: Variant=null
	if _world.get_script()!=null and str(_world.get_script().resource_path).ends_with("underworld_home_world.gd"):
		home_floor=_world.get("floor_y")
	# Cache only deterministic cell candidates, never projected/visible/admitted state.
	var cells: Array[int]=[
		floori((center.x-size.x*.5/PARALLAX.x-420)/520),ceili((center.x+size.x*.5/PARALLAX.x+420)/520)+1,
		floori((center.y+size.y*.5/PARALLAX.y-280)/144),ceili((center.y+size.y*.5/PARALLAX.y+280)/144)+1,
		floori((center.x-size.x*.5/PARALLAX.x-460)/320),ceili((center.x+size.x*.5/PARALLAX.x+460)/320)+1,
		floori((center.y-size.y*.5/PARALLAX.y-360)/112),ceili((center.y+size.y*.5/PARALLAX.y+160)/112)+1]
	var key: Array=[cells,_seed,home_floor,_world.get_instance_id()]
	if key==_spec_cache_key:
		found=_spec_cache_found
	else:
		for x: int in range(cells[0],cells[1]):
			if home_floor!=null:
				var roll:=_roll("home_grass",x,0)
				if roll%100<72:
					var at:=Vector2(x*520+roll%380,float(home_floor)+236+(roll/480)%19)
					found.append(_object_spec("home_grass/%d"%x,"grass",at,roll))
				continue
			for y: int in range(cells[2],cells[3]):
				var roll:=_roll("grass",x,y)
				if roll%100>=62:continue
				var at:=Vector2(x*520+70+roll%380,y*144+24+(roll/480)%96)
				found.append(_object_spec("grass/%d/%d"%[x,y],"grass",at,roll))
		for x: int in range(cells[4],cells[5]):
			for y: int in range(cells[6],cells[7]):
				var roll:=_roll("branch",x,y)
				if roll%100>=48:continue
				var at:=Vector2(x*320+40+roll%240,y*112+18+(roll/1200)%76)
				found.append(_object_spec("branch/%d/%d"%[x,y],"branch",at,roll))
		_spec_cache_key=key
		_spec_cache_found=found
	var relevant: Array[Dictionary]=[]
	for spec: Dictionary in found:
		var projected:=_project(spec,center,size)
		if float(projected.root_clearance)>=ROOT_GUARD and buffer.intersects(projected.bounds):relevant.append(spec)
	# This order is only used to admit new objects. Residents are never ranked
	# again, evicted in favour of a candidate, resized, or assigned another asset.
	relevant.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return str(a.id)<str(b.id))
	return relevant

func _create_resident(spec: Dictionary) -> void:
	var sprite:=Sprite2D.new()
	sprite.name="ResidentForeground_%d"%sprite.get_instance_id()
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture=_textures[str(spec.asset.id)]
	sprite.scale=Vector2.ONE*float(spec.display_scale)
	var material:=ShaderMaterial.new()
	material.shader=ART_SHADER
	sprite.material=material
	material.set_shader_parameter("attachment",spec.asset.sample_attachment)
	material.set_shader_parameter("art_size",spec.asset.sample_size)
	material.set_shader_parameter("source_to_world",float(spec.display_scale))
	material.set_shader_parameter("branch",str(spec.kind)=="branch")
	material.set_shader_parameter("wind_phase",float(spec.wind_phase))
	sprite.hide()
	add_child(sprite)
	var resident:=spec.duplicate()
	resident.merge({"sprite":sprite,"instance_id":sprite.get_instance_id(),"alpha":0.0,"target_alpha":0.0,"safe_time":0.0,"admitted":false,"entered_view":false,"mask_rect_count":0,"safe":false,"root_gate":0.0,"born_frame":Engine.get_process_frames()})
	_residents[str(spec.id)]=resident

func _retire(id: String,reason: String) -> void:
	var resident: Dictionary=_residents[id]
	_retired.append({"id":id,"instance_id":resident.instance_id,"reason":reason,"frame":Engine.get_process_frames()})
	if _retired.size()>64:_retired.pop_front()
	(resident.sprite as Sprite2D).queue_free()
	_residents.erase(id)

func _exposed_regions(bounds: Rect2,size: Vector2) -> Array[Rect2]:
	# Geometry estimate only, not a claim about painted-alpha pixel coverage.
	# Permanent masks carve local regions instead of suppressing the whole reed.
	var regions: Array[Rect2]=[]
	var clipped:=bounds.intersection(Rect2(Vector2.ZERO,size))
	if not clipped.has_area():return regions
	regions.append(clipped)
	for mask_rect: Rect2 in _static_protect:
		var strict:=mask_rect.grow(WIND_MARGIN)
		if not clipped.intersects(strict):continue
		var next: Array[Rect2]=[]
		for part: Rect2 in regions:
			var cut:=part.intersection(strict)
			if not cut.has_area():next.append(part);continue
			var strips: Array[Rect2]=[
				Rect2(part.position,Vector2(part.size.x,cut.position.y-part.position.y)),
				Rect2(Vector2(part.position.x,cut.end.y),Vector2(part.size.x,part.end.y-cut.end.y)),
				Rect2(Vector2(part.position.x,cut.position.y),Vector2(cut.position.x-part.position.x,cut.size.y)),
				Rect2(Vector2(cut.end.x,cut.position.y),Vector2(part.end.x-cut.end.x,cut.size.y))]
			for strip: Rect2 in strips:
				if strip.has_area():next.append(strip)
		# A complex static mask can over-estimate exposed area if fragmented.
		# Bound CPU work; the exact GPU masks remain authoritative and unchanged.
		if next.size()>64:return regions
		regions=next
		if regions.is_empty():break
	return regions

func _distance_to_rectangles(regions: Array[Rect2],protection: Array[Rect2]) -> float:
	var result:=1000000.0
	for region: Rect2 in regions:
		var bounds:=region.grow(WIND_MARGIN)
		for rect: Rect2 in protection:
			var separation: Vector2=(rect.position-bounds.end).max(bounds.position-rect.end).max(Vector2.ZERO)
			result=minf(result,separation.length())
	return result

func _sync_residents(center: Vector2,size: Vector2) -> void:
	var view:=Rect2(Vector2.ZERO,size)
	var buffer:=view.grow(PREBUILD_MARGIN)
	var grass_slots:=0
	var branch_slots:=0
	for id: String in _residents.keys():
		var resident: Dictionary=_residents[id]
		var projected:=_project(resident,center,size)
		resident.merge(projected,true)
		var bounds: Rect2=resident.bounds
		# Once any part entered view, release only after the complete image and
		# wind envelope are outside. Hiding/fading never releases its identity.
		if bool(resident.entered_view) and not bounds.grow(RETIRE_MARGIN).intersects(view):
			_retire(id,"complete_bounds_offscreen")
			continue
		if not bool(resident.entered_view) and not bounds.grow(RETIRE_MARGIN).intersects(buffer):
			_retire(id,"prebuild_buffer_left")
			continue
		if bounds.grow(WIND_MARGIN).intersects(view):resident.entered_view=true
		if bool(resident.admitted):
			if str(resident.kind)=="branch":branch_slots+=1
			else:grass_slots+=1
	for spec: Dictionary in _specifications(center,size):
		if _residents.has(str(spec.id)) or _residents.size()>=MAX_RESIDENTS:continue
		_create_resident(spec)
		var resident: Dictionary=_residents[str(spec.id)]
		resident.merge(_project(resident,center,size),true)
		resident.entered_view=(resident.bounds as Rect2).grow(WIND_MARGIN).intersects(view)
	for resident: Dictionary in _residents.values():
		var exposed:=_exposed_regions(resident.bounds,size)
		var exposed_area:=0.0
		for region: Rect2 in exposed:exposed_area+=region.get_area()
		var distance:=_distance_to_rectangles(exposed,_dynamic_protect)
		if str(resident.kind)=="branch":
			# A branch's thin stem must remain connected. Even a permanent UI
			# mask can sever it, so fade the complete image before any protection.
			var entire_branch: Array[Rect2]=[resident.bounds]
			distance=_distance_to_rectangles(entire_branch,_protect)
		resident["unmasked_bounds_area"]=exposed_area
		resident["protection_clearance"]=distance
		resident.root_gate=smoothstep(ROOT_GUARD,ROOT_FADE_DISTANCE,float(resident.root_clearance))
		resident.safe=not _overflow and distance>=ANTICIPATION_MARGIN and float(resident.root_clearance)>=ROOT_GUARD
		if not bool(resident.safe):resident.safe_time=0.0
		if not bool(resident.admitted) and bool(resident.safe) and not exposed.is_empty():
			var branch: bool=str(resident.kind)=="branch"
			if (branch and branch_slots>=1) or (not branch and grass_slots>=2):continue
			# Prevent admission of overlapping decoration; this decision sticks
			# until offscreen retirement rather than switching every frame.
			var crowded:=false
			for other: Dictionary in _residents.values():
				if bool(other.admitted) and (resident.bounds as Rect2).grow(24).intersects(other.bounds):crowded=true;break
			if crowded:continue
			resident.admitted=true
			if branch:branch_slots+=1
			else:grass_slots+=1
		resident.target_alpha=MAX_ALPHA if bool(resident.admitted) and bool(resident.safe) and float(resident.safe_time)>=SAFE_DELAY else 0.0

func refresh() -> void:
	# Presentation may call this again in the same frame; it never advances
	# wind, safety duration, or opacity. Only _process(delta) owns elapsed time.
	_refresh(0.0)

func _refresh(delta: float) -> void:
	if _assets.size()!=5 or not is_instance_valid(_world) or not is_instance_valid(_actor):return
	_protection()
	var camera:=get_viewport().get_camera_2d()
	var center:=camera.get_screen_center_position() if camera!=null else _actor.global_position
	var size:=get_viewport().get_visible_rect().size
	_sync_residents(center,size)
	var frame:=Engine.get_process_frames()
	if delta>0 and not get_tree().paused and frame!=_advance_frame:
		_advance_frame=frame
		_advance_count+=1
		_wind_time+=delta
		for resident: Dictionary in _residents.values():
			if bool(resident.safe):resident.safe_time=float(resident.safe_time)+delta
			resident.target_alpha=MAX_ALPHA if bool(resident.admitted) and bool(resident.safe) and float(resident.safe_time)>=SAFE_DELAY else 0.0
			var duration:=FADE_IN_SECONDS if float(resident.target_alpha)>float(resident.alpha) else FADE_OUT_SECONDS
			resident.alpha=move_toward(float(resident.alpha),float(resident.target_alpha),delta*MAX_ALPHA/duration)
	_render_receipt(center,size)

func _render_receipt(center: Vector2,size: Vector2) -> void:
	var view:=Rect2(Vector2.ZERO,size)
	# The shader uses render-target-local pixels. Stretch into that backing
	# store without the screen transform's window/letterbox placement offset.
	var raster_transform := get_viewport().get_stretch_transform()
	var raster_scale := raster_transform.get_scale().abs()
	# Grow each protection rectangle once per synchronous render, preserving order.
	var strict_masks: Array[Rect2]=[]
	var soft_masks: Array[Rect2]=[]
	for rect: Rect2 in _protect:
		var strict:=rect.grow(WIND_MARGIN)
		strict_masks.append(strict)
		soft_masks.append(strict.grow(MASK_SOFT_MARGIN))
	for resident: Dictionary in _residents.values():
		var sprite:=resident.sprite as Sprite2D
		var bounds: Rect2=resident.bounds
		var material:=sprite.material as ShaderMaterial
		var masks:=PackedVector4Array()
		var wind_bounds:=bounds.grow(WIND_MARGIN)
		for i: int in strict_masks.size():
			var strict:=strict_masks[i]
			if soft_masks[i].intersects(wind_bounds):
				var raster: Rect2 = raster_transform * strict
				masks.append(Vector4(raster.position.x,raster.position.y,raster.end.x,raster.end.y))
		resident.mask_rect_count=masks.size()
		masks.resize(MAX_PROTECTION)
		material.set_shader_parameter("protection_rects",masks)
		material.set_shader_parameter("protection_count",mini(int(resident.mask_rect_count),MAX_PROTECTION))
		material.set_shader_parameter("protection_overflow",_overflow)
		material.set_shader_parameter("mask_soft_margin",MASK_SOFT_MARGIN * minf(raster_scale.x,raster_scale.y))
		material.set_shader_parameter("root_visibility",float(resident.root_gate))
		material.set_shader_parameter("wind_time",_wind_time)
		sprite.position=resident.position
		sprite.modulate=Color(1,1,1,float(resident.alpha))
		sprite.visible=bool(resident.admitted) and not _overflow and float(resident.alpha)>0.0 and float(resident.root_gate)>0.0 and wind_bounds.intersects(view)
		resident["drawn"]=sprite.visible
	# Rendering and admission always run. Only the diagnostic dictionary is lazy;
	# these resident/protection values change together inside the next refresh.
	_receipt_center=center
	_receipt_size=size
	_receipt_layer=layer
	_receipt_pending=true

func _materialize_receipt() -> void:
	var center:=_receipt_center
	var size:=_receipt_size
	var visible_items: Array[Dictionary]=[]
	var residents: Array[Dictionary]=[]
	var rejected: Array[Dictionary]=[]
	var grass_count:=0
	var branch_count:=0
	for resident: Dictionary in _residents.values():
		var bounds: Rect2=resident.bounds
		var asset: Dictionary=resident.asset
		var anchor: Vector2=resident.attachment
		var at: Vector2=resident.anchor_world
		var item: Dictionary={"id":resident.id,"resident_id":resident.id,"instance_id":resident.instance_id,"asset":asset.id,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"attachment":[anchor.x,anchor.y],"world_anchor":[at.x,at.y],"opacity":float(resident.alpha)*float(resident.root_gate),"alpha":resident.alpha,"target_alpha":resident.target_alpha,"safe_time":resident.safe_time,"admitted":resident.admitted,"entered_view":resident.entered_view,"root_clearance":resident.root_clearance,"root_gate":resident.root_gate,"protection_clearance":resident.protection_clearance,"unmasked_bounds_area":resident.unmasked_bounds_area,"mask_rect_count":resident.mask_rect_count,"display_scale":resident.display_scale,"wind_phase":resident.wind_phase,"raw_crop":asset.raw_crop,"source":MASTER,"collision":false,"drawn":resident.drawn}
		residents.append(item)
		if bool(resident.drawn):
			visible_items.append(item.duplicate())
			if str(resident.kind)=="branch":branch_count+=1
			else:grass_count+=1
		elif not bool(resident.admitted):rejected.append({"id":resident.id,"reason":"waiting_for_safe_admission_or_resident_budget"})
	var rectangles: Array=[]
	for rect: Rect2 in _protect:rectangles.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	var dynamic_rectangles: Array=[]
	for rect: Rect2 in _dynamic_protect:dynamic_rectangles.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	_last={"schema":"underworld-foreground-runtime-v1","revision":"FOREGROUND-CONTINUITY-08","parallax":[PARALLAX.x,PARALLAX.y],"minimum_visible_opacity":0.0,"layer":_receipt_layer,"grid_wu":1,"seed":_seed,"camera":[center.x,center.y],"viewport":[size.x,size.y],"grass_count":grass_count,"branch_count":branch_count,"visible":visible_items,"residents":residents,"resident_count":_residents.size(),"retired":_retired.duplicate(true),"advance_frame":_advance_frame,"advance_count":_advance_count,"rejected":rejected,"protection_count":_protect.size(),"protection_sources":_source_counts.duplicate(),"protection_rectangles":rectangles,"anticipation_rectangles":dynamic_rectangles,"overflow_hidden":_overflow,"live_warning_hidden":false,"master_sha256":_build.master_sha256,"physics_mutation":false,"wind_time":_wind_time,"mask_policy":{"strict_inside":true,"wind_margin":WIND_MARGIN,"soft_margin":MASK_SOFT_MARGIN,"anticipation_margin":ANTICIPATION_MARGIN,"safe_delay":SAFE_DELAY,"fade_in_seconds":FADE_IN_SECONDS,"fade_out_seconds":FADE_OUT_SECONDS,"per_item_filtered":true,"anticipation_sources":"grass_dynamic_exposed_bounds_branch_all_protection_complete_bounds","grass_anticipation":"dynamic_only_over_exposed_bounds","branch_anticipation":"all_protection_over_complete_bounds_plus_wind","static_protection":"strict_local_mask_with_branch_whole_fade","retire_margin":RETIRE_MARGIN,"root_guard":ROOT_GUARD,"root_fade_distance":ROOT_FADE_DISTANCE}}

func receipt() -> Dictionary:
	if _receipt_pending:
		_materialize_receipt()
		_receipt_pending=false
	return _last.duplicate(true)
