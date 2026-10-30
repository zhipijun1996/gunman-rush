extends RefCounted
const DEFINITION=preload("loop_definition_v1-37b7878f8b23.gd")
const KIND="closed_polyline_loop/v1"

static func from_raw(raw: Dictionary):
	var d=DEFINITION.new()
	d.platform_id=StringName(raw.platform_id)
	d.size=Vector2(raw.size[0],raw.size[1])
	d.travel_duration=float(raw.loop_period)
	d.dwell_duration=0
	d.initial_phase=float(raw.get("initial_phase",0))
	for p: Array in raw.loop_points:d.points.append(Vector2(p[0],p[1]))
	d.start=d.points[0];d.finish=d.points[-1]
	return d

static func raw_from_document(doc: Dictionary) -> Dictionary:
	assert(doc.get("schema")=="gunman-rush-level-sketch/v1")
	var deck: Dictionary={}
	var track: Dictionary={}
	for o: Dictionary in doc.objects:
		if o.get("id")=="n25-cell-deck":deck=o
	for o: Dictionary in doc.objects:
		if o.get("id")==deck.get("trackId"):track=o
	assert(track.get("type")=="trackLine" and track.get("mode")=="loop" and float(track.get("dwell",0))==0 and float(deck.get("rotation",0))==0)
	var ps: Array=[]
	for p: Dictionary in track.points:ps.append([float(p.x),float(p.y)])
	return {"platform_id":"loop-deck","trajectory_kind":KIND,"start":ps[0],"finish":ps[-1],"size":[float(deck.w),float(deck.h)],"loop_points":ps,"loop_period":float(track.duration),"initial_phase":float(track.get("initialPhase",0)),"travel_duration":float(track.duration),"dwell_duration":0}

static func install(definition: PlatformingModuleDefinition,data: Dictionary) -> void:
	var raw_platforms: Array=data.get("moving_platforms",[])
	for i: int in range(raw_platforms.size()):
		var raw: Dictionary=raw_platforms[i]
		if raw.get("trajectory_kind")!=KIND:continue
		if data.has("trajectory_document"):
			var reloaded:=raw_from_document(data.trajectory_document)
			assert(reloaded.loop_points==raw.loop_points and reloaded.loop_period==raw.loop_period and reloaded.size==raw.size and reloaded.initial_phase==raw.initial_phase)
			raw=reloaded
		definition.ferries[i]=from_raw(raw)

static func definition_audit(d) -> Dictionary:
	var malformed=[]
	for kind: String in ["open","zero_segment","collinear","nonfinite","bad_period","bad_phase","bad_size"]:
		var b=DEFINITION.new();b.points=d.points.duplicate();b.size=d.size;b.travel_duration=d.travel_duration;b.dwell_duration=0;b.initial_phase=d.initial_phase
		if kind=="open":b.points[-1]=b.points[-1]+Vector2(1,0)
		elif kind=="zero_segment":b.points[1]=b.points[0]
		elif kind=="collinear":b.points=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(2,0),Vector2(0,0)])
		elif kind=="nonfinite":b.points[1]=Vector2(NAN,0)
		elif kind=="bad_period":b.travel_duration=0
		elif kind=="bad_phase":b.initial_phase=1
		elif kind=="bad_size":b.size.x=0
		malformed.append({"kind":kind,"rejected":not b.is_valid()})
	var e: Rect2=d.envelope()
	return {"valid":d.is_valid(),"period":d.period(),"points":d.points.size(),"period_position_error":d.at_time(0).distance_to(d.at_time(d.period())),"envelope":[e.position.x,e.position.y,e.size.x,e.size.y],"malformed":malformed}

static func snapshot(host) -> Dictionary:
	var out: Array=[]
	for p: ModuleMovingPlatform in host.context.module.moving_platforms:
		if not p.definition.get_script()==DEFINITION:continue
		var expected: Vector2=p.definition.at_time(host.context.module.clock)
		out.append({"id":str(p.definition.platform_id),"actual_position":[p.position.x,p.position.y],"expected_position":[expected.x,expected.y],"position_error":p.position.distance_to(expected),"rotation":p.rotation,"bell_controlled":p.bell_controlled,"period":p.definition.period()})
	var contacts: Array=[]
	for i: int in host.motor.get_slide_collision_count():
		var hit: KinematicCollision2D=host.motor.get_slide_collision(i);var n:=hit.get_normal();var body=hit.get_collider()
		contacts.append({"collider":str(body.name) if body!=null else "UNKNOWN","normal":[n.x,n.y]})
	var r: Vector2=host.motor.recoil_velocity
	return {"platforms":out,"contacts":contacts,"recoil_velocity":[r.x,r.y],"shot_charges":host.controller.action_resources.shot_charges,"normal_velocity":[host.motor.normal_velocity.x,host.motor.normal_velocity.y]}
