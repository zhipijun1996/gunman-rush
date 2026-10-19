extends SceneTree
const LEGACY_PRESENTATION := preload("res://tests/legacy_plains_presentation_fixture.gd")
var legacy_presentation_fixtures: Array[Dictionary] = []
const FROZEN_PRE_JOIN_SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painted_material : source_color, filter_linear;
uniform sampler2D painted_border : source_color, filter_linear;
uniform highp vec4 faces[64];
uniform int face_count = 0;
uniform vec4 block_bounds;
uniform vec2 shape_origin;
uniform bool body_local_material = false;
uniform int cell_masks[16];
uniform int block_width = 1;
uniform bool canonical_cells = true;
uniform vec4 outer_corners[32];
uniform int corner_count = 0;
varying highp vec2 shape_pixel;
varying highp vec2 material_pixel;
void vertex() { shape_pixel = VERTEX+shape_origin; material_pixel = body_local_material ? shape_pixel : (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
// Each source seam fades into the middle of the other phase; retain painted detail.
// This repairs sampler continuity, not art quality.
vec4 horizontal_sample(vec2 uv) {
    float x = fract(uv.x);
    vec4 a = texture(painted_material, vec2(x, uv.y));
    float w = smoothstep(0.0, 0.12, min(x, 1.0-x));
    vec4 edge = texture(painted_material, vec2(fract(x+0.5),uv.y));
    return mix(edge, a, w);
}
vec4 earth_sample(vec2 p) {
    float y = fract(p.y / 208.0);
    vec4 a = horizontal_sample(vec2(p.x / 384.0, mix(0.18,0.999,y)));
    vec4 edge = horizontal_sample(vec2(p.x/384.0,mix(0.18,0.999,fract(y+0.5))));
    return mix(edge,a,smoothstep(0.0,0.12,min(y,1.0-y)));
}
// Painted rock edge strips share the same source and world phase. Interior
// alpha gates the pigment; the sprite's transparent RGB never becomes a halo.
vec4 border_tex(float phase, float depth, int side) {
    vec2 p = side==0 ? vec2(36.0+depth*4.0,192.0+phase*704.0)
           : side==1 ? vec2(1500.0-depth*4.0,192.0+phase*704.0)
           : vec2(160.0+phase*1216.0,940.0-depth*4.0);
    return texture(painted_border,p/vec2(1536.0,1024.0));
}
vec4 border_sample(float coordinate,float depth,int side) {
    float t=fract(coordinate/(side==2 ? 304.0 : 176.0));
    return mix(border_tex(fract(t+0.5),depth,side),border_tex(t,depth,side),smoothstep(0.0,0.12,min(t,1.0-t)));
}
// Use painted alpha only within a bounded inward contour band. This softens
// the silhouette without moving collision or inventing a new landing surface.
float border_alpha(float coordinate,float depth,int side) {
    float t=fract(coordinate/(side==3 || side==2 ? 304.0 : 176.0));
    float t2=fract(t+0.5);
    vec2 a=side==0 ? vec2(16.0+depth*48.0,192.0+t*704.0)
          : side==1 ? vec2(1520.0-depth*48.0,192.0+t*704.0)
          : vec2(160.0+t*1216.0,side==2 ? 976.0-depth*64.0 : 64.0+depth*64.0);
    vec2 b=side==0 ? vec2(a.x,192.0+t2*704.0)
          : side==1 ? vec2(a.x,192.0+t2*704.0)
          : vec2(160.0+t2*1216.0,a.y);
    float alpha=mix(texture(painted_border,b/vec2(1536.0,1024.0)).a,texture(painted_border,a/vec2(1536.0,1024.0)).a,smoothstep(0.0,0.12,min(t,1.0-t)));
    return min(1.0,alpha*1.06);
}
void fragment() {
    float top = 10000.0;
    float edge_distance = 10000.0;
    float side_light = 1.0;
    vec3 edge_depth=vec3(10000.0);
    for (int i=0; i<64; i++) {
        if (i>=face_count) { break; }
        vec2 a=faces[i].xy;
        vec2 b=faces[i].zw;
        vec2 ab=b-a;
        float along=clamp(dot(shape_pixel-a,ab)/max(dot(ab,ab),0.01),0.0,1.0);
        float d=length(shape_pixel-a-along*ab);
        if (ab.y<0.0) edge_depth.x=min(edge_depth.x,d);
        if (ab.y>0.0) edge_depth.y=min(edge_depth.y,d);
        if (ab.x<0.0) edge_depth.z=min(edge_depth.z,d);
        if (d<edge_distance) {
            edge_distance=d;
            side_light=ab.x>0.0 ? 1.06 : ab.x<0.0 ? 0.66 : ab.y>0.0 ? 0.78 : 0.90;
        }
        // Clockwise boundaries: only an exposed up-facing edge grows grass.
        if (ab.x>0.0 && shape_pixel.y>=a.y ) {
            top=min(top,length(shape_pixel-vec2(clamp(shape_pixel.x,a.x,b.x),a.y)));
        }
    }
    vec4 earth=earth_sample(material_pixel);
    float section_depth=min(top+edge_depth.z,edge_depth.x+edge_depth.y);
    float turf_scale=clamp(section_depth/40.0,0.12,1.0);
    vec4 grass=horizontal_sample(vec2(material_pixel.x/384.0,clamp(top*6.0/(1024.0*turf_scale),0.0,0.22)));
    vec4 paint=mix(grass,earth,smoothstep(10.0*turf_scale,22.0*turf_scale,top));
    paint.rgb *= mix(side_light,1.0,smoothstep(0.0,5.0,edge_distance));
    vec3 border_sum=vec3(0.0);
    float border_weight=0.0;
    for (int side=0;side<3;side++) {
        float depth=edge_depth[side];
        if (depth<10.0) {
            vec4 rim=border_sample(side==2 ? material_pixel.x : material_pixel.y,depth,side);
            float w=(1.0-smoothstep(0.0,10.0,depth))*rim.a;
            if (side!=2) w*=smoothstep(4.0,12.0,top);
            border_sum+=rim.rgb*w; border_weight+=w;
        }
    }
    if (border_weight>0.0) paint.rgb=mix(paint.rgb,border_sum/border_weight,min(0.85,border_weight));
    // Rounded outer contours use the actual canonical mask, including thin rows.
    vec2 cell=floor((shape_pixel-block_bounds.xy)/32.0);
    int index=int(cell.y)*block_width+int(cell.x);
    int mask=cell_masks[clamp(index,0,15)];
    vec2 p=mod(shape_pixel-block_bounds.xy,32.0);
    float contour=1.0;
    float radius=2.5;
    if (canonical_cells && (mask&1)==0 && (mask&8)==0 && p.x<radius && p.y<radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(radius)));
    if (canonical_cells && (mask&1)==0 && (mask&2)==0 && p.x>32.0-radius && p.y<radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(32.0-radius,radius)));
    if (canonical_cells && (mask&4)==0 && (mask&8)==0 && p.x<radius && p.y>32.0-radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(radius,32.0-radius)));
    if (canonical_cells && (mask&4)==0 && (mask&2)==0 && p.x>32.0-radius && p.y>32.0-radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(32.0-radius)));
    if (!canonical_cells) {
        for (int i=0;i<32;i++) {
            if (i>=corner_count) { break; }
            vec4 corner=outer_corners[i];
            int orientation=int(corner.z);
            vec2 direction=vec2((orientation==1 || orientation==3) ? -1.0 : 1.0,orientation>=2 ? -1.0 : 1.0);
            vec2 local=(shape_pixel-corner.xy)*direction;
            float r=corner.w;
            if (local.x>=0.0 && local.y>=0.0 && local.x<r && local.y<r) {
                contour=min(contour,1.0-smoothstep(r-0.4,r+0.4,length(local-vec2(r))));
            }
        }
    }
    float contour_band=min(1.75,section_depth*0.125);
    for (int side=0;side<4;side++) {
        float depth=side==3 ? top : edge_depth[side];
        if (depth<contour_band && contour_band>0.0) {
            float a=border_alpha(side>=2 ? material_pixel.x : material_pixel.y,depth/contour_band,side);
            contour=min(contour,mix(a,1.0,smoothstep(0.0,contour_band,depth)));
        }
    }
    paint.a *= contour;
    COLOR=paint;
}
"""
var gpu_probe := false
var assertions := 0
var failures := 0
var output := ""
var mutation := ""
var report: Dictionary = {}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--mutation="): mutation = arg.trim_prefix("--mutation=")
		if arg == "--gpu-probe": gpu_probe = true
	run.call_deferred()
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures += 1; printerr("VISUAL SPACE FAIL: ", label)
func find_spaces(node: Node, result: Array[PlainsVisualSpace]) -> void:
	if node is PlainsVisualSpace: result.append(node)
	for child: Node in node.get_children(): find_spaces(child, result)
func forbidden_descendants(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Camera2D: return true
		if forbidden_descendants(child): return true
	return false
func run() -> void:
	if gpu_probe:
		await run_gpu_probe()
		return
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline"), "real formal baseline starts")
	for unused: int in 120:
		await physics_frame; await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: break
	app.lifetime.stage_epoch += 1; app.lifetime.actor_epoch += 1
	_sync_fixture_map_index(app, 2)
	app.director._enter_stage(2, &"boss")
	app._stage_entered(DemoRunResult.new())
	for unused: int in 120:
		await physics_frame; await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index == 2: break
	_install_legacy_presentation(app)
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok, "real map2 assembled")
	check(_fixture_identity_matches(app, 2, "level-design-v2-baseline"), "actual map2 stage/manifest seed+difficulty")
	var before := JSON.stringify(app.stage.generated.manifest)
	var spaces: Array[PlainsVisualSpace] = []
	find_spaces(app.stage, spaces)
	check(spaces.size() == 1, "exactly one semantic creek space")
	if spaces.size() == 1:
		var space := spaces[0]
		check(space.omission_reason.is_empty(), "candidate has actual supported anchor")
		check(is_instance_valid(space.source_module) and space.source_module.definition.module_id == &"plains_bell_ferry_control", "real semantic ferry module")
		check(is_instance_valid(space.attachment) and space.attachment.get_parent() == space.source_module, "actual dock support body")
		check(not forbidden_descendants(space), "presentation subtree has no collision or camera authority")
		check(space.measured_nodes().size() == 2, "real sprite and real collider measured")
		check(space.actual_issues().is_empty(), "untouched actual wall anchor/scale/depth/source")
		space._update_bank_materials()
		check(space.bank_material_issues().is_empty(), "real selected bank material scopes bound")
		var bank_rows := space.bank_material_measurements()
		check(not bank_rows.is_empty() and bank_rows.size() == space.bank_quads.size(), "actual Control bank observer emits nonempty measured rows")
		var observed_bounds_equal := true
		for index: int in bank_rows.size():
			var quad: ColorRect = space.bank_quads[index]
			var actual := quad.get_global_transform() * Rect2(Vector2.ZERO,quad.size)
			observed_bounds_equal = observed_bounds_equal and bank_rows[index].actual_world_bounds == PlainsVisualSpace.rect_values(actual) and bank_rows[index].node_path == str(quad.get_path())
		check(observed_bounds_equal, "actual Control observer world bounds equal real rendered quads")
		space._output = ProjectSettings.globalize_path(output.get_base_dir() + "/" + (mutation if not mutation.is_empty() else "positive") + "_composition_raw.json")
		space._last_physics_frame = -120
		space._process(0.0)
		check(not space._samples.is_empty() and not space._samples[-1].bank_materials.is_empty(), "explicit actual observer process samples real bank properties")
		if mutation == "bank_scope_escape":
			var material := space.bank_quads[0].material as ShaderMaterial
			material.set_shader_parameter("well_bank_regions",PackedVector4Array([Vector4(-10000,-10000,20000,20000),Vector4(0,0,1,1)]))
		elif mutation == "bank_disabled": (space.bank_quads[0].material as ShaderMaterial).set_shader_parameter("well_bank_enabled",false)
		elif mutation == "ferry_graded":
			var ferry := space.source_module.moving_platforms[0]
			(ferry.painted_art.get_child(0).material as ShaderMaterial).set_shader_parameter("well_bank_enabled",true)
		elif mutation == "detached_root": space.wall.position.y -= 120
		elif mutation == "channel_intrusion": space.wall.position.x += 500
		elif mutation == "far_detached_root": space.recess.global_position.y -= 120
		elif mutation == "far_clipped_boundary":
			var cropped := AtlasTexture.new(); cropped.atlas = space.recess.texture
			cropped.region = Rect2(0,0,768,1024); space.recess.texture = cropped
		elif mutation == "far_wrong_scale": space.recess.scale *= 1.5
		elif mutation == "far_wrong_depth": space.recess.z_index = 100
		elif mutation == "wrong_attachment": space.attachment = space.source_module.get_node("Platform1") as StaticBody2D
		elif mutation == "translated_parent":
			# Compare equal sampling instants, not an old pre-camera-ready frame.
			space._update_recess_parallax()
			var parent := Node2D.new(); parent.position = Vector2(240,-90); parent.z_index = -15
			app.stage.add_child(parent)
			var translated := PlainsVisualSpace.new(); translated.configure(app.stage); parent.add_child(translated)
			check(translated.actual_issues().is_empty(), "real translated parent keeps world anchored walls/recess")
			check(translated.actual_opaque_bounds().is_equal_approx(space.actual_opaque_bounds()), "translated parent actual opaque world bounds equal")
			check(translated.recess.global_position.is_equal_approx(space.recess.global_position), "translated parent actual far world placement equal")
			parent.free()
		elif not mutation.is_empty(): check(false, "unknown mutation")
		var issues := space.actual_issues()
		issues.append_array(space.bank_material_issues())
		check(issues.is_empty(), "actual consumer invariant after requested mutation: " + str(issues))
		check(JSON.stringify(app.stage.generated.manifest) == before, "presentation keeps formal Manifest unchanged")
		report = {"mutation": mutation, "issues": issues, "nodes": space.measured_nodes(), "bank_materials": bank_rows, "dock": PlainsVisualSpace.rect_values(space.dock), "manifest_hash": app.stage.generated.manifest.manifest_hash, "scope": "Real DemoApp/assembler and actual Sprite/Platform0 measures, no traversal or aesthetic/device claim"}
	check(PlainsVisualSpace.validated_output_path("res://build/../docs/escape.json").is_empty(), "observer rejects canonical relative path escape")
	check(PlainsVisualSpace.validated_output_path(ProjectSettings.globalize_path("res://build") + "/../../escape.json").is_empty(), "observer rejects canonical absolute path escape")
	check(not PlainsVisualSpace.validated_output_path("res://build/visual_director/observed.json").is_empty(), "observer permits only real build output")
	report["legacy_presentation_fixtures"] = legacy_presentation_fixtures
	report["presentation_scope"] = "explicit_legacy_presentation_not_default"
	report["actual_map_identity"] = {"map_index":app.stage.map_index,"seed":app.stage.generated.manifest.seed,"difficulty":app.stage.generated.manifest.difficulty}
	if not await preload("res://tests/audio_teardown.gd").drain_world(app):
		check(false, "actual application audio drains before exit")
	app.free(); await process_frame
	report["assertions"] = assertions; report["failures"] = failures
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report) + "\n"); file.close()
	print("VISUAL SPACE: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

func probe_view() -> SubViewport:
	var view := SubViewport.new()
	view.size=Vector2i(192,160)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view

func run_gpu_probe() -> void:
	var views: Array[SubViewport]=[]
	var old := Shader.new(); old.code=FROZEN_PRE_JOIN_SHADER
	for mode: int in 3:
		var view:=probe_view();views.append(view)
		var rectangles: Array[Rect2]=[Rect2(0,0,160,128)]
		var art:=PlainsTileComposer.build_rectangles(rectangles)
		art.position=Vector2(16,16);view.add_child(art)
		for child: ColorRect in art.get_children():
			var mat:=child.material as ShaderMaterial
			if mode==0: mat.shader=old
			if mode==2:
				mat.set_shader_parameter("well_bank_enabled",true)
				mat.set_shader_parameter("well_bank_regions",PackedVector4Array([Vector4(16,16,160,128),Vector4(1000,1000,1,1)]))
				mat.set_shader_parameter("well_bank_strength",0.78)
	var family: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/visual_director/waterworks_v1/manifest.json"))
	var far_path: String=""
	for asset: Dictionary in family.assets:
		if asset.id==family.active_recess_asset_id: far_path="res://"+str(asset.path)
	for mode: int in 2:
		var view:=probe_view();views.append(view)
		var sprite:=Sprite2D.new();sprite.texture=load(far_path);sprite.centered=false;sprite.position=Vector2(16,16)
		sprite.scale=Vector2.ONE*(160.0/sprite.texture.get_width());view.add_child(sprite)
		if mode==1:
			var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/plains_waterworks_depth.gdshader");sprite.material=mat
	for unused: int in 4: await RenderingServer.frame_post_draw
	var images: Array[Image]=[]
	for view: SubViewport in views: images.append(view.get_texture().get_image())
	check(not images[0].is_empty(), "actual GPU reference pixels exist")
	check(images[0].get_data()==images[1].get_data(), "new default shader is exact frozen prior GPU output")
	var alpha_equal:=true;var grass_equal:=true;var body_changed:=0
	for y: int in 160:
		for x: int in 192:
			var a:=images[1].get_pixel(x,y);var b:=images[2].get_pixel(x,y)
			if a.a!=b.a: alpha_equal=false
			if y<44 and a!=b: grass_equal=false
			if y>=84 and a!=b: body_changed+=1
	check(alpha_equal,"selected bank preserves every actual alpha pixel")
	check(grass_equal,"selected bank preserves actual top28world grass pixels")
	check(body_changed>100,"selected body actually changes rendered source painting")
	var far_alpha_equal:=true;var far_changed:=0
	for y: int in 160:
		for x: int in 192:
			var a:=images[3].get_pixel(x,y);var b:=images[4].get_pixel(x,y)
			if a.a!=b.a: far_alpha_equal=false
			if a!=b: far_changed+=1
	check(far_alpha_equal,"distant fracture shader preserves every original alpha pixel/aperture")
	check(far_changed>25,"distant fracture role lighting actually changes pixels")
	report={"assertions":assertions,"failures":failures,"default_reference_shader_sha256":FROZEN_PRE_JOIN_SHADER.sha256_text(),"alpha_equal":alpha_equal,"far_alpha_equal":far_alpha_equal,"far_changed_pixels":far_changed,"grass_equal":grass_equal,"body_changed_pixels":body_changed,"scope":"Actual isolated GPU shader fixture only, not formal scene/beauty/device acceptance"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		for index: int in images.size(): images[index].save_png(output.get_base_dir()+"/gpu_%s.png"%index)
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report)+"\n");file.close()
	for view: SubViewport in views: view.free()
	print("VISUAL SPACE GPU: %s assertions, %s failures"%[assertions,failures])
	quit(0 if failures==0 else 1)


# Test-only independent-stage fixture; no natural campaign transition is claimed.
func _sync_fixture_map_index(app: DemoApp, index: int) -> void:
	for entry: Dictionary in app.director.get_property_list():
		if str(entry.get("name", "")) == "region_map_index":
			app.director.set("region_map_index", index)
			return

func _fixture_identity_matches(app: DemoApp, index: int, root_seed: String) -> bool:
	var actual := app.stage as PlainsRegionStage
	if actual == null or not actual.assembly_ok: return false
	var manifest: Dictionary = actual.generated.manifest
	return actual.map_index == index and manifest.get("region", "") == "plains" and manifest.get("seed", "") == PlainsRegionCampaign.seed_for(root_seed, index) and manifest.get("difficulty", "") == ("intro" if index == 1 else "advanced")


func _install_legacy_presentation(app: DemoApp) -> void:
	var record := LEGACY_PRESENTATION.prepare(app, "waterworks")
	legacy_presentation_fixtures.append(record)
	check(record.get("pixel_default_before",false), "new stage retains current pixel default before explicit historical fixture")
	check(record.get("no_flag_and_wrong_profile_refused_without_mutation",false), "missing/wrong legacy profile rejected with actual default unchanged")
	check(record.get("installed",false) and record.get("unchanged",false), "explicit legacy presentation preserves actual physics/Manifest/player tuning")
