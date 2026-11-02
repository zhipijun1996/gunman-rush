class_name PlainsTerrainFamilySampler
extends RefCounted
## Actual union-aware presentation only. Original failed whole sources remain rejected.
const CONTRACT_PATH := "res://assets/region_production_v3/terrain_sampling_v1/contract_v2.json"
const CONTRACT_SHA := "5be47acdcbc1c69f22e8ac88dbdb4d653588a8965a8a5becb99fb5b37cf6b011"
const CLIFF := preload("res://assets/region_production_v3/spaces/limestone_bank_section_v1/source.png")
const PANEL := preload("res://assets/region_production_v3/spaces/suspended_mechanical_baffle_v1/source.png")
const SHADER := preload("res://shaders/plains_terrain_family.gdshader")
const CLIFF_SHA := "02e7832d5a4a9238af1ac307d4f4688c22ea7927cf88eb99f56a126a13d404db"
const PANEL_SHA := "1dbd25214b1ff0eee3f0e4fbf807afeac4fa96307302730ffd9a9ca520824e48"
# Remains one semantic representative per map until actual independent GPU admission.
const PROMOTE_APPLICABLE := false

static func boundary(solids:Array[Rect2])->PackedVector4Array:
	var unique:Dictionary={}
	for rect:Rect2 in solids:
		for face:Dictionary in PlainsTerrainBorders.plan(rect,solids).faces:
			var a:Vector2=face.start;var b:Vector2=face.finish
			if face.side in ["bottom","left"]:var swap:=a;a=b;b=swap
			unique[Vector4(a.x,a.y,b.x,b.y)]=true
	return PlainsTileComposer.merge_edges(PackedVector4Array(unique.keys()))

static func groups(solids:Array[Rect2])->Array[Dictionary]:
	var remaining:=solids.duplicate()
	remaining.sort_custom(func(a:Rect2,b:Rect2)->bool:return a.position.x<b.position.x if a.position.x!=b.position.x else a.position.y<b.position.y)
	var result:Array[Dictionary]=[]
	while not remaining.is_empty():
		var parts:Array[Rect2]=[remaining.pop_front()]
		var pending:=true
		while pending:
			pending=false
			for i:int in range(remaining.size()-1,-1,-1):
				var candidate:Rect2=remaining[i]
				for member:Rect2 in parts:
					if member.intersects(candidate,true):parts.append(candidate);remaining.remove_at(i);pending=true;break
		var bounds:=parts[0]
		for rect:Rect2 in parts:bounds=bounds.merge(rect)
		result.append({"parts":parts,"bounds":bounds,"faces":boundary(parts)})
	return result

static func inventory(stage:Node2D)->Dictionary:
	var rooted:Array[Rect2]=[];var floating:Array[Dictionary]=[];var one_way:Array[Dictionary]=[];var static_rows:Array[Dictionary]=[]
	for module:PlatformingModule in stage.assembler.modules:
		for index:int in module.definition.platforms.size():
			var rect:=Rect2(module.position+module.definition.platforms[index].position,module.definition.platforms[index].size)
			var row:Dictionary={"rect":rect,"module_path":str(module.get_path()),"platform_index":index}
			if index in module.definition.one_way_platform_indices:one_way.append(row)
			else:static_rows.append(row)
	var columns:Array[Rect2]=[]
	if is_instance_valid(stage.assembler.ground_supports):columns=stage.assembler.ground_supports.columns.duplicate()
	var all_static:Array[Rect2]=columns.duplicate()
	for row:Dictionary in static_rows:all_static.append(row.rect)
	# Actual current region manifests can omit the old floating-index-version key.
	# Real connected solid union + actual foundation wins over an empty legacy hint.
	for group:Dictionary in groups(all_static):
		var attached:=false
		for rect:Rect2 in group.parts:
			if rect in columns:attached=true;break
		if attached:rooted.append_array(group.parts)
		else:
			for row:Dictionary in static_rows:
				if row.rect in group.parts:floating.append(row)
	return {"rooted":rooted,"floating":floating,"one_way":one_way,"columns":columns}

static func _move_children(source:Node2D,target:Node2D)->void:
	for child:Node in source.get_children():source.remove_child(child);target.add_child(child)
	source.free()

static func _eligible(group:Dictionary,columns:Array[Rect2])->bool:
	var bounds:Rect2=group.bounds
	if bounds.size.x<96 or bounds.size.y<64 or group.faces.size()>64:return false
	# A real generated ground column establishes rooted semantic; a floating slab never does.
	for rect:Rect2 in group.parts:
		if rect in columns:return true
	return false

static func _cliff(group:Dictionary,protected:Array[Rect2])->Node2D:
	var node:=PlainsTileComposer.build_rectangles(group.parts)
	if node==null:return null
	for quad:ColorRect in node.get_children():
		var old:=quad.material as ShaderMaterial
		var material:=ShaderMaterial.new();material.shader=SHADER
		for name:String in ["painted_material","painted_border","canonical_cells","face_count","faces","corner_count","outer_corners","shape_origin"]:
			material.set_shader_parameter(name,old.get_shader_parameter(name))
		material.set_shader_parameter("family_paint",CLIFF)
		quad.material=material;quad.set_meta("expected_face_count",material.get_shader_parameter("face_count"));quad.set_meta("family_source",CLIFF.resource_path);quad.set_meta("family_use","limestone_union_core")
	# Outward bands belong to actual exposed faces, never to original authoring rectangles.
	for edge:Vector4 in group.faces:
		var a:=Vector2(edge.x,edge.y);var b:=Vector2(edge.z,edge.w);var ab:=b-a
		if ab.x>0:continue # approved grass/standing plane remains unchanged
		var inward:=Vector2.RIGHT if ab.y<0 else Vector2.LEFT if ab.y>0 else Vector2.UP
		if not PlainsTerrainBorders.occupied((a+b)/2+inward*63.99,group.parts):continue
		var limit:=10.0 if ab.x<0 else 3.0
		if ab.x<0:
			for other:Rect2 in protected:
				if other in group.parts:continue
				if other.position.y>=a.y and other.position.y-a.y<96 and other.end.x>minf(a.x,b.x)-16 and other.position.x<maxf(a.x,b.x)+16:limit=minf(3.0,(other.position.y-a.y)/4.0)
		var rect:Rect2
		if ab.y<0:rect=Rect2(a.x-limit,b.y,limit,ab.length())
		elif ab.y>0:rect=Rect2(a.x,a.y,limit,ab.length())
		else:rect=Rect2(b.x,a.y,ab.length(),limit)
		var material:=ShaderMaterial.new();material.shader=SHADER
		material.set_shader_parameter("family_paint",CLIFF)
		material.set_shader_parameter("painted_material",PlainsTileComposer.PAINT)
		material.set_shader_parameter("painted_border",PlainsTileComposer.BORDER)
		material.set_shader_parameter("canonical_cells",false)
		material.set_shader_parameter("outside_only",true)
		material.set_shader_parameter("outward_limit",limit)
		var faces:=PackedVector4Array([edge]);faces.resize(64)
		material.set_shader_parameter("faces",faces);material.set_shader_parameter("face_count",1)
		var quad:=PlainsTileComposer.paint_quad(rect,material)
		quad.set_meta("family_source",CLIFF.resource_path);quad.set_meta("family_use","limestone_exposed_fringe")
		node.add_child(quad)
	return node

static func _panel(rect:Rect2)->Node2D:
	var node:=Node2D.new();node.name="SampledSuspendedStoneCopper"
	for source:Rect2 in [Rect2(0,103,972,728),Rect2(0,1242,972,377)]:
		var atlas:=AtlasTexture.new();atlas.atlas=PANEL;atlas.region=source;atlas.filter_clip=true
		var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale=Vector2.ONE/9.0
		var y:=103.0 if source.position.y==103 else 831.0
		sprite.position=rect.position+Vector2(-379,y-130)/9.0
		sprite.set_meta("family_use","suspended_cap_body");sprite.set_meta("family_source",PANEL.resource_path)
		node.add_child(sprite)
	node.set_meta("physical_rect",rect)
	return node

static func build(stage:Node2D,all_solids:Array[Rect2])->Node2D:
	if "--legacy-waterworks-contract" in OS.get_cmdline_user_args():return PlainsTileComposer.build_rectangles(all_solids)
	var result:=Node2D.new();result.name="TerrainFamilyComposite"
	var data:=inventory(stage)
	var rooted_groups:=groups(data.rooted)
	var merchant:=Vector2.ZERO
	for area:Dictionary in stage.generated.manifest.get("areas",[]):
		if str(area.id)==str(stage.generated.manifest.get("merchant_id","")):merchant=Vector2(float(area.position[0]),float(area.position[1]));break
	var chosen:Dictionary={};var distance:=INF
	for group:Dictionary in rooted_groups:
		if not _eligible(group,data.columns):continue
		var bounds:Rect2=group.bounds
		var d:=bounds.get_center().distance_to(merchant)
		if d<distance:chosen=group;distance=d
	var entries:Array[Dictionary]=[];var omitted:Array[Dictionary]=[]
	var protected:Array[Rect2]=all_solids.duplicate()
	for row:Dictionary in data.one_way:protected.append(row.rect)
	for group:Dictionary in rooted_groups:
		var admitted:=_eligible(group,data.columns) and (PROMOTE_APPLICABLE or group==chosen)
		var art:=_cliff(group,protected) if admitted else PlainsTileComposer.build_rectangles(group.parts)
		if art==null:result.free();return PlainsTileComposer.build_rectangles(all_solids)
		_move_children(art,result)
		var bounds:Rect2=group.bounds
		if admitted:entries.append({"kind":"rooted_union","bounds":bounds,"parts":group.parts,"faces":group.faces,"source":CLIFF.resource_path,"source_sha256":CLIFF_SHA,"uniform_scale":.15,"phase":"one_semantic_pilot" if not PROMOTE_APPLICABLE else "admitted_form_range"})
		else:omitted.append({"kind":"rooted_baseline","bounds":bounds,"reason":"not_representative_yet" if _eligible(group,data.columns) else "thin_or_no_real_root_column_or_boundary_budget"})
	var panel_used:=false
	for row:Dictionary in data.floating:
		var rect:Rect2=row.rect
		if rect.size==Vector2(24,110) and (PROMOTE_APPLICABLE or not panel_used):
			var art:=_panel(rect);result.add_child(art);panel_used=true
			entries.append({"kind":"suspended_panel","bounds":rect,"module_path":row.module_path,"platform_index":row.platform_index,"source":PANEL.resource_path,"source_sha256":PANEL_SHA,"uniform_scale":1.0/9.0,"top_region":[0,103,972,728],"bottom_region":[0,1242,972,377]})
		else:
			var parts:Array[Rect2]=[rect];var art:=PlainsTileComposer.build_rectangles(parts)
			if art!=null:_move_children(art,result)
			omitted.append({"kind":"floating_baseline","bounds":rect,"reason":"missing_admitted_width_height_caps"})
	result.set_meta("family_entries",entries);result.set_meta("family_omitted",omitted)
	result.set_meta("one_way_baseline_count",data.one_way.size())
	result.set_meta("contract_sha256",CONTRACT_SHA)
	return result

static func actual_issues(art:Node2D)->Array[String]:
	var issues:Array[String]=[]
	if FileAccess.get_sha256(CONTRACT_PATH)!=CONTRACT_SHA:issues.append("sampling_contract_changed")
	if FileAccess.get_sha256(CLIFF.resource_path)!=CLIFF_SHA or FileAccess.get_sha256(PANEL.resource_path)!=PANEL_SHA:issues.append("sampling_source_changed")
	for entry:Dictionary in art.get_meta("family_entries",[]):
		if entry.kind=="suspended_panel" and entry.bounds.size!=Vector2(24,110):issues.append("panel_physical_frame_unsupported")
	for child:Node in art.get_children():
		if child is ColorRect and child.has_meta("family_use"):
			var mat:=child.material as ShaderMaterial
			if mat==null or mat.shader!=SHADER:issues.append("actual_family_shader_changed")
			elif mat.get_shader_parameter("family_paint")!=CLIFF:issues.append("actual_family_texture_changed")
			elif child.has_meta("expected_face_count") and mat.get_shader_parameter("face_count")!=child.get_meta("expected_face_count"):issues.append("actual_union_boundaries_changed")
		if child.name.begins_with("SampledSuspendedStoneCopper"):
			var physical:Rect2=child.get_meta("physical_rect")
			for i:int in child.get_child_count():
				var sprite:=child.get_child(i) as Sprite2D
				var source:=Rect2(0,103,972,728) if i==0 else Rect2(0,1242,972,377)
				var y:=103.0 if i==0 else 831.0
				if not sprite.global_position.is_equal_approx(art.global_position+physical.position+Vector2(-379,y-130)/9.0):issues.append("actual_panel_detached_or_gap_fill")
				if sprite.scale!=Vector2.ONE/9.0:issues.append("actual_panel_scale_changed")
				if not sprite.texture is AtlasTexture or not (sprite.texture as AtlasTexture).filter_clip:issues.append("actual_panel_atlas_unclipped")
				elif (sprite.texture as AtlasTexture).atlas!=PANEL:issues.append("actual_panel_texture_changed")
				elif (sprite.texture as AtlasTexture).region!=source:issues.append("actual_panel_source_region_changed")
	return issues
