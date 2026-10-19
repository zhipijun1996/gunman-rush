class_name UnderworldLocalComposition
extends Node2D
## Local background architecture uses its own painted base, not physical roots.
## It never claims a standable edge, grounded-landmark ray or collision.
var compositions: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var _spec: Dictionary = {}

func configure(areas: Array, region: Dictionary, protected: Array[Rect2], solids: Array[Rect2], spec: Dictionary) -> void:
	_spec=spec
	z_index = int(spec.z_index)
	if bool(spec.collision) or bool(spec.standing_edge) or bool(spec.physical_support) or str(spec.depth)!="distant_local_architecture" or z_index>=0:
		omitted.append({"reason":"background_spec_claims_foreground_or_physics"})
		return
	var source := str(region.atlas)
	if source!=str(spec.painted_base.source):
		omitted.append({"reason":"background_painted_base_source_mismatch"})
		return
	var atlas := load("res://"+source) as Texture2D
	var r: Array = region.region
	var height := float(spec.target_height)
	var factor := height/float(region.foot[1])
	var size := Vector2(float(r[2]),float(r[3]))*factor
	var anchor := Vector2(float(region.foot[0]),float(region.foot[1]))*factor
	for area: Dictionary in areas:
		if str(area.get("identity",""))!=str(spec.identity): continue
		var origin := Vector2(float(area.position[0]),float(area.position[1]))
		for offset_y: Variant in spec.offset_y:
			for offset_x: Variant in spec.offset_x:
				var dy := float(offset_y)
				var dx := float(offset_x)
				var foot := origin+Vector2(dx,dy)
				var bounds := Rect2(foot-anchor,size)
				if protected.any(func(b:Rect2)->bool:return bounds.grow(8.0).intersects(b)): continue
				if solids.any(func(b:Rect2)->bool:return bounds.grow(2.0).intersects(b)): continue
				# Reject source bases hidden by foreground solids. Physics has no
				# authority here; this is a conservative visibility candidate test.
				var hidden := 0
				for u: float in [.1,.3,.5,.7,.9]:
					for v: float in [.1,.3,.5,.7,.9]:
						var point := bounds.position+bounds.size*Vector2(u,v)
						if solids.any(func(b:Rect2)->bool:return b.has_point(point)): hidden+=1
				if hidden>int(spec.maximum_solid_hidden_samples): continue
				var texture := AtlasTexture.new()
				texture.atlas=atlas
				texture.region=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
				texture.filter_clip=true
				var sprite := Sprite2D.new()
				sprite.name="DistantCreekWell_"+str(area.id)
				sprite.centered=false
				sprite.texture=texture
				sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position=bounds.position
				sprite.scale=Vector2.ONE*factor
				var material := ShaderMaterial.new()
				material.shader=preload("res://scripts/underworld_plains/underworld_parallax_edge.gdshader")
				material.set_shader_parameter("edge_fraction",.0001)
				material.set_shader_parameter("plane_opacity",float(spec.opacity))
				material.set_shader_parameter("fog_shadow",Color(str(spec.fog_shadow)))
				material.set_shader_parameter("fog_highlight",Color(str(spec.fog_highlight)))
				sprite.material=material
				add_child(sprite)
				var metadata := {"identity":spec.identity,"area_id":str(area.id),"asset_id":spec.asset_id,"asset_source":source,"source_sha256":FileAccess.get_sha256("res://"+source),"world_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"virtual_root":[foot.x,foot.y],"image_base":spec.painted_base.description,"depth":spec.depth,"collision":false,"standing_edge":false,"physical_support":false,"foreground_keepout":"whole_bounds_plus_8_preserved","actual_solid_visibility_samples_hidden":hidden,"visibility_samples":25,"node":sprite.name}
				sprite.set_meta("composition",metadata)
				compositions.append(metadata)
				return
	omitted.append({"identity":"creek_well","reason":"no_visible_local_background_socket_without_functional_keepout_overlap"})

func actual_issues() -> Array[String]:
	var issues: Array[String] = []
	for sprite: Sprite2D in get_children():
		if sprite.has_meta("landmark"):issues.append("background_architecture_misdeclared_as_grounded_landmark")
		if z_index>=0 or sprite.z_index>0:issues.append("background_architecture_moved_to_foreground")
		var metadata: Dictionary = sprite.get_meta("composition",{})
		if metadata.get("depth","")!="distant_local_architecture" or metadata.get("collision",true) or metadata.get("standing_edge",true) or metadata.get("physical_support",true):issues.append("background_architecture_claims_gameplay_or_physical_support")
		var expected: Array = metadata.get("world_bounds",[])
		var bounds := Rect2(sprite.global_position,sprite.texture.get_size()*sprite.global_scale)
		if expected.size()!=4 or not bounds.is_equal_approx(Rect2(expected[0],expected[1],expected[2],expected[3])):issues.append("background_actual_bounds_differ_from_record")
		var material := sprite.material as ShaderMaterial
		if material==null:issues.append("background_missing_atmospheric_material");continue
		for key: String in ["fog_shadow","fog_highlight"]:
			var color: Color = material.get_shader_parameter(key)
			var limits: Dictionary = _spec.readability_limits
			if (bool(limits.red_not_above_blue) and color.r>color.b) or color.g>float(limits.max_g) or color.r>float(limits.max_r) or color.b>float(limits.max_b):issues.append("background_bright_or_green_standing_edge_signal")
	return issues
