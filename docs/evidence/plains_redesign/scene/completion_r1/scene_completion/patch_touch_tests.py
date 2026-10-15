from pathlib import Path
p=Path('tests/plains_redesign_scene_runner.gd');s=p.read_text();s=s.replace('var elective_receipts: Array = []','var elective_receipts: Array = []\nvar legacy_ui: Dictionary = {}');s=s.replace('var visual_frames: Array = []','var visual_frames: Array = []\n\tvar observe_every_tick := false');s=s.replace('(trace_ticks % 6 == 0 or not observed_frames[-1].accepted_events.is_empty())','(observe_every_tick or trace_ticks % 6 == 0 or not observed_frames[-1].accepted_events.is_empty())');s=s.replace('trace.current_edge="elective_extra_upward_recoil"','trace.current_edge="elective_extra_upward_recoil"\n\ttrace.observe_every_tick=true');s=s.replace('if custom=="touch_geometry":\n\t\tapp.overlay','if custom=="touch_geometry":\n\t\ttrace.observe_every_tick=true\n\t\tapp.overlay');s=s.replace('else:\n\t\tawait run_case(1,"fast")','else:\n\t\tawait legacy_compatibility()\n\t\tawait run_case(1,"fast")');s=s.replace('"mutation":mutation,"screenshots":','"mutation":mutation,"legacy_ui":legacy_ui,"screenshots":');s=s.replace('func run() -> void:', '''func legacy_compatibility() -> void:
	var legacy:=DemoApp.new();legacy.meta_persistence_enabled=false;root.add_child(legacy)
	check(legacy.start_demo("scene-legacy-info",false),"original nonregion consumer starts")
	for unused: int in 120:
		await physics_frame;await process_frame
		if not legacy._stage_pending and is_instance_valid(legacy.stage):break
	await process_frame
	legacy_ui={"connected_region":legacy.connected_region,"info":pair(legacy._debug_button.position),"hud_width":legacy._hud_frame.size.x,"health_width":legacy._resources_hud.health_bar.size.x,"camera_zoom":pair(legacy._run_camera.zoom),"scope":"actual legacy DemoApp consumer, not screenshot/device acceptance"}
	check(not legacy.connected_region and legacy._debug_button.position==Vector2(434,10),"nonregion actual INFO original position")
	check(legacy._hud_frame.size.x==500 and legacy._resources_hud.health_bar.size.x==220,"nonregion actual HUD and resource original widths")
	check(legacy._run_camera.zoom.is_equal_approx(Vector2.ONE*1.95),"nonregion original camera zoom retained")
	legacy.debug_hud=true;await process_frame
	check(legacy._debug_button.position==Vector2(434,10),"nonregion debug INFO original position")
	legacy.free();await process_frame

func run() -> void:''');p.write_text(s)
p=Path('tools/run_plains_redesign_scene_tests.py');s=p.read_text();s=s.replace('coverage = set()','legacy = data.get("legacy_ui", {})\n    if legacy.get("connected_region") is not False or legacy.get("info") != [434.0,10.0] or legacy.get("hud_width") != 500 or legacy.get("health_width") != 220 or any(abs(v-1.95)>.001 for v in legacy.get("camera_zoom", [0,0])):\n        problems.append("actual original nonregion UI/camera compatibility absent")\n    coverage = set()');s=s.replace('report["acceptance_counterexamples"] =','broken = copy.deepcopy(positive); broken["legacy_ui"] = {}; mutations["missing_actual_legacy_compatibility"] = broken\n        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="touch_geometry"); [v.update(touch_regions=[]) for v in c["visual_frames"]]; mutations["disabled_touch_geometry"] = broken\n        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="touch_geometry"); v=c["visual_frames"][0]; v["ui"][0]["bounds"] = v["touch_regions"][0]; mutations["restored_touch_ui_overlap"] = broken\n        report["acceptance_counterexamples"] =');p.write_text(s)
