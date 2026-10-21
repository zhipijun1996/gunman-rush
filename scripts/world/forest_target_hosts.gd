class_name ForestTargetHosts
extends RefCounted
## Runtime-only v14 presentation. Never edits the frozen manifest or adds nodes.
const PRESENTATION_REVISION := "forest-target-hosts-r4"
const LAYOUT := "forest-fruit-routes-v14"
const GOLDEN_GROUPS: Array[String] = ["fallen_fork","spiral_crown","gate_pull","guardian_pair","queen_rib","hollow_elbow"]

static func build(m: Dictionary) -> Dictionary:
	var audit := {"presentation_revision":PRESENTATION_REVISION,"layout":str(m.get("layout_version","")),"manifest_hash":str(m.get("manifest_hash","")),"annotation_scope":"serialized_v14_pending_is_preserved_historical_design_annotation","acceptance_scope":"runtime_candidate_host_resolution_is_not_visual_acceptance","mounts":[],"host_boughs":[],"unresolved":[]}
	if m.get("layout_version") not in [LAYOUT,"forest-bible-world-v15"]:return audit
	var anchors: Dictionary = {}
	var supports: Dictionary = {}
	for row: Dictionary in m.get("hook_anchors",[]):
		if row.get("fruit_presentation")=="existing_marker_pending_local_support":anchors[str(row.id)]=row
	for row: Dictionary in m.get("platforms",[]):supports[str(row.id)]=row
	var candidates: Dictionary = {}
	if "fallen_fork" in GOLDEN_GROUPS:_include(audit,candidates,_fallen_fork(anchors,supports))
	if "spiral_crown" in GOLDEN_GROUPS:
		_include(audit,candidates,_pod_pendant(anchors,supports))
		_include(audit,candidates,_crown_pair(anchors,supports))
	if "gate_pull" in GOLDEN_GROUPS:_include(audit,candidates,_gate_pull(anchors,supports))
	if "guardian_pair" in GOLDEN_GROUPS:_include(audit,candidates,_guardian_pair(anchors,supports))
	if "queen_rib" in GOLDEN_GROUPS:_include(audit,candidates,_queen_rib(anchors,supports))
	if "hollow_elbow" in GOLDEN_GROUPS:_include(audit,candidates,_hollow_elbow(anchors,supports))
	for anchor: Dictionary in m.get("hook_anchors",[]):
		if anchor.get("fruit_presentation")!="existing_marker_pending_local_support":continue
		var id := str(anchor.id)
		var mount := {"target_id":id,"target_position":anchor.position.duplicate(),"role":str(anchor.get("fruit_role","")),"serialized_annotation":str(anchor.fruit_presentation),"presentation":"original_functional_ring","resolved":false,"resolved_source":"none","reason":"group_not_yet_authored_or_reviewed","visual_acceptance":"unverified"}
		if candidates.has(id):
			mount.merge(candidates[id],true)
		else:audit.unresolved.append(id)
		audit.mounts.append(mount)
	return audit

static func _fallen_fork(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var crown_id := "broken_arch__crown_ring"
	var lower_id := "upper_spiral__spiral_lower"
	var host_id := "broken_arch__root_arch"
	if not supports.has(host_id) or not (anchors.has(crown_id) or anchors.has(lower_id)):return {}
	var host: Dictionary=supports[host_id]
	if host.get("scene_kind")!="fallen_log" or bool(host.get("one_way",true)):return {}
	var rect := _rect(host.rect)
	var crown := _point(anchors[crown_id].position) if anchors.has(crown_id) else _point(anchors[lower_id].position)+Vector2(-160,90)
	var crown_tip := crown+Vector2(0,-26)
	var root := Vector2(rect.end.x,clampf(crown_tip.y,rect.position.y+12,rect.end.y-12))
	var points: Array = [_pair(root),_pair(root+Vector2(52,-36)),_pair(root+Vector2(112,-64))]
	var branches: Array = []
	var mounts: Dictionary = {}
	if anchors.has(lower_id):
		var lower := _point(anchors[lower_id].position)
		if lower.x<=root.x:return {}
		var lower_tip := lower+Vector2(0,-26)
		points.append_array([_pair(lower_tip+Vector2(-133,20)),_pair(lower_tip+Vector2(-70,45)),_pair(lower_tip+Vector2(-25,20)),_pair(lower_tip)])
		mounts[lower_id]=_mount(lower_id,lower,host,root,lower_tip,"runtime_fallen_fork",true,"fallen_fork")
	if anchors.has(crown_id):
		if crown.x<=root.x:return {}
		var branch: Array = [points[2],_pair(crown_tip+Vector2(-20,-35)),_pair(crown_tip)]
		if anchors.has(lower_id):branches.append(branch)
		else:points.append_array(branch.slice(1))
		mounts[crown_id]=_mount(crown_id,crown,host,root,crown_tip,"runtime_fallen_fork",true,"fallen_fork")
	return {"bough":{"id":"runtime_fallen_fork","host_support_id":host_id,"root":_pair(root),"points":points,"branches":branches,"base_width":11.0,"standing_edge":false},"mounts":mounts}

static func _include(audit: Dictionary,mounts: Dictionary,candidate: Dictionary) -> void:
	if candidate.is_empty():return
	audit.host_boughs.append(candidate.bough)
	mounts.merge(candidate.mounts)

static func _pod_pendant(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var id := "upper_spiral__spiral_middle"
	var host_id := "upper_spiral_pod_bough"
	if not anchors.has(id) or not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="living_bough":return {}
	var rect := _rect(host.rect)
	var at := _point(anchors[id].position)
	if at.x<rect.end.x or at.y<=rect.end.y:return {}
	var root := Vector2(rect.end.x-5,rect.end.y-2)
	var tip := at+Vector2(0,-26)
	var bough := {"id":"runtime_pod_pendant","host_support_id":host_id,"root":_pair(root),"points":[_pair(root),_pair(root+Vector2(30,12)),_pair(tip+Vector2(7,-57)),_pair(tip+Vector2(10,-27)),_pair(tip)],"base_width":8.0,"standing_edge":false}
	return {"bough":bough,"mounts":{id:_mount(id,at,host,root,tip,bough.id,true,"pod_pendant")}}

static func _crown_pair(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var host_id := "hollow__cavity_left_step"
	if not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="living_bough":return {}
	var rect := _rect(host.rect)
	var root := Vector2(rect.position.x+4,rect.end.y-3)
	var join := root+Vector2(-145,-62)
	var points: Array = [_pair(root),_pair(root+Vector2(-48,-45)),_pair(join)]
	var branches: Array = []
	var mounts: Dictionary = {}
	var crown_id := "upper_spiral__spiral_crown"
	if anchors.has(crown_id):
		var at := _point(anchors[crown_id].position)
		var tip := at+Vector2(0,-26)
		if at.x>=root.x:return {}
		points.append_array([_pair(join+Vector2(-110,25)),_pair(tip+Vector2(55,-54)),_pair(tip)])
		mounts[crown_id]=_mount(crown_id,at,host,root,tip,"runtime_crown_pair",true,"crown_pair")
	var relay_id := "canopy_fork__relay_a"
	if anchors.has(relay_id):
		var at := _point(anchors[relay_id].position)
		var tip := at+Vector2(0,-26)
		if anchors.has(crown_id):
			branches.append([_pair(join),_pair(join+Vector2(-25,52)),_pair(tip+Vector2(-24,-35)),_pair(tip)])
		else:
			# No unused extension toward an already-rooted crown in map2.
			points=[_pair(root),_pair(Vector2(lerpf(root.x,tip.x,0.5),minf(root.y,tip.y)-35)),_pair(tip+Vector2(-22,-40)),_pair(tip)]
		mounts[relay_id]=_mount(relay_id,at,host,root,tip,"runtime_crown_pair",true,"crown_pair")
	if mounts.is_empty():return {}
	return {"bough":{"id":"runtime_crown_pair","host_support_id":host_id,"root":_pair(root),"points":points,"branches":branches,"base_width":12.0,"standing_edge":false},"mounts":mounts}

static func _gate_pull(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var id := "crown_approach_ring_0"
	if not anchors.has(id):return {}
	var at := _point(anchors[id].position)
	var host_id := "hollow__cavity_right_step" if at.y<300 else "hollow__cavity_exit"
	if not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="living_bough":return {}
	var rect := _rect(host.rect)
	var root := Vector2(rect.end.x-4,rect.position.y+rect.size.y*0.5)
	var tip := at+Vector2(0,-26)
	var points: Array
	if at.y>rect.end.y:
		points=[_pair(root),_pair(root+Vector2(48,20)),_pair(tip+Vector2(-72,-70)),_pair(tip+Vector2(-35,-8)),_pair(tip)]
	else:
		points=[_pair(root),_pair(root+Vector2(25,-35)),_pair(tip+Vector2(-30,-18)),_pair(tip)]
	var bough := {"id":"runtime_gate_pull","host_support_id":host_id,"root":_pair(root),"points":points,"base_width":10.0,"standing_edge":false}
	return {"bough":bough,"mounts":{id:_mount(id,at,host,root,tip,bough.id,false,"gate_pull")}}

static func _guardian_pair(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var host_id := "counter_branch"
	if not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="living_bough":return {}
	var rect := _rect(host.rect)
	var mounts: Dictionary = {}
	var paths: Array = []
	for id: String in ["inner_left","inner_right"]:
		if not anchors.has(id):continue
		var at := _point(anchors[id].position)
		var direction := 1.0 if id=="inner_left" else -1.0
		var root := Vector2(rect.position.x+4 if direction>0 else rect.end.x-4,rect.position.y+rect.size.y*0.5)
		var tip := at+Vector2(0,-26)
		paths.append([_pair(root),_pair(root+Vector2(direction*22,-38)),_pair(tip+Vector2(-direction*22,-16)),_pair(tip)])
		mounts[id]=_mount(id,at,host,root,tip,"runtime_guardian_pair",false,"guardian_pair")
	if paths.is_empty():return {}
	return {"bough":{"id":"runtime_guardian_pair","host_support_id":host_id,"root":paths[0][0],"points":paths[0],"branches":paths.slice(1),"base_width":9.0,"standing_edge":false},"mounts":mounts}

static func _queen_rib(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var id := "B"
	var host_id := "right_rib"
	if not anchors.has(id) or not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="hollow_bark":return {}
	var rect := _rect(host.rect)
	var at := _point(anchors[id].position)
	var root := Vector2(rect.end.x-4,rect.position.y+6)
	var tip := at+Vector2(0,-26)
	var bough := {"id":"runtime_queen_rib","host_support_id":host_id,"root":_pair(root),"points":[_pair(root),_pair(root+Vector2(32,-40)),_pair(tip+Vector2(-30,-27)),_pair(tip)],"base_width":11.0,"standing_edge":false}
	return {"bough":bough,"mounts":{id:_mount(id,at,host,root,tip,bough.id,false,"queen_rib")}}

static func _hollow_elbow(anchors: Dictionary,supports: Dictionary) -> Dictionary:
	var id := "hollow__cavity_ring_b"
	var host_id := "hollow__trunk_upper_cap"
	if not anchors.has(id) or not supports.has(host_id):return {}
	var host: Dictionary = supports[host_id]
	if host.get("scene_kind")!="hollow_bark":return {}
	var rect := _rect(host.rect)
	var at := _point(anchors[id].position)
	var root := Vector2(rect.end.x-4,rect.end.y-6)
	var tip := at+Vector2(0,-26)
	var bough := {"id":"runtime_hollow_elbow","host_support_id":host_id,"root":_pair(root),"points":[_pair(root),_pair(root+Vector2(28,30)),_pair(tip+Vector2(24,-34)),_pair(tip)],"base_width":10.0,"standing_edge":false}
	return {"bough":bough,"mounts":{id:_mount(id,at,host,root,tip,bough.id,true,"hollow_elbow")}}

static func _mount(id: String,at: Vector2,host: Dictionary,root: Vector2,tip: Vector2,bough_id: String,fruit: bool,kind: String) -> Dictionary:
	return {"target_id":id,"resolved":true,"presentation":"runtime_rooted_fruit" if fruit else "original_functional_ring","resolved_source":"actual_platform_perimeter_and_continuous_runtime_bough","reason":"candidate_requires_group_pixel_review","mount_kind":kind,"host_id":str(host.id),"host_rect":host.rect.duplicate(),"root":_pair(root),"stem_root":_pair(tip),"ring_neck":_pair(at+Vector2(0,-16)),"bough_id":bough_id}

static func mount_for(audit: Dictionary,target_id: String) -> Dictionary:
	for mount: Dictionary in audit.get("mounts",[]):
		if str(mount.target_id)==target_id:return mount
	return {}

static func draw(canvas: Node2D,audit: Dictionary) -> void:
	if audit.get("layout")!=LAYOUT:return
	for bough: Dictionary in audit.get("host_boughs",[]):ForestFruitBough.draw(canvas,bough)
	for mount: Dictionary in audit.get("mounts",[]):
		if not bool(mount.get("resolved",false)) or mount.get("presentation")=="runtime_rooted_fruit":continue
		canvas.draw_line(_point(mount.stem_root),_point(mount.ring_neck),Color("435d42"),3.0,false)

static func _point(at: Array) -> Vector2:return Vector2(float(at[0]),float(at[1]))
static func _pair(at: Vector2) -> Array:return [at.x,at.y]
static func _rect(at: Array) -> Rect2:return Rect2(float(at[0]),float(at[1]),float(at[2]),float(at[3]))
