extends SceneTree
const Base = preload("/workspace/refactor-evidence/combat-perf-deploy-01/root-rig/paired-e42/baseline_e42.gd")
var failures := 0
var rows: Array = []

class BenchCanvas:
	extends Node2D
	var rig: RefCounted
	var pose: Dictionary = {}
	var samples: Array[float] = []
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		rig.call("draw_pose", self, pose)
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)

func _initialize() -> void:
	run.call_deferred()

func _stats(samples: Array[float]) -> Dictionary:
	var total := 0.0
	for value: float in samples: total += value
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	return {"samples":samples.size(),"mean_ms":total/samples.size(),"p50_ms":ordered[int((ordered.size()-1)*.50)],"p95_ms":ordered[int((ordered.size()-1)*.95)],"total_ms":total}

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("E42 PAIRED: "+label)

func _new_rig(variant: int, kind: StringName) -> RefCounted:
	return Base.E42Skin.new(kind) if variant==0 else PlainsRevisionSkin.new(kind)

func _construction() -> void:
	# No candidate/base instances exist before the first pair. Texture/script
	# preloading occurs before this timing, so cold here means constructor only.
	for kind: StringName in [&"root_bell", &"patrol"]:
		for variant: int in [0,1]:
			var started := Time.get_ticks_usec()
			var rig := _new_rig(variant,kind)
			var elapsed := float(Time.get_ticks_usec()-started)/1000.0
			rows.append({"scope":"first_constructor","kind":kind,"variant":"e42" if variant==0 else "candidate","ms":elapsed,"vertices":rig.get("_points").size(),"cold_topology":kind==&"root_bell","cold_kind":true})
			_check(rig.get("_points").size()==625,"constructor625")
			rig = null
	for round_index: int in 3:
		for kind: StringName in [&"root_bell", &"patrol"]:
			var samples: Array[float] = []
			var baseline_samples: Array[float] = []
			for index: int in 80:
				for variant: int in ([0,1] if index%2==0 else [1,0]):
					var started := Time.get_ticks_usec()
					var rig := _new_rig(variant,kind)
					var elapsed := float(Time.get_ticks_usec()-started)/1000.0
					if variant==0: baseline_samples.append(elapsed)
					else: samples.append(elapsed)
					_check(rig.get("_points").size()==625,"repeat constructor625")
					rig = null
			rows.append({"scope":"repeat_constructor","round":round_index,"kind":kind,"baseline":_stats(baseline_samples),"candidate":_stats(samples)})

func _pose(situation: String, frame: int) -> Dictionary:
	return {"clock":1.0+float(frame)/60.0,"stride":.2+float(frame)*.11,"travel":.8,"drive":.3,"appendage_follow":.6,"load":.6 if situation!="moving" else 0.0,"strike":.4 if situation!="moving" else 0.0,"recovery":.3,"hurt":.5 if situation!="moving" else 0.0,"dead":situation=="dying","death":clampf(float(frame)/60.0,0.0,1.0),"death_clock":.02+float(frame)*.01,"air":false,"vertical":-45.0}

func _draw_samples() -> void:
	for situation: String in ["moving","hurt_attack","dying"]:
		for variant: int in [0,1]:
			var canvas := BenchCanvas.new()
			canvas.rig = _new_rig(variant,&"root_bell")
			canvas.pose = _pose(situation,31)
			canvas.position = Vector2(120,120)
			root.add_child(canvas)
			for draw_index: int in 2:
				var prior := canvas.samples.size()
				canvas.queue_redraw()
				for attempt: int in 8:
					await process_frame
					if canvas.samples.size()>prior: break
				_check(canvas.samples.size()>prior,"actual draw callback")
			rows.append({"scope":"new_instance_first_draw_and_repeat_cpu","case":situation,"variant":"e42" if variant==0 else "candidate","samples_ms":canvas.samples.duplicate(),"cold_weight_template":variant==1 and situation=="moving","topology_already_warm":true})
			canvas.rig = null
			canvas.queue_free()
			await process_frame

func _kernel() -> void:
	var baseline := Base.E42Skin.new(&"root_bell")
	var rig := PlainsRevisionSkin.new(&"root_bell")
	_check(baseline._units.to_byte_array()==rig._units.to_byte_array(),"UV byte identity")
	_check(baseline._points.to_byte_array()==rig._points.to_byte_array(),"neutral point byte identity")
	var weights: Array[PlainsRevisionWeights] = []
	for uv: Vector2 in rig._units: weights.append(PlainsRevisionWeights.new(uv,&"root_bell"))
	for round_index: int in 3:
		for situation: String in ["moving","hurt_attack","dying"]:
			var samples: Array[float] = []
			var baseline_samples: Array[float] = []
			var checked := 0
			for frame: int in 63:
				var values := _pose(situation,frame)
				var baseline_points := PackedVector2Array()
				var candidate_points := PackedVector2Array()
				for variant: int in ([0,1] if frame%2==0 else [1,0]):
					var started := Time.get_ticks_usec()
					if variant==0:
						var prepared := Base.E42Pose.prepare(values)
						for index: int in baseline._points.size(): baseline_points.append(baseline.deform_prepared(baseline._points[index],baseline._units[index],prepared,weights[index]))
					else:
						var prepared := PlainsRevisionPose.prepare(values)
						for index: int in rig._points.size(): candidate_points.append(rig.deform_prepared(rig._points[index],rig._units[index],prepared,weights[index]))
					var elapsed := float(Time.get_ticks_usec()-started)/1000.0
					if frame>=3:
						if variant==0: baseline_samples.append(elapsed)
						else: samples.append(elapsed)
				_check(baseline_points.to_byte_array()==candidate_points.to_byte_array(),"kernel bytes/"+situation+"/"+str(frame))
				checked += candidate_points.size()
			rows.append({"scope":"prepare_and625_kernel","round":round_index,"case":situation,"vertices_per_sample":625,"checked_vertices":checked,"warmup_excluded":3,"baseline":_stats(baseline_samples),"candidate":_stats(samples)})

func run() -> void:
	_construction()
	await _draw_samples()
	_kernel()
	print("COMBAT_E42_PAIRED "+JSON.stringify({"rows":rows,"failures":failures,"scope":"Exact e42 versus current candidate in one native headless process; alternating constructor/kernel order. Draw callbacks measure CPU work/submission only. No browser, GPU timing, game AI, phone FPS or full-map startup claim. Dying forced kernel includes complete collapse; it does not measure settled draw-cache savings."}))
	quit(1 if failures else 0)
