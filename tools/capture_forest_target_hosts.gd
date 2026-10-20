extends SceneTree
## Explicit initial-placement G2 fixtures. No traversal or player approval claim.
var output := "res://build/forest_revision04/hosts-W8"
var seed_value := "forest-depth-00"
var map_index := 1
var group := "fallen_fork"
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--seed="):seed_value=arg.trim_prefix("--seed=")
		elif arg.begins_with("--group="):group=arg.trim_prefix("--group=")
		elif arg.begins_with("--map="):map_index=int(arg.trim_prefix("--map="))
	run.call_deferred()

func frames(count: int) -> void:
	for index: int in count:await physics_frame

func run() -> void:
	root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	var view_groups := {"root_hint":["hanging_fruit_hint"],"fallen_fork":["broken_arch_entry","broken_arch_crown","broken_arch_return_view"],"spiral_crown":["spiral_pod_bank","spiral_crown_bank","canopy_return_view"],"gate_pull":["gate_side_closed","gate_approach_closed","gate_open_after_actual_hook"],"guardian_pair":["guardian_entry","guardian_left_counter","guardian_right_counter"],"queen_rib":["queen_entry","queen_right_bank","queen_right_return"],"hollow_elbow":["hollow_upper_bank","hollow_exit_bank","hollow_return_bank"]}
	var views: Array = view_groups.get(group,[])
	for view: String in views:
		var app := DemoApp.new()
		app.meta_persistence_enabled=false
		root.add_child(app)
		if not app.start_debug_region(&"thorn_forest",map_index,seed_value,ThornForestRegionGenerator.DEPTH_VERSION,ForestTargetHosts.LAYOUT):
			failures.append("entry/"+view);app.free();break
		await frames(10)
		var stage := app.stage as ThornForestRegionStage
		if not is_instance_valid(stage) or not stage.assembly_ok:
			failures.append("stage/"+view);app.free();break
		var manifest: Dictionary=stage.generated.manifest
		var original := JSON.stringify(manifest)
		var assembler := stage.assembler as ThornForestRegionAssembler
		var instance: Dictionary={}
		for row: Dictionary in manifest.geometry_instances:
			if row.id=="broken_arch":instance=row;break
		if instance.is_empty():failures.append("instance/"+view);app.free();break
		var local: Array=instance.local_geometry.spawn if view=="broken_arch_entry" else instance.local_geometry.goal
		var at := Vector2(float(local[0])+float(instance.translation[0]),float(local[1])+float(instance.translation[1]))
		if view=="broken_arch_return_view":
			for support: Dictionary in manifest.platforms:
				if support.id=="broken_arch__crown":at=Vector2(float(support.rect[0])+float(support.rect[2])-28,float(support.rect[1])-18)
		if group=="spiral_crown":
			var support_id := "upper_spiral_pod_bough" if view=="spiral_pod_bank" else ("upper_spiral__crown" if view=="spiral_crown_bank" else "canopy_fork__crown")
			for support: Dictionary in manifest.platforms:
				if support.id==support_id:at=Vector2(float(support.rect[0])+float(support.rect[2])*0.5,float(support.rect[1])-18)
		var support_id := ""
		var side := 0.5
		if group=="root_hint":
			support_id="interwoven_inner_bough"
			side=0.37
		elif group=="gate_pull":
			support_id="hollow__cavity_exit" if view=="gate_side_closed" else "boss_approach"
			side=0.55
		elif group=="guardian_pair":
			support_id="boss_entry" if view=="guardian_entry" else "counter_branch"
			side=0.2 if view=="guardian_left_counter" else 0.8
		elif group=="queen_rib":
			support_id="canopy_entry" if view=="queen_entry" else ("right_rib" if view=="queen_right_bank" else "right_bank")
			side=0.5
		elif group=="hollow_elbow":
			support_id="hollow__cavity_right_step" if view=="hollow_upper_bank" else ("hollow__cavity_exit" if view=="hollow_exit_bank" else "hollow__elbow_return_relay")
		var support_found := support_id.is_empty()
		for support: Dictionary in manifest.platforms:
			if support.id==support_id:
				at=Vector2(float(support.rect[0])+float(support.rect[2])*side,float(support.rect[1])-18)
				support_found=true
		if not support_found:failures.append("missing_observation_support/"+view);app.free();break
		if not app.controller.return_to_segment(at):failures.append("initial_setup/"+view)
		app.controller.router.clear("initial_visual_fixture_only")
		await frames(45)
		var action := {}
		if view=="gate_open_after_actual_hook":
			var key := str(manifest.vine_gate.key_anchor)
			var target: GrappleAnchor = assembler.hook_targets.get(key)
			action={"kind":"actual_input_hook_opens_gate","before_open":stage.region_state.opened.has("crown_vine"),"target":key,"start":[app.player.position.x,app.player.position.y]}
			app.controller.router.request_action(&"grapple",(target.global_position-(app.player.global_position+Vector2(0,-6))).normalized())
			for tick: int in 180:
				await frames(1)
				if stage.region_state.opened.has("crown_vine"):
					action["contact_tick"]=tick
					break
			await frames(60)
			action["after_open"]=stage.region_state.opened.has("crown_vine")
			action["shape_disabled"]=assembler.vine_shape.disabled
			action["completed_hint_hidden"]=not stage._gate_hint.visible
			if not action.completed_hint_hidden:failures.append("completed_gate_hint/"+view)
			if action.before_open or not action.after_open or not action.shape_disabled:failures.append("actual_gate_hook/"+view)
		if group in ["guardian_pair","queen_rib"]:await frames(60)
		var visible_hints: Array = []
		for hint: Dictionary in stage.context_signs:
			if hint.label.visible:visible_hints.append(hint.label.text)
		if group=="root_hint":
			var expected_hint := "Left: recoil and hook back toward the crown.\nRight: recoil toward the hanging fruit, then fire down."
			if not expected_hint in visible_hints:failures.append("actual_visible_fruit_hint/"+view)
			if visible_hints.any(func(text: String) -> bool:return "hanging ring" in text):failures.append("stale_visible_ring_hint/"+view)
		var seal: BossArenaSeal = stage.boss_seal
		var seal_view := {"armed":seal.armed,"closed":seal.closed,"world_status_text_enabled":seal.world_status_text_enabled,"boss_hud_visible":app._boss_status.visible,"boss_hud_text":app._boss_status.text}
		if group in ["guardian_pair","queen_rib"] and seal.closed and (seal.world_status_text_enabled or not "ARENA SEALED" in app._boss_status.text):failures.append("sealed_HUD/"+view)
		var audit := assembler.presentation_host_audit()
		var unchanged: bool=JSON.stringify(manifest)==original and JSON.stringify(assembler.manifest)==original
		if not unchanged:failures.append("manifest_changed/"+view)
		if not app.player.is_on_floor():failures.append("not_grounded/"+view)
		var mounts: Array=[]
		for mount: Dictionary in audit.get("mounts",[]):
			if not bool(mount.get("resolved",false)):continue
			var target: GrappleAnchor=assembler.hook_targets.get(str(mount.target_id))
			var radius := -1.0
			for child: Node in target.get_children():
				if child is CollisionShape2D and child.shape is CircleShape2D:radius=child.shape.radius
			var expected_script := "res://scripts/world/forest_fruit_anchor.gd" if mount.get("presentation")=="runtime_rooted_fruit" else "res://scripts/world/grapple_anchor.gd"
			var authored: Dictionary = {}
			for row: Dictionary in manifest.hook_anchors:
				if str(row.id)==str(mount.target_id):authored=row;break
			var node_ok: bool=authored.get("fruit_presentation")=="existing_marker_pending_local_support" and target.collision_mask==0 and target.hang_enabled==bool(authored.get("hang_enabled",false)) and target.position==Vector2(mount.target_position[0],mount.target_position[1]) and target.collision_layer==8 and radius==12 and target.is_in_group(&"grapple_target") and target.get_script().resource_path==expected_script
			if not node_ok:failures.append("target_changed/"+str(mount.target_id))
			mounts.append({"id":mount.target_id,"position":[target.position.x,target.position.y],"radius":radius,"layer":target.collision_layer,"hang":target.hang_enabled,"runtime_presentation":mount.presentation,"script":target.get_script().resource_path,"unchanged_target_contract":node_ok})
		await RenderingServer.frame_post_draw
		var image_path := output.path_join("map%s_"%map_index+view+".png")
		if root.get_texture().get_image().save_png(image_path)!=OK:failures.append("image/"+view)
		var camera := app._run_camera
		observations.append({"view":view,"scope":"formal_App_initial_segment_G2_fixture_not_traversal","seed":manifest.seed,"map":map_index,"layout":manifest.layout_version,"manifest_hash":manifest.manifest_hash,"manifest_representation_sha256":original.sha256_text(),"manifest_unchanged":unchanged,"action":action,"visible_context_hints":visible_hints,"seal_presentation":seal_view,"image":image_path,"body":[app.player.position.x,app.player.position.y],"grounded":app.player.is_on_floor(),"camera":[camera.get_screen_center_position().x,camera.get_screen_center_position().y],"runtime_host_audit":audit,"targets":mounts})
		app.process_mode=Node.PROCESS_MODE_DISABLED
		app._cancel_enemy_attacks()
		if not await preload("res://tests/audio_teardown.gd").drain_world(app):failures.append("audio_release/"+view)
		app.free()
		await process_frame;await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"source_bound_"+group+"_G2_fixtures_only","presentation_revision":ForestTargetHosts.PRESENTATION_REVISION,"failures":failures,"observations":observations}));file.close()
	print("FOREST TARGET HOSTS: %s observations / %s failures" % [observations.size(),failures.size()])
	quit(0 if observations.size()==views.size() and failures.is_empty() else 1)
