class_name PlainsShotLatchPlanner
extends RefCounted
const VERSION := "plains-shot-latches-v4-remote-chain"
const CONFIG := "res://config/plains_shot_latches.json"
static func config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
static func recorded_plan(manifest: Dictionary) -> Dictionary:
	var settings := config()
	var result := {"version": VERSION, "configuration": settings, "latches": []}
	for index: int in manifest.get("nodes", []).size():
		var node: Dictionary = manifest.nodes[index]
		if not settings.modules.has(node.module_id):
			continue
		var data: Dictionary = settings.modules[node.module_id]
		var definition := RandomStageGenerator.new().definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		var bell := Vector2(data.bell[0], data.bell[1])
		var gate := Rect2(data.gate[0], data.gate[1], data.gate[2], data.gate[3])
		var sequence_gate:Array=data.get("sequence_gate",[]).duplicate()
		if definition.mirrored_horizontal:
			var axis := definition.world_bounds.position.x + definition.world_bounds.end.x
			bell.x = axis-bell.x
			gate.position.x = axis-gate.end.x
			if not sequence_gate.is_empty():sequence_gate[0]=axis-float(sequence_gate[0])-float(sequence_gate[2])
		result.latches.append({"id":"windchime_%s" % node.id, "node_index":index, "module_id":node.module_id, "kind":data.kind, "bell":[bell.x,bell.y], "gate":[gate.position.x,gate.position.y,gate.size.x,gate.size.y], "prompt":data.prompt, "link_color":data.link_color, "open_seconds":data.get("open_seconds",0), "sequence_offset":data.get("sequence_offset",[0,0]),"sequence_gate":sequence_gate,"actuator_id":data.get("actuator_id",""),"link_id":"LINK %02d"%(result.latches.size()+1),"sigil_index":result.latches.size()%3})
	return result
static func validate(manifest: Dictionary) -> bool:
	var generator := RandomStageGenerator.new()
	if not generator._same_data(manifest.get("shot_latch_plan"), recorded_plan(manifest)):
		return false
	for latch: Dictionary in manifest.shot_latch_plan.latches:
		var node: Dictionary = manifest.nodes[latch.node_index]
		var d := generator.definition_for(node.module_id,node.mirrored,node.reverse_traversal)
		var gate := Rect2(latch.gate[0],latch.gate[1],latch.gate[2],latch.gate[3])
		var bell_bounds := Rect2(Vector2(latch.bell[0],latch.bell[1])-Vector2(14,17),Vector2(28,34))
		var second := Rect2(bell_bounds.position + Vector2(latch.sequence_offset[0],latch.sequence_offset[1]) * Vector2(-1 if d.mirrored_horizontal else 1,1), bell_bounds.size)
		if not d.world_bounds.encloses(gate) or not d.world_bounds.encloses(bell_bounds) or not d.world_bounds.encloses(second):
			return false
		if not latch.sequence_gate.is_empty():
			var path_gate:=Rect2(latch.sequence_gate[0],latch.sequence_gate[1],latch.sequence_gate[2],latch.sequence_gate[3])
			if not d.world_bounds.encloses(path_gate):return false
			for anchor:Vector2 in d.anchors:
				if path_gate.intersects(Rect2(anchor-Vector2(12,18),Vector2(24,36)),true):return false
		for point: Vector2 in d.anchors:
			if gate.intersects(Rect2(point-Vector2(12,18),Vector2(24,36)),true):
				return false
	return true
