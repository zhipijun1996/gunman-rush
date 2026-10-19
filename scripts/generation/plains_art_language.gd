class_name PlainsArtLanguage
extends RefCounted
## Candidate module and world construction grammar, selected before embedding.
## Definitions own operation dimensions; the catalog owns visual expression limits.
const CATALOG := "res://resources/generation/plains_art_language.json"
const VERSION := "plains-art-language-v1"

static func catalog() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return raw if raw is Dictionary else {}

static func plan_recipe(recipe: Dictionary, identity: String, edge_id: String) -> Dictionary:
	var data := catalog()
	if data.is_empty(): return _failure("Missing actual art-language catalog")
	var modules: Array = []
	var width := 0.0
	var quiet := 0.0
	for module_id: String in recipe.get("modules",[]):
		var definition := RandomStageGenerator.new().definition_for(module_id,false,false)
		if definition == null: return _failure("Unknown operation Definition: "+module_id)
		var planned := plan_definition(definition, str(data.module_families.get(module_id,"")), edge_id+"/"+str(modules.size()))
		if not planned.ok: return planned
		if not modules.is_empty():
			var joint := compatibility(modules[-1],planned)
			if not joint.ok: return joint
		modules.append(planned)
		width += float(planned.size_spec.operation_width)
		quiet = maxf(quiet,float(planned.clearance.quiet_arrival_width))
	if modules.is_empty(): return _failure("Recipe contains no expressible operation modules")
	var shoulder := maxf(float(modules[0].assembly.shoulder_width),float(modules[-1].assembly.shoulder_width))
	return {"ok":true,"version":VERSION,"id":edge_id+"/art_language","recipe_id":recipe.get("id",""),"identity":identity,"modules":modules,"operation_width":width,"minimum_expression_width":width+2.0*shoulder,"quiet_arrival_width":quiet,"source_order":"art_construction_and_action_definition_before_embedding","asset_readiness":data.asset_readiness.duplicate(true)}

static func plan_definition(definition: PlatformingModuleDefinition, family_id: String, unit_id: String) -> Dictionary:
	var data := catalog()
	if definition == null or not data.get("families",{}).has(family_id): return _failure("No registered art family for operation module")
	var actual := RandomStageGenerator.new().definition_for(str(definition.module_id),false,false)
	if actual == null or JSON.stringify(RandomStageGenerator.new()._resource_data(actual),"",true)!=JSON.stringify(RandomStageGenerator.new()._resource_data(definition),"",true): return _failure("Operation Definition changed without a registered joint redesign")
	if str(data.module_families.get(str(definition.module_id),""))!=family_id: return _failure("Operation module is not registered to this structural family")
	var size_id := ""
	for key: String in data.width_specs:
		if float(data.width_specs[key]) == definition.world_bounds.size.x: size_id = key
	if size_id.is_empty(): return _failure("Operation width has no finite art specification: "+str(definition.module_id))
	var family: Dictionary = data.families[family_id]
	var depth_id := str(family.body_depth_spec)
	var source := "res://resources/generation/modules/%s.tres" % str(definition.module_id)
	var platforms: Array = []
	for index: int in definition.platforms.size():
		var surface := _surface_expression(definition,index,family_id,data)
		if not surface.ok: return surface
		platforms.append(surface)
	var planned := {"ok":true,"version":VERSION,"id":unit_id,"module_id":str(definition.module_id),"family_id":family_id,"definition_source":source,"definition_sha256":FileAccess.get_sha256(source),"definition_content_hash":RandomStageGenerator.new().content_hash(str(definition.module_id)),"size_spec":{"id":size_id,"operation_width":definition.world_bounds.size.x,"operation_height":definition.world_bounds.size.y,"visual_body_depth_spec":depth_id,"visual_body_depth":float(data.body_depth_specs[depth_id]),"collision_thickness_is_not_visual_depth":true},"assembly":{"construction":family.construction,"contour":family.contour,"support":family.support,"material_family":family.material_family,"shoulder_width":float(family.shoulder_width),"pixels_per_world_unit":float(data.world_grammar.material_pixels_per_world_unit),"scale":1.0,"allow_free_floating_rock":false,"platforms":platforms,"moving_mechanisms":"preserve_definition_motion_and_envelopes"},"ports":{"entry":_port(definition.entry_port),"exit":_port(definition.exit_port),"boundary":data.interfaces.common_boundary,"connection_mode":data.interfaces.connection_mode},"clearance":{"quiet_arrival_width":float(family.quiet_arrival_width),"operation_envelopes":"existing_definition_hazards_ferries_and_motor_airspace","do_not_occlude_standing_surface":true},"asset_readiness":family.asset_readiness,"scope":"renderable_design_with_existing_physics_unchanged"}
	var errors := expression_errors(planned)
	return _failure("Invalid module art expression: "+str(errors)) if not errors.is_empty() else planned

static func plan_generated(node: Dictionary) -> Dictionary:
	var data:=catalog()
	var module_id:=str(node.get("module_id",""))
	if not data.get("generated_module_families",{}).has(module_id):return _failure("Generated module type has no admitted art-language interface")
	if str(node.get("id","")).is_empty() or not node.get("geometry",null) is Dictionary or not node.get("offset",null) is Array:return _failure("Generated art requires an actual node identity geometry and offset")
	var offset: Array=node.offset
	if offset.size()!=2 or not _finite_numeric_array(offset):return _failure("Generated node offset must be finite")
	if node.get("mirrored",false) or node.get("reverse_traversal",false):return _failure("Generated inline reflection needs a separately registered interface")
	var geometry: Dictionary=node.geometry
	if not geometry.get("bounds",null) is Array or not geometry.get("platforms",null) is Array or not geometry.get("one_way",null) is Array:return _failure("Generated geometry requires bounds platforms and one-way ownership")
	var bounds: Array=geometry.bounds
	if bounds.size()!=4 or not _finite_numeric_array(bounds) or float(bounds[2])<=0.0 or float(bounds[3])<=0.0:return _failure("Generated bounds must be a finite positive rectangle")
	# This expansion owns only the existing plain-floor junction and connector.
	# Shafts, ferries, tutorials and newly invented inline geometries remain out.
	if geometry.platforms.size()!=1 or not geometry.platforms[0] is Array or geometry.platforms[0].size()!=4 or not _finite_numeric_array(geometry.platforms[0]):return _failure("Generated floor interface requires exactly one actual contact rectangle")
	var rect: Array=geometry.platforms[0]
	if float(rect[2])<=0.0 or float(rect[3])<=0.0 or float(rect[3])>=float(rect[2]):return _failure("Generated floor must retain a horizontal contact cross-section")
	if not geometry.get("ferries",[]) is Array or not geometry.get("ferries",[]).is_empty():return _failure("Generated floor interface does not own moving mechanisms")
	if bool(geometry.get("junction",false))!=(module_id=="region_junction"):return _failure("Generated junction identity does not match the source geometry")
	for index: Variant in geometry.one_way:
		if not index is int and not index is float:return _failure("Generated one-way ownership must use actual platform indices")
		if float(index)!=0.0:return _failure("Generated one-way ownership references a missing platform")
	if geometry.has("standing_margin") and (not geometry.standing_margin is int and not geometry.standing_margin is float):return _failure("Generated standing margin must remain numeric")
	var definition:=PlainsRegionGenerator.definition(node)
	if not definition.is_valid():return _failure("Generated source Definition violates the existing physical contract")
	var family_id:=str(data.generated_module_families[module_id])
	var family: Dictionary=data.families[family_id]
	var platforms: Array=[]
	for index: int in definition.platforms.size():
		var surface:=_surface_expression(definition,index,family_id,data)
		if not surface.get("ok",false):return surface
		platforms.append(surface)
	var depth_id:=str(family.body_depth_spec)
	var source_hash:=JSON.stringify(RandomStageGenerator.new()._canonical(geometry),"",true).sha256_text()
	return {"ok":true,"version":VERSION,"id":str(node.id)+"/art_language","module_id":module_id,"family_id":family_id,"source_kind":"generated_inline","source_node_id":str(node.id),"source_offset":offset.duplicate(),"source_geometry_hash":source_hash,"definition_source":"manifest_node_geometry","definition_sha256":source_hash,"definition_content_hash":JSON.stringify(RandomStageGenerator.new()._canonical(RandomStageGenerator.new()._resource_data(definition)),"",true).sha256_text(),"source_order":"connection_source_and_art_before_scene_instantiation","size_spec":{"kind":"bounded_part_assembly_span","operation_width":definition.world_bounds.size.x,"operation_height":definition.world_bounds.size.y,"visual_body_depth_spec":depth_id,"visual_body_depth":float(data.body_depth_specs[depth_id]),"collision_thickness_is_not_visual_depth":true},"assembly":{"construction":family.construction,"contour":family.contour,"support":family.support,"material_family":family.material_family,"shoulder_width":float(family.shoulder_width),"pixels_per_world_unit":float(data.world_grammar.material_pixels_per_world_unit),"scale":1.0,"allow_free_floating_rock":false,"platforms":platforms,"moving_mechanisms":"existing_generated_floor_has_no_mechanism"},"ports":{"entry":_port(definition.entry_port),"exit":_port(definition.exit_port),"boundary":data.interfaces.common_boundary,"connection_mode":data.interfaces.connection_mode},"clearance":{"quiet_arrival_width":float(family.quiet_arrival_width),"operation_envelopes":"existing_generated_floor_contract","do_not_occlude_standing_surface":true},"asset_readiness":family.asset_readiness,"scope":"generated_floor_dimension_contract_pending_painted_parts"}

static func _finite_numeric_array(values: Array) -> bool:
	for value: Variant in values:
		if not value is int and not value is float:return false
		if not is_finite(float(value)):return false
	return true

static func expression_errors(expression: Dictionary, source_node: Dictionary = {}) -> Array:
	if expression.get("source_kind","")=="generated_inline":
		if source_node.is_empty():return ["missing_external_generated_source"]
		var expected:=plan_generated(source_node)
		if not expected.get("ok",false):return ["invalid_external_generated_source"]
		return [] if JSON.stringify(RandomStageGenerator.new()._canonical(expected),"",true)==JSON.stringify(RandomStageGenerator.new()._canonical(expression),"",true) else ["generated_source_or_expression_drift"]
	var errors: Array = []
	var data := catalog()
	var family_id := str(expression.get("family_id",""))
	if not data.families.has(family_id): return ["unregistered_family"]
	var spec: Dictionary = expression.get("size_spec",{})
	if not data.width_specs.has(str(spec.get("id",""))) or float(data.width_specs.get(str(spec.get("id","")),-1))!=float(spec.get("operation_width",-2)): errors.append("unregistered_size")
	var assembly: Dictionary = expression.get("assembly",{})
	if float(assembly.get("scale",0.0))!=1.0: errors.append("unregistered_stretch")
	if assembly.get("allow_free_floating_rock",true) or assembly.get("support","")!=data.families[family_id].support: errors.append("unsupported_structure")
	if assembly.get("contour","")!=data.families[family_id].contour: errors.append("unregistered_contour")
	var family: Dictionary=data.families[family_id]
	if assembly.get("construction","")!=family.construction or assembly.get("material_family","")!=family.material_family or float(assembly.get("shoulder_width",-1))!=float(family.shoulder_width): errors.append("unregistered_assembly")
	if str(spec.get("visual_body_depth_spec",""))!=str(family.body_depth_spec) or float(spec.get("visual_body_depth",-1))!=float(data.body_depth_specs[family.body_depth_spec]): errors.append("unregistered_body_depth")
	var module_id:=str(expression.get("module_id",""))
	if str(data.module_families.get(module_id,""))!=family_id: errors.append("module_family_drift")
	var actual:=RandomStageGenerator.new().definition_for(module_id,false,false)
	if actual==null: errors.append("missing_definition")
	else:
		var source:="res://resources/generation/modules/%s.tres" % module_id
		if expression.get("definition_source","")!=source or expression.get("definition_sha256","")!=FileAccess.get_sha256(source) or expression.get("definition_content_hash","")!=RandomStageGenerator.new().content_hash(module_id): errors.append("definition_source_drift")
		if float(spec.get("operation_width",-1))!=actual.world_bounds.size.x or float(spec.get("operation_height",-1))!=actual.world_bounds.size.y: errors.append("definition_dimensions_drift")
		var surfaces: Array=assembly.get("platforms",[])
		if surfaces.size()!=actual.platforms.size(): errors.append("surface_ownership_drift")
		else:
			for index: int in surfaces.size():
				var expected:=_surface_expression(actual,index,family_id,data)
				if not expected.get("ok",false) or JSON.stringify(expected,"",true)!=JSON.stringify(surfaces[index],"",true): errors.append("surface_construction_drift")

	var ports: Dictionary = expression.get("ports",{})
	if ports.get("boundary","")!=data.interfaces.common_boundary or ports.get("connection_mode","")!=data.interfaces.connection_mode: errors.append("unregistered_interface")
	if actual!=null and (ports.get("entry",{})!=_port(actual.entry_port) or ports.get("exit",{})!=_port(actual.exit_port)): errors.append("operation_port_drift")
	return errors

static func compatibility(left: Dictionary, right: Dictionary) -> Dictionary:
	if not expression_errors(left).is_empty() or not expression_errors(right).is_empty(): return _failure("Invalid neighbor art expression")
	if left.ports.boundary!=right.ports.boundary: return _failure("Incompatible terrain cross-section interfaces")
	var left_exit: Array = left.ports.exit.position
	var left_entry: Array = left.ports.entry.position
	var delta := float(left_exit[1])-float(left_entry[1])
	if absf(delta)>float(catalog().interfaces.maximum_height_step): return _failure("Recipe needs a registered height transition, not a stretched end")
	return {"ok":true,"connection_mode":left.ports.connection_mode,"preserve_operation_ports":true}

static func plan_world_intent(manifest: Dictionary) -> Dictionary:
	var data := catalog()
	if data.is_empty() or manifest.get("areas",[]).is_empty(): return _failure("No topology for world art intent")
	if not manifest.get("nodes",[]).is_empty(): return _failure("World art intent must precede module instantiation")
	for area: Dictionary in manifest.areas:
		if not area.has("id") or not area.has("row") or not area.has("col") or not area.get("position",null) is Array: return _failure("World art intent requires topology id row col and position")
		var position: Array=area.get("position",[])
		if position.size()!=2 or float(position[0])!=0.0 or float(position[1])!=0.0: return _failure("World art intent must precede area coordinate embedding")
	var columns: Dictionary = {}
	var minimum_span := float(data.world_grammar.minimum_column_span)
	var minimum_spans: Dictionary = {}
	for area: Dictionary in manifest.areas:
		var col := int(area.col)
		if not columns.has(col): columns[col]={"col":col,"area_ids":[],"top_area_id":str(area.id),"bottom_area_id":str(area.id),"top_row":int(area.row),"bottom_row":int(area.row),"edge_ids":[]}
		minimum_spans[str(col)]=minimum_span
		columns[col].area_ids.append(str(area.id))
		if int(area.row)<int(columns[col].top_row): columns[col].top_row=int(area.row);columns[col].top_area_id=str(area.id)
		if int(area.row)>int(columns[col].bottom_row): columns[col].bottom_row=int(area.row);columns[col].bottom_area_id=str(area.id)
	for edge: Dictionary in manifest.connections:
		if str(edge.kind)!="horizontal": continue
		var expression: Dictionary=edge.get("art_language",{})
		if not expression.get("ok",false): return _failure("World intent requires every horizontal recipe art plan before embedding")
		var col := _area_col(manifest,str(edge.a))
		if not columns.has(col): return _failure("Recipe has no topology column")
		columns[col].edge_ids.append(str(edge.id))
		minimum_spans[str(col)]=maxf(float(minimum_spans[str(col)]),float(expression.minimum_expression_width)+float(expression.quiet_arrival_width)+400.0)
	var keys: Array=columns.keys();keys.sort()
	var masses: Array=[]
	var valleys: Array=[]
	var stream:=RunRandomStream.new(str(manifest.seed),"region_art_language","world_intent",VERSION)
	var at:=0
	while at<keys.size():
		var count:=2 if at+2<keys.size() and int(keys[at+1])==int(keys[at])+1 and stream.next_int(2)==1 else 1
		var column: Dictionary=columns[keys[at]].duplicate(true)
		column.columns=[]
		column.lower_area_ids=[]
		column.upper_area_ids=[]
		for offset: int in count:
			var other: Dictionary=columns[keys[at+offset]]
			column.columns.append(int(other.col))
			column.lower_area_ids.append(str(other.bottom_area_id))
			column.upper_area_ids.append(str(other.top_area_id))
			if offset>0:
				column.area_ids.append_array(other.area_ids)
				column.edge_ids.append_array(other.edge_ids)
				if int(other.top_row)<int(column.top_row): column.top_row=other.top_row;column.top_area_id=other.top_area_id
				if int(other.bottom_row)>int(column.bottom_row): column.bottom_row=other.bottom_row;column.bottom_area_id=other.bottom_area_id
		column.id="massif/columns_"+str(keys[at])+"_"+str(keys[at+count-1])
		column.kind="finite_meadow_massif"
		column.contour_variant=stream.next_int(int(data.world_grammar.contour_variants))
		column.material_family="rear_chalk"
		column.formation="shared_cross_column_ridge" if count>1 else "finite_outcrop"
		masses.append(column)
		at+=count
	for index: int in range(maxi(0,masses.size()-1)):
		valleys.append({"id":"valley/"+str(index),"kind":"exterior_air_corridor","left_massif_id":masses[index].id,"right_massif_id":masses[index+1].id,"minimum_width":float(data.world_grammar.minimum_open_valley_width),"occlusion_policy":"no_massif_fill","continues_to":"exterior_sky_below_and_above_finite_formation"})
	return {"ok":true,"version":VERSION,"catalog_sha256":FileAccess.get_sha256(CATALOG),"source_order":"topology_recipe_and_art_intent_before_world_coordinates","minimum_column_span":minimum_span,"minimum_column_spans":minimum_spans,"massifs":masses,"open_valleys":valleys,"grammar":data.world_grammar.duplicate(true),"asset_readiness":data.asset_readiness.duplicate(true),"physics":"unchanged_definition_projection"}

static func resolve_world(intent: Dictionary, manifest: Dictionary) -> Dictionary:
	if not intent.get("ok",false): return _failure("Cannot resolve rejected world intent")
	if not manifest.get("nodes",[]).is_empty(): return _failure("World art resolution must precede module instantiation")
	var column_positions: Dictionary={}
	for area: Dictionary in manifest.get("areas",[]):
		if not area.has("id") or not area.has("row") or not area.has("col") or not area.get("position",null) is Array: return _failure("World art resolution requires topology id row col and position")
		var position: Array=area.get("position",[])
		if position.size()!=2 or not is_finite(float(position[0])) or not is_finite(float(position[1])): return _failure("World art resolution requires finite area coordinates")
		var col:=int(area.col)
		if column_positions.has(col) and float(column_positions[col])!=float(position[0]): return _failure("A topology column has inconsistent horizontal embedding")
		column_positions[col]=float(position[0])
	var ordered_columns: Array=column_positions.keys();ordered_columns.sort()
	if ordered_columns.is_empty():return _failure("World art resolution requires embedded columns")
	for index: int in ordered_columns.size():
		if int(ordered_columns[index])!=index:return _failure("World art resolution requires contiguous topology columns")
		if index>0 and float(column_positions[ordered_columns[index]])<=float(column_positions[ordered_columns[index-1]]):return _failure("Horizontal embedding must be strictly ordered and non-overlapping")
	var masses: Array=[]
	var lookup: Dictionary={}
	var grammar: Dictionary=intent.grammar
	var xs: Array=[]
	for area: Dictionary in manifest.areas:
		var x:=float(area.position[0])
		if x not in xs:xs.append(x)
	xs.sort()
	for source: Dictionary in intent.massifs:
		var upper:=_area_position(manifest,str(source.top_area_id))
		var lower:=_area_position(manifest,str(source.bottom_area_id))
		var first_col:=int(source.columns[0])
		var last_col:=int(source.columns[-1])
		var left_span:=float(intent.minimum_column_span)
		var right_span:=left_span
		if first_col>0:left_span=float(xs[first_col])-float(xs[first_col-1])
		elif xs.size()>1:left_span=float(xs[1])-float(xs[0])
		if last_col+1<xs.size():right_span=float(xs[last_col+1])-float(xs[last_col])
		elif last_col>0:right_span=float(xs[last_col])-float(xs[last_col-1])
		var left:=float(xs[first_col])-left_span*float(grammar.massif_half_width_fraction)
		var right:=float(xs[last_col])+right_span*float(grammar.massif_half_width_fraction)
		var center:=(left+right)*0.5
		var half:=(right-left)*0.5
		var top:=upper.y-float(grammar.camera_clearance)
		var bottom:=lower.y+float(grammar.massif_root_depth)
		var peak:=float(grammar.ridge_peak_height)*(0.8+0.2*float(source.contour_variant))
		var ridge: Array=[[left,top+100.0],[left+half*0.28,top+32.0],[left+half*0.72,top-peak],[center+half*0.18,top-peak*0.72],[right-half*0.25,top+8.0],[right,top+128.0]]
		var points:=ridge.duplicate(true)
		points.append_array([[right-half*0.10,bottom-120.0],[center+half*0.45,bottom],[center-half*0.55,bottom-32.0],[left+half*0.12,bottom-150.0]])
		var mass: Dictionary=source.duplicate(true)
		mass.points=points;mass.ridge_line=ridge;mass.source_area_ids=source.area_ids.duplicate();mass.source_edge_ids=source.edge_ids.duplicate()
		mass.layer="rear_landform";mass.collision=false;mass.assembly={"method":"finite_closed_massif_polygon","no_rectangle_hole_subtraction":true,"pixels_per_world_unit":float(grammar.material_pixels_per_world_unit),"world_material_origin":[0.0,0.0]}
		mass.bounds=[left,top-peak,right-left,bottom-(top-peak)]
		masses.append(mass);lookup[mass.id]=mass
	var valleys: Array=[]
	for source: Dictionary in intent.open_valleys:
		var left: Dictionary=lookup[source.left_massif_id]
		var right: Dictionary=lookup[source.right_massif_id]
		var x0:=float(left.bounds[0])+float(left.bounds[2])
		var x1:=float(right.bounds[0])
		if x1-x0<float(source.minimum_width):return _failure("Embedding cannot express registered open valley width")
		var top:=minf(float(left.bounds[1]),float(right.bounds[1]))-float(grammar.camera_clearance)
		var bottom:=maxf(float(left.bounds[1])+float(left.bounds[3]),float(right.bounds[1])+float(right.bounds[3]))+float(grammar.camera_clearance)
		var valley: Dictionary=source.duplicate(true)
		valley.points=[[x0,top],[x1,top],[x1,bottom],[x0,bottom]]
		valley.source_area_ids=left.source_area_ids+right.source_area_ids
		valleys.append(valley)
	return {"ok":true,"version":VERSION,"catalog_sha256":intent.catalog_sha256,"intent":intent.duplicate(true),"finite_landforms":masses,"open_valleys":valleys,"asset_requirements":catalog().families.duplicate(true),"asset_readiness":intent.asset_readiness.duplicate(true),"coverage":{"world_topology_area_count":manifest.areas.size(),"finite_massif_count":masses.size(),"spatial_resolution":"coarse_one_or_two_column_finite_formations_not_full_geological_solver","front_physics":"existing_definition_unchanged","front_visual":"legacy_projection_pending_registered_painted_family","whole_region_art_admitted":false},"design_debug_not_art_admission":true,"geometry_source":"topology_art_intent_resolved_before_module_instantiation"}

static func _surface_expression(definition: PlatformingModuleDefinition, index: int, family_id: String, data: Dictionary) -> Dictionary:
	var rect: Rect2=definition.platforms[index]
	var family: Dictionary=data.families[family_id]
	var contact_y:=INF
	for contact: Rect2 in definition.platforms:
		if definition.entry_port.position.x>=contact.position.x and definition.entry_port.position.x<=contact.end.x and contact.position.y>=definition.entry_port.position.y: contact_y=minf(contact_y,contact.position.y)
	if not is_finite(contact_y): return _failure("Entry port has no registered contact surface")
	var role:="grounded_bank"
	if index in definition.one_way_platform_indices: role="supported_one_way_walkway"
	elif rect.size.y>=rect.size.x: role="vertical_wall"
	elif rect.position.y<contact_y-1.0: role="supported_lintel" if family_id=="repair_masonry" else "rooted_upper_outcrop"
	var role_spec: Dictionary=data.part_grammar.role_specs[role]
	var axis:=str(role_spec.axis)
	if role=="vertical_wall" and rect.size.x not in role_spec.cross_section_specs: return _failure("Vertical wall has no registered shaft cross-section")
	var length:=rect.size.x if axis=="x" else rect.size.y
	var part_plan:=_assemble_parts(length,role,data.part_grammar)
	if not part_plan.ok:return _failure("Unexpressible platform "+str(definition.module_id)+"/"+str(index)+": "+str(part_plan.error))
	var depth_id:=str(family.body_depth_spec)
	part_plan.root_interface={"root_spec":depth_id,"depth":float(data.body_depth_specs[depth_id]),"connection":role_spec.root,"status":"pending_real_painted_root_and_actual_attachment_validation"}
	part_plan.contact_span=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	part_plan.cross_section=rect.size.x if role=="vertical_wall" else float(data.body_depth_specs[depth_id]) if role_spec.cross_section is String else float(role_spec.cross_section)
	return {"ok":true,"platform_index":index,"contact_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"structural_role":role,"support_requirement":str(role_spec.root),"collision_source":"existing_definition_unchanged","visual_body_depth":float(data.body_depth_specs[depth_id]),"no_new_standing_surfaces":true,"assembly_plan":part_plan}

static func _assemble_parts(length: float, role: String, grammar: Dictionary) -> Dictionary:
	var spec: Dictionary=grammar.role_specs[role]
	var end: Dictionary=grammar.parts[spec.end_part]
	var end_length:=float(end.axis_length)
	var pixels_per_world:=float(grammar.pixels_per_world_unit)
	var target_pixels:=roundi(length*pixels_per_world)
	if float(target_pixels)/pixels_per_world!=length:return _failure("Contact span is outside the registered source-pixel lattice")
	var minimum_overlap:=float(grammar.overlap_world_range[0])
	var maximum_overlap:=float(grammar.overlap_world_range[1])
	var best: Dictionary={}
	for core_id: String in spec.core_parts:
		var core: Dictionary=grammar.parts[core_id]
		var minimum_joint_pixels:=ceili(minimum_overlap*pixels_per_world)
		var maximum_joint_pixels:=mini(floori(maximum_overlap*pixels_per_world),mini(roundi(end_length*pixels_per_world)-1,roundi(float(core.axis_length)*pixels_per_world)-1))
		for count: int in range(1,int(grammar.maximum_core_count)+1):
			var nominal_pixels:=roundi((2.0*end_length+float(core.axis_length)*count)*pixels_per_world)
			var overlap_pixels:=nominal_pixels-target_pixels
			if overlap_pixels<minimum_joint_pixels*(count+1) or overlap_pixels>maximum_joint_pixels*(count+1):continue
			if best.is_empty() or count<int(best.core_count):best={"core_id":core_id,"core_count":count,"total_overlap_pixels":overlap_pixels}
			break
	if best.is_empty():return _failure("No finite end/core assembly covers contact span without stretching or end truncation")
	var pieces: Array=[]
	var joints: Array=[]
	var offset:=0.0
	var ids: Array=[spec.end_part]
	for unused: int in int(best.core_count):ids.append(best.core_id)
	ids.append(spec.end_part)
	var joint_count:=ids.size()-1
	var base_overlap_pixels:=floori(float(best.total_overlap_pixels)/float(joint_count))
	var remaining_pixels:=int(best.total_overlap_pixels)-base_overlap_pixels*joint_count
	for index: int in ids.size():
		var part: Dictionary=grammar.parts[ids[index]]
		var axis_length:=float(part.axis_length)
		pieces.append({"part_id":ids[index],"offset":offset,"axis_length":axis_length,"source_scale":float(grammar.source_scale),"mirrored":index==ids.size()-1,"asset_status":grammar.asset_status})
		var overlap:=0.0
		if index<joint_count:
			var source_overlap_pixels:=base_overlap_pixels+(1 if index<remaining_pixels else 0)
			overlap=float(source_overlap_pixels)/pixels_per_world
			joints.append({"from_part":index,"to_part":index+1,"overlap_world":overlap,"source_overlap_pixels":source_overlap_pixels,"interface_range_world":grammar.overlap_world_range.duplicate(),"source_registration":"pending_real_painted_interface_windows"})
		offset+=axis_length-overlap
	if offset!=length:return _failure("Finite source-pixel parts do not exactly cover contact span")
	return {"ok":true,"role":role,"axis":spec.axis,"target_length":length,"target_source_pixels":target_pixels,"covered_length":offset,"coverage_error":offset-length,"core_count":best.core_count,"pieces":pieces,"joints":joints,"pixels_per_world_unit":pixels_per_world,"coordinate_representation":"integer_source_pixel_interfaces","no_stretch":true,"no_end_truncation":true,"art_status":"pending_painted_sources_not_asset_admitted","assembly_rule":grammar.assembly_rule}

static func _area_col(manifest: Dictionary, area_id: String) -> int:
	for area: Dictionary in manifest.areas:
		if str(area.id)==area_id:return int(area.col)
	return -1

static func _area_position(manifest: Dictionary, area_id: String) -> Vector2:
	for area: Dictionary in manifest.areas:
		if str(area.id)==area_id:return Vector2(float(area.position[0]),float(area.position[1]))
	return Vector2.ZERO

static func _port(port: PlatformingModulePort) -> Dictionary:
	return {"position":[port.position.x,port.position.y],"direction":[port.direction.x,port.direction.y],"physics_source":"actual_definition"}

static func _failure(message: String) -> Dictionary:
	return {"ok":false,"version":VERSION,"error":message}
