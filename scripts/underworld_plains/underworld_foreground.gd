class_name UnderworldForeground
extends CanvasLayer
## Sparse world-seeded, offscreen-attached foreground. Readability wins every frame.
const BUILD := "res://assets/underworld_plains/foreground_fine_05/foreground_build.json"
const ART_SHADER := preload("res://shaders/underworld_foreground.gdshader")
const MAX_PROTECTION := 64
const WIND_MARGIN := 3.0
const PARALLAX := Vector2(1.15,1.12)
const MIN_OPACITY := .65
const MASTER := "res://assets/underworld_plains/foreground_fine_05/master_original.png"
var _world: Node
var _actor: PlayerMotor
var _seed := "home-fine-05"
var _assets: Array[Dictionary] = []
var _textures: Dictionary = {}
var _sprites: Array[Sprite2D] = []
var _tracked: Dictionary = {}
var _trail_fields: Dictionary = {}
var _custom_draw_scripts: Dictionary = {}
var _fixed_world: Array[Rect2] = []
var _protect: Array[Rect2] = []
var _source_counts: Dictionary = {}
var _overflow := false
var _danger_active := false
var _wind_time := 0.0
var _last: Dictionary = {}
var _build: Dictionary = {}

static func attach(owner: Node,world: Node,actor: PlayerMotor) -> UnderworldForeground:
	var item:=UnderworldForeground.new()
	item.name="UnderworldForeground"
	item._world=world;item._actor=actor
	owner.add_child(item)
	return item

func _ready() -> void:
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
	for i: int in 3:
		var sprite:=Sprite2D.new()
		sprite.name="SparseForeground_%d"%i
		sprite.centered=false
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var material:=ShaderMaterial.new();material.shader=ART_SHADER
		sprite.material=material
		sprite.hide()
		add_child(sprite)
		_sprites.append(sprite)
	refresh()

func _exit_tree() -> void:
	if get_tree()==null: return
	if get_tree().node_added.is_connected(_observe):get_tree().node_added.disconnect(_observe)
	if get_tree().node_removed.is_connected(_forget):get_tree().node_removed.disconnect(_forget)

func _process(delta: float) -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_actor):queue_free();return
	if not get_tree().paused:_wind_time+=delta
	refresh()

func _inventory(node: Node) -> void:
	_observe(node)
	for child: Node in node.get_children():_inventory(child)

func _observe(node: Node) -> void:
	if node==self or is_ancestor_of(node):return
	if node is Control or node is CollisionShape2D or node is EnemyActor:
		_tracked[node.get_instance_id()]=weakref(node)
	elif node is Node2D and node.get_script()!=null:
		var path:=str(node.get_script().resource_path).to_lower()
		if "projectile" in path or "weapon_entity" in path:
			_tracked[node.get_instance_id()]=weakref(node)
			var trails: Array[String]=[]
			for property: Dictionary in node.get_property_list():
				if str(property.name) in ["trail","_visual_trail","_trail"]:trails.append(str(property.name))
			_trail_fields[node.get_instance_id()]=trails
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
	if not rect.has_area() or not rect.intersects(get_viewport().get_visible_rect()):return
	_source_counts[source]=int(_source_counts.get(source,0))+1
	var next:=rect.intersection(get_viewport().get_visible_rect())
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
	_add(get_viewport().get_canvas_transform()*rect,source)

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

func _protection() -> void:
	_protect.clear();_source_counts.clear();_overflow=false;_danger_active=false
	for rect: Rect2 in _fixed_world:_world_rect(rect,"actual_static_geometry_and_functions")
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
			if not _visible(control):continue
			if control is TouchOverlay:_touch_protection(control as TouchOverlay)
			elif _drawn_control(control):_add((control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)).grow(8),"actual_visible_ui")
		elif node is CollisionShape2D:
			var collision:=node as CollisionShape2D
			if collision.disabled or collision.shape==null or not _visible(collision):continue
			var parent:=collision.get_parent() as CollisionObject2D
			if parent==null or parent.collision_layer==0:continue
			var rect: Rect2=collision.get_global_transform_with_canvas()*collision.shape.get_rect()
			if parent is StaticBody2D or parent is AnimatableBody2D:
				if maxf(rect.size.x,rect.size.y)>180:
					_add(Rect2(rect.position,Vector2(rect.size.x,1)).grow(10),"actual_platform_edge")
					_add(Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,1)).grow(10),"actual_platform_edge")
					_add(Rect2(rect.position,Vector2(1,rect.size.y)).grow(10),"actual_platform_edge")
					_add(Rect2(Vector2(rect.end.x,rect.position.y),Vector2(1,rect.size.y)).grow(10),"actual_platform_edge")
				else:_add(rect.grow(18),"actual_mechanism_or_platform")
			else:_add(rect.grow(44),"actual_actor_or_danger")
		elif node is EnemyActor:
			var enemy:=node as EnemyActor
			if enemy.health.terminal or not is_instance_valid(enemy.motor) or not _visible(enemy.motor):continue
			var zone:=Rect2(enemy.motor.global_position-Vector2(100,100),Vector2(200,200))
			_world_rect(zone,"enemy_and_warning")
			if enemy.attack_behavior!=null and enemy.attack_behavior.state in [&"telegraph",&"attack"] and (get_viewport().get_canvas_transform()*zone).intersects(get_viewport().get_visible_rect()):_danger_active=true
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

func _roll(category: String,x: int,y: int) -> int:
	# Avalanche the string hash: neighboring world cells must not become a
	# repeated diagonal sequence after the small placement moduli below.
	var value: int=(_seed+":"+category+":"+str(x)+":"+str(y)).hash()
	value=((value^(value>>16))*0x45d9f3b)&0xffffffff
	value=((value^(value>>16))*0x45d9f3b)&0xffffffff
	return posmod(value^(value>>16),1000000)

func _grass_candidate(found: Array[Dictionary],id: String,at: Vector2,roll: int,center: Vector2,size: Vector2) -> void:
	var screen: Vector2=(at-center)*PARALLAX+size*.5
	# A tall near reed is readable above the frame while its complete root
	# remains outside. The narrow visibility band prevents a fake standing edge.
	if screen.y<size.y+13 or screen.y>size.y+98:return
	var distance:=screen.y-size.y
	for height: float in [170.0+float((roll/97)%15),148.0+float(roll%9)]:
		found.append({"id":"%s/%d"%[id,int(height)],"asset":_assets[roll%3],"anchor_world":at,"screen":screen,"height":height,"fade":smoothstep(13,34,distance),"rank":absf(screen.x-size.x*.5)+(184.0-height)})

func _candidates(center: Vector2,size: Vector2) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	var home_floor: Variant=null
	if _world.get_script()!=null and str(_world.get_script().resource_path).ends_with("underworld_home_world.gd"):
		home_floor=_world.get("floor_y")
	for x: int in range(floori((center.x-size.x*.5/PARALLAX.x-360)/520),ceili((center.x+size.x*.5/PARALLAX.x+360)/520)+1):
		if home_floor!=null:
			var roll:=_roll("home_grass",x,0)
			if roll%100<72:
				var at:=Vector2(x*520+70+roll%380,float(home_floor)+236+(roll/480)%19)
				_grass_candidate(found,"home_grass/%d"%x,at,roll,center,size)
			continue
		for y: int in range(floori((center.y+size.y*.5/PARALLAX.y-120)/144),ceili((center.y+size.y*.5/PARALLAX.y+120)/144)+1):
			var roll:=_roll("grass",x,y)
			if roll%100>=62:continue
			var at:=Vector2(x*520+70+roll%380,y*144+24+(roll/480)%96)
			_grass_candidate(found,"grass/%d/%d"%[x,y],at,roll,center,size)
	# Several seeded attachment opportunities let actual HUD/route protection
	# select a different branch, rather than reducing the protection footprint.
	# These are world cells: walking/panning reveals gaps and different sides.
	# A 320wu horizontal lattice supplies side-entry opportunities even when
	# a whole wider cell falls between both screen edges. Lower occupancy keeps
	# quiet gaps; each opportunity is still a fixed world point, never a corner lock.
	for x: int in range(floori((center.x-size.x*.5/PARALLAX.x-340)/320),ceili((center.x+size.x*.5/PARALLAX.x+340)/320)+1):
		for y: int in range(floori((center.y-size.y*.5/PARALLAX.y)/112),ceili((center.y+size.y*.5/PARALLAX.y)/112)+1):
			var roll:=_roll("branch",x,y)
			if roll%100>=48:continue
			var at:=Vector2(x*320+40+roll%240,y*112+18+(roll/1200)%76)
			var screen: Vector2=(at-center)*PARALLAX+size*.5
			if screen.y<size.y*.15 or screen.y>size.y*.70:continue
			var left:=screen.x<=-13 and screen.x>=-260
			var right:=screen.x>=size.x+13 and screen.x<=size.x+260
			if not left and not right:continue
			var distance: float=-screen.x if left else screen.x-size.x
			# Alternatives share the same real hanging point. Each is tested
			# using its complete original image rectangle and 3wu wind margin.
			for width: float in [352.0,288.0,224.0]:
				found.append({"id":"branch/%d/%d/%d"%[x,y,int(width)],"asset":_assets[3 if left else 4],"anchor_world":at,"screen":screen,"width":width,"fade":smoothstep(13,38,distance),"rank":size.x+distance+absf(screen.y-size.y*.35)+(352.0-width)})
	found.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.rank)<float(b.rank))
	return found

func refresh() -> void:
	if _assets.size()!=5 or _sprites.size()!=3 or not is_instance_valid(_world) or not is_instance_valid(_actor):return
	for sprite: Sprite2D in _sprites:sprite.hide()
	_protection()
	var camera:=get_viewport().get_camera_2d()
	var center:=camera.get_screen_center_position() if camera!=null else _actor.global_position
	var size:=get_viewport().get_visible_rect().size
	var visible_items: Array[Dictionary]=[]
	var rejected: Array[Dictionary]=[]
	var grass_count:=0
	var branch_count:=0
	if not _overflow and not _danger_active:
		for candidate: Dictionary in _candidates(center,size):
			var asset: Dictionary=candidate.asset
			var branch: bool=str(asset.kind)=="branch"
			if (branch and branch_count>=1) or (not branch and grass_count>=2):continue
			var source_size: Vector2=asset.sample_size
			var source_attachment: Vector2=asset.sample_attachment
			var display_scale: float=float(candidate.width)/source_size.x if branch else float(candidate.height)/source_size.y
			var attachment:=source_attachment*display_scale
			var display_size:=source_size*display_scale
			var position: Vector2=(candidate.screen-attachment).round()
			var actual_anchor:=position+attachment
			var bounds:=Rect2(position,display_size)
			var clipped:=bounds.intersection(Rect2(Vector2.ZERO,size))
			var opacity:=float(candidate.fade)*.9
			if not bounds.intersects(Rect2(Vector2.ZERO,size)):continue
			var attachment_safe: bool=(actual_anchor.x<=-12 or actual_anchor.x>=size.x+12) if branch else actual_anchor.y>=size.y+12
			var reason:=""
			if not attachment_safe:reason="attachment_in_frame"
			elif opacity<MIN_OPACITY:reason="below_readable_opacity"
			elif clipped.get_area()<4800 or (branch and clipped.size.x<72) or (not branch and clipped.size.y<72):reason="insufficient_visible_extent"
			elif _protect.any(func(rect:Rect2)->bool:return bounds.grow(WIND_MARGIN).intersects(rect)):reason="actual_function_or_ui_overlap"
			elif visible_items.any(func(item:Dictionary)->bool:return bounds.grow(24).intersects(Rect2(Vector2(item.bounds[0],item.bounds[1]),Vector2(item.bounds[2],item.bounds[3])))):reason="foreground_spacing"
			if not reason.is_empty():rejected.append({"id":candidate.id,"reason":reason});continue
			var sprite:=_sprites[visible_items.size()]
			sprite.texture=_textures[str(asset.id)]
			sprite.position=position
			sprite.scale=Vector2.ONE*display_scale
			sprite.modulate=Color(1,1,1,opacity)
			var material:=sprite.material as ShaderMaterial
			material.set_shader_parameter("attachment",source_attachment)
			material.set_shader_parameter("art_size",source_size)
			material.set_shader_parameter("source_to_world",display_scale)
			material.set_shader_parameter("branch",branch)
			material.set_shader_parameter("wind_time",_wind_time)
			material.set_shader_parameter("wind_phase",float(_roll(str(candidate.id),0,0)%1000)*.01)
			sprite.show()
			if branch:branch_count+=1
			else:grass_count+=1
			visible_items.append({"id":candidate.id,"asset":asset.id,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"attachment":[actual_anchor.x,actual_anchor.y],"world_anchor":[candidate.anchor_world.x,candidate.anchor_world.y],"opacity":sprite.modulate.a,"display_scale":display_scale,"raw_crop":asset.raw_crop,"source":MASTER,"collision":false})
	var rectangles: Array=[]
	for rect: Rect2 in _protect:rectangles.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	_last={"schema":"underworld-foreground-runtime-v1","revision":"DEPTH-FRAME-06","parallax":[PARALLAX.x,PARALLAX.y],"minimum_visible_opacity":MIN_OPACITY,"layer":layer,"grid_wu":1,"seed":_seed,"camera":[center.x,center.y],"viewport":[size.x,size.y],"grass_count":grass_count,"branch_count":branch_count,"visible":visible_items,"rejected":rejected,"protection_count":_protect.size(),"protection_sources":_source_counts.duplicate(),"protection_rectangles":rectangles,"overflow_hidden":_overflow,"live_warning_hidden":_danger_active,"master_sha256":_build.master_sha256,"physics_mutation":false,"wind_time":_wind_time}

func receipt() -> Dictionary:
	return _last.duplicate(true)
