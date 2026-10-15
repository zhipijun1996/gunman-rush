from pathlib import Path
p=Path('tests/plains_redesign_spatial_runner.gd');s=p.read_text();s=s.replace('"tick":trace_ticks,"position":','"floor_colliders":floor_colliders(),"tick":trace_ticks,"position":');s=s.replace('func _initialize() -> void:','''	func floor_colliders() -> Array:
		var rows: Array=[]
		for index: int in motor.get_slide_collision_count():
			var hit:=motor.get_slide_collision(index)
			if hit.get_normal().dot(motor.up_direction)<.7:continue
			var body:=hit.get_collider() as Node2D
			if is_instance_valid(body):rows.append({"path":str(body.get_path()),"instance_id":body.get_instance_id(),"position":[hit.get_position().x,hit.get_position().y]})
		return rows
func _initialize() -> void:''');p.write_text(s)
p=Path('tools/run_plains_redesign_spatial_tests.py');s=p.read_text();insert='''
def validate_receiver_fault(data, complete):
    fault = data.get("receiver_fault", {})
    if fault.get("complete") is not complete or data.get("platform_only") is not (not complete): return False
    receiver = fault.get("receiver", [])
    before, after, removed = fault.get("support_before", []), fault.get("support_after", []), fault.get("removed_fragments", [])
    if len(receiver) != 4 or receiver[2] <= 0 or receiver[3] <= 0 or not before: return False
    x, y, w, h = receiver
    expected = []
    expected_removed = []
    untouched_ids = set()
    for body in before:
        rect = body.get("rect", [])
        if len(rect) != 4 or body.get("collision_layer") != 1: return False
        left, top, width, depth = rect
        a, b = max(left, x), min(left + width, x + w)
        attached = abs(top - (y + h)) < .001 and b > a
        if not complete or not attached:
            expected.append(rect); untouched_ids.add(body["instance_id"]); continue
        expected_removed.append([a, top, b-a, depth])
        if a > left: expected.append([left, top, a-left, depth])
        if b < left+width: expected.append([b, top, left+width-b, depth])
    def normalized(rows): return sorted(tuple(round(v, 3) for v in row) for row in rows)
    if normalized(expected) != normalized([b.get("rect", []) for b in after]): return False
    if normalized(removed) != normalized(expected_removed) or (complete and not removed): return False
    if not untouched_ids.issubset({b.get("instance_id") for b in after}): return False
    if not complete:
        observations = data.get("observations", [])
        if len(observations) != 1 or not observations[0].get("frames"): return False
        frame = observations[0]["frames"][-1]
        actual_contacts = {row.get("instance_id") for row in frame.get("floor_colliders", [])}
        if frame.get("grounded") is not True or not actual_contacts.intersection(untouched_ids): return False
        # The original fall predicate MUST still reject this incomplete deletion.
        if frame["position"][1] > 500: return False
    return True

''';s=s.replace('def validate_native(data, negative=False):',insert+'def validate_native(data, negative=False):');s=s.replace('return data.get("failures", 0) > 0 and observations[0]','return validate_receiver_fault(data, True) and data.get("failures", 0) > 0 and observations[0]');s=s.replace('("positive", "deleted_receiver", "corpus")','("positive", "deleted_receiver", "platform_only_control", "corpus")');s=s.replace('negative = mode == "deleted_receiver"','negative = mode in ("deleted_receiver", "platform_only_control")');s=s.replace('if negative:\n                command.append("--delete-receiver")','if negative:\n                command.append("--delete-receiver-platform-only" if mode == "platform_only_control" else "--delete-receiver")');s=s.replace('valid = (result["exit_code"] == 1 if negative else result["status"] == "passed") and (validate_corpus(data) if mode == "corpus" else validate_native(data, negative))','valid = (result["exit_code"] == 1 if negative else result["status"] == "passed") and (validate_corpus(data) if mode == "corpus" else (validate_receiver_fault(data, False) and not validate_native(data, True)) if mode == "platform_only_control" else validate_native(data, negative))');p.write_text(s)
