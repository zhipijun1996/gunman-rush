from pathlib import Path
p=Path('tests/plains_redesign_scene_runner.gd');s=p.read_text();old='''var ferry_paths: Array=[]
			for module: PlatformingModule in trace.stage.modules:
				for ferry: ModuleMovingPlatform in module.moving_platforms:ferry_paths.append(str(ferry.get_path()))''';new='''var ferry_paths: Array=[]
			var outer_connection: Dictionary=trace.stage.manifest.connections.filter(func(e:Dictionary):return e.get("outer_return",false))[0]
			var carrier_modules: Array=[]
			for index: int in outer_connection.modules:
				var module: PlatformingModule=trace.stage.modules[index]
				carrier_modules.append({"node_id":trace.stage.manifest.nodes[index].id,"module_id":str(module.definition.module_id),"path":str(module.get_path())})
				for ferry: ModuleMovingPlatform in module.moving_platforms:ferry_paths.append(str(ferry.get_path()))''';assert old in s;s=s.replace(old,new);s=s.replace('"ferry_contacts":contacts,"actual_edges"','"ferry_contacts":contacts,"ferry_paths":ferry_paths,"carrier_modules":carrier_modules,"connection_id":outer_connection.id,"actual_edges"');s=s.replace('check(not contacts.is_empty() if mode=="outer_return" else true,"lower return actually rides a real ferry body")','''check(not contacts.is_empty() if mode=="outer_return" else true,"lower return actually rides the exact new horizontal connection carrier")
			if ok and mode=="outer_return":
				var return_begin: int=trace.trace_ticks
				var returned: bool=await trace.follow_to("area_3_2")
				if returned:returned=await trace.follow_to("area_3_3")
				route_comparison["cycle_return"]={"path":["area_4_2","area_3_2","area_3_3"],"start_tick":return_begin,"end_tick":trace.trace_ticks,"position":pair(trace.motor.global_position),"reached":returned,"actual_edges":trace.observed_edges.filter(func(e:Dictionary):return e.start_tick>=return_begin)}
				check(returned,"same body closes lower-out upper-back circuit without repeating entry shaft")
				ok=returned''');p.write_text(s)
p=Path('tools/run_plains_redesign_scene_tests.py');s=p.read_text();s=s.replace('if e.get("purpose") != "outer_return" or e.get("recipe") != "ferry_dock": problems.append("authored outer ferry intent has no actual recipe consumer")','''if e.get("purpose") != "outer_return" or e.get("recipe") != "ferry_dock": problems.append("authored outer ferry intent has no actual recipe consumer")
            expected_nodes = {case["manifest"]["nodes"][i]["id"] for i in e.get("modules", [])}
            modules = lower.get("carrier_modules", [])
            paths = lower.get("ferry_paths", [])
            if not modules or {m.get("node_id") for m in modules} != expected_nodes or any(m.get("module_id") != "plains_ferry_channel" for m in modules) or not paths or any(not any(p.startswith(m["path"]+"/") for m in modules) for p in paths):
                problems.append("new horizontal carrier provenance absent")
            indexed = {f["tick"]: f for f in case["frames"]}
            contacts = lower.get("ferry_contacts", [])
            if not contacts or any(row.get("collider") not in paths or not any(hit.get("collider")==row["collider"] for hit in indexed.get(row.get("tick"),{}).get("collisions",[])) for row in contacts):
                problems.append("new horizontal ferry has no matching actual Motor contact")
            if contacts and (not indexed.get(contacts[0]["tick"]-1) or not indexed.get(contacts[-1]["tick"]+1) or not lower["start_tick"]<contacts[0]["tick"]<=contacts[-1]["tick"]<lower["end_tick"]):
                problems.append("new ferry boarding/departure boundary observations absent")
            cycle = lower.get("cycle_return", {})
            if not cycle.get("reached") or len(cycle.get("actual_edges",[])) != 2 or math.dist(cycle.get("position",[1e9,1e9]),lower["start_position"])>2:
                problems.append("same-body actual lower-out upper-back cycle absent")''');s=s.replace('report["acceptance_counterexamples"] =','''broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="outer_return"); c["route_comparison"]["ferry_contacts"][0]["collider"]="unrelated/well_lift"; mutations["substituted_vertical_lift_for_horizontal_boat"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="outer_return"); c["route_comparison"]["cycle_return"]={}; mutations["missing_actual_closed_cycle"] = broken
        report["acceptance_counterexamples"] =''');p.write_text(s)
p=Path('tools/run_plains_redesign_spatial_tests.py');s=p.read_text();s=s.replace('(folder / "validator_refusals.json").write_text','''complete = json.loads((folder / "deleted_receiver.json").read_text())
        residue = json.loads((folder / "platform_only_control.json").read_text())
        for name in ("all_earth_deleted", "neighbor_body_deleted", "foreign_removed_fragment", "platform_only_declared_complete"):
            corrupt = copy.deepcopy(residue if name=="platform_only_declared_complete" else complete)
            fault = corrupt["receiver_fault"]
            if name=="all_earth_deleted": fault["support_after"]=[]
            elif name=="neighbor_body_deleted": fault["support_after"].pop()
            elif name=="foreign_removed_fragment": fault["removed_fragments"].append([0,0,10,10])
            else: fault["complete"]=True;corrupt["platform_only"]=False
            refused = not validate_receiver_fault(corrupt, True)
            refusals.append({"case":name,"refused":refused})
            if not refused:raise RuntimeError("Receiver fault validator accepted unrelated deletion: "+name)
        (folder / "validator_refusals.json").write_text''');p.write_text(s)
