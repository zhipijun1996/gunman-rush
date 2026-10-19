extends SceneTree
func _initialize()->void:
	var tuning:=PlayerTuning.load_default()
	var rows:Array=[]
	for difficulty:String in ["intro","advanced"]:
		var generator:=PlainsRegionGenerator.new()
		generator.root_bell_mode="v3"
		var result:=generator.generate("level-design-v2-baseline/08",tuning,false,"",difficulty)
		if not result.ok:printerr(result);quit(1);return
		var m:Dictionary=result.manifest
		var count:=0;var aligned:=0;var one_way:=0;var moving:=0;var examples:Array=[];var min_width:=INF;var min_height:=INF
		for n:Dictionary in m.nodes:
			var d:=PlainsRegionGenerator.definition(n)
			var offset:=Vector2(n.offset[0],n.offset[1])
			moving+=d.ferries.size()
			for i:int in d.platforms.size():
				var r:=Rect2(offset+d.platforms[i].position,d.platforms[i].size)
				count+=1
				if i in d.one_way_platform_indices:one_way+=1;continue
				min_width=minf(min_width,r.size.x);min_height=minf(min_height,r.size.y)
				var values:Array=[r.position.x,r.position.y,r.end.x,r.end.y]
				var valid:=true
				for v:float in values:
					if not is_zero_approx(fposmod(v,32.0)):valid=false
				if valid:aligned+=1
				elif examples.size()<10:examples.append({"node":n.id,"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
		rows.append({"difficulty":difficulty,"seed":m.seed,"manifest_hash":m.manifest_hash,"node_count":m.nodes.size(),"all_platforms":count,"solid_platforms":count-one_way,"all_bounds_aligned32":aligned,"one_way":one_way,"moving":moving,"support_columns":m.ground_supports.size(),"min_solid_width":min_width,"min_solid_height":min_height,"unaligned_examples":examples})
	var f:=FileAccess.open("res://build/pixel-formal-audit/geometry_inventory.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"Generated definitions only; no route traversal or visual acceptance","rows":rows},"  ")+"\n");f.close()
	print("FORMAL GEOMETRY INVENTORY ",JSON.stringify(rows))
	quit(0)
