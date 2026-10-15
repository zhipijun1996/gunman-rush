from pathlib import Path
p=Path('scripts/generation/plains_region_generator.gd');s=p.read_text();s=s.replace('e.purpose="creek_discovery" if e.a==','e.purpose="outer_return" if e.get("outer_return",false) else "creek_discovery" if e.a==');p.write_text(s)
p=Path('tests/plains_redesign_scene_runner.gd');s=p.read_text();s=s.replace('var legacy_ui: Dictionary = {}','var legacy_ui: Dictionary = {}\nvar route_comparison: Dictionary = {}');s=s.replace('"elective_receipts":elective_receipts.duplicate(true)})','"elective_receipts":elective_receipts.duplicate(true),"route_comparison":route_comparison.duplicate(true)})');s=s.replace('elective_receipts=[]\n\tif mutation.is_empty():','elective_receipts=[]\n\troute_comparison={}\n\tif mutation.is_empty():')
old='''elif ok and mode=="outer_return":
		ok=await trace.follow_to("area_3_3")
		if ok:ok=await trace.follow_to("area_4_3")
		if ok:ok=await trace.follow_to("area_4_2")
		if ok:ok=await trace.follow_to(str(trace.stage.manifest.prep_id))'''
new='''elif ok and mode in ["outer_return","outer_upper_alternative"]:
		ok=await trace.follow_to("area_3_3")
		if ok:
			var start_tick: int=trace.trace_ticks
			var before:=trace.runtime_snapshot(true)
			var start_position:=pair(trace.motor.global_position)
			var path: Array=["area_3_3","area_4_3","area_4_2"] if mode=="outer_return" else ["area_3_3","area_3_2","area_4_2"]
			ok=await trace.follow_to(path[1])
			if ok:ok=await trace.follow_to(path[2])
			var ferry_paths: Array=[]
			for module: PlatformingModule in trace.stage.modules:
				for ferry: ModuleMovingPlatform in module.moving_platforms:ferry_paths.append(str(ferry.get_path()))
			var contacts: Array=[]
			for frame: Dictionary in trace.observed_frames.slice(start_tick):
				for collision: Dictionary in frame.collisions:
					if collision.collider in ferry_paths:contacts.append({"tick":frame.tick,"collider":collision.collider,"normal":collision.normal,"position":frame.position})
			route_comparison={"path":path,"start_tick":start_tick,"end_tick":trace.trace_ticks,"start_position":start_position,"end_position":pair(trace.motor.global_position),"runtime_before":before,"runtime_after":trace.runtime_snapshot(true),"ferry_contacts":contacts,"actual_edges":trace.observed_edges.filter(func(e:Dictionary):return e.start_tick>=start_tick),"reached":ok,"scope":"Same root/map/initial build/policy; shared fork and convergence. Timing/phase/resource observations, not a fun score or universally faster shortcut."}
			check(not contacts.is_empty() if mode=="outer_return" else true,"lower return actually rides a real ferry body")
		if ok:ok=await trace.follow_to(str(trace.stage.manifest.prep_id))'''
assert old in s;s=s.replace(old,new);s=s.replace('await run_case(2,"fast","outer_return")','await run_case(2,"fast","outer_return")\n\t\tawait run_case(2,"fast","outer_upper_alternative")');p.write_text(s)
p=Path('tools/run_plains_redesign_scene_tests.py');s=p.read_text();s=s.replace('len(routes) != 7','len(routes) != 8').replace('actual seven-route native contract','actual eight-route native contract');s=s.replace('(2, "fast", "outer_return"),','(2, "fast", "outer_return"), (2, "fast", "outer_upper_alternative"),');s=s.replace('if not rolled_zero_tested:', '''comparisons = {c.get("custom"): c.get("route_comparison", {}) for c in routes if c.get("custom") in {"outer_return", "outer_upper_alternative"}}
    if set(comparisons) != {"outer_return", "outer_upper_alternative"}:
        problems.append("missing actual shared-fork route comparison")
    else:
        lower, upper = comparisons["outer_return"], comparisons["outer_upper_alternative"]
        if any(not c.get("reached") or c.get("end_tick",0) <= c.get("start_tick",0) or len(c.get("actual_edges", [])) != 2 for c in (lower, upper)) or not lower.get("ferry_contacts"):
            problems.append("route comparison lacks actual edges/ferry collision/time")
        if math.dist(lower.get("start_position",[1e9,1e9]),upper.get("start_position",[0,0]))>2 or math.dist(lower.get("end_position",[1e9,1e9]),upper.get("end_position",[0,0]))>2:
            problems.append("route comparison fork/convergence differ")
        for case in routes:
            if case.get("custom") != "outer_return": continue
            e = next((e for e in case["manifest"]["connections"] if e.get("outer_return")), {})
            if e.get("purpose") != "outer_return" or e.get("recipe") != "ferry_dock": problems.append("authored outer ferry intent has no actual recipe consumer")
    if not rolled_zero_tested:''');p.write_text(s)
