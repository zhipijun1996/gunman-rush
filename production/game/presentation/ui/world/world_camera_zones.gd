class_name WorldCameraZones
extends RefCounted
## Pure room composition/portal resolver. Actor position selects zones, never camera position.
var room: FixedWorldRoom
var encounters: Dictionary = {}
var zones: Array[Dictionary] = []
var links: Array[Dictionary] = []
var active_id := ""
var transition: Dictionary = {}
var candidate_id := ""
var candidate_age := 0.0
var exit_margin := 24.0
var enter_seconds := .1

func configure(value: FixedWorldRoom, settings: Dictionary) -> void:
	room=value;zones.clear();links.clear();transition.clear();candidate_id="";candidate_age=0
	exit_margin=float(settings.zone_exit_margin);enter_seconds=float(settings.zone_enter_seconds)
	var config: Dictionary=room.contract.camera
	var extent:=FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units)
	for raw: Dictionary in config.get("zones",[]):
		var zone_data := raw.duplicate(true)
		if zone_data.has("encounter"):
			zone_data["arena"] = true
			zone_data["look_up"] = false
			zone_data["look_down"] = false
		zones.append(zone_data)
	if zones.is_empty():
		zones.append({"id":"main","profile":config.get("profile","bounded_follow"),"trigger":pack(extent),"display":pack(extent),"priority":0})
	for raw: Dictionary in config.get("links",[]): links.append(raw.duplicate(true))
	# Combat composition is authored with the fixed_arena profile in schema 3.
	active_id=""

static func pack(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func zone(id: String) -> Dictionary:
	for z: Dictionary in zones:
		if str(z.id)==id:return z
	return zones[0]
func available(row: Dictionary) -> bool:
	if row.has("requires") and (room.services == null or not room.services.state.holds(row.requires)):
		return false
	if row.has("mechanism"):
		var source: Node = room.element_runtime.nodes.get(row.mechanism)
		if source == null or not source.has_method("element_state"):
			return false
		# element_state is the accepted live state, including the restored save
		# and any authored initial value before the first switch transaction.
		var committed: Dictionary = source.element_state()
		if committed.get("active") != true: return false
	if row.has("encounter"):
		var encounter := encounters.get(row.encounter) as WorldRoomEncounter
		return encounter != null and encounter.battle_active()
	return true
func passage_available(link: Dictionary) -> bool:
	return available(link) and available(zone(link.a)) and available(zone(link.b))

func select_initial(point: Vector2) -> void:
	var best:=-INF
	for z: Dictionary in zones:
		if not available(z):continue
		var trigger:=FixedWorldProvider.rect(z.trigger)
		var score:=float(z.get("priority",0))*1000000.0-point.distance_squared_to(point.clamp(trigger.position,trigger.end))
		if trigger.has_point(point):score+=1e12
		if score>best:best=score;active_id=str(z.id)
	transition.clear();candidate_id="";candidate_age=0

func update(point: Vector2, delta: float) -> Dictionary:
	if active_id.is_empty():select_initial(point)
	var current:=zone(active_id)
	if not transition.is_empty():
		# Reversal follows the same portal parameter. Opening alone never starts this.
		if not passage_available(transition):transition.clear()
		else:
			var t:=portal_progress(transition,point)
			var band:=FixedWorldProvider.rect(transition.band)
			var to_id:=str(transition.b)
			if t>=1 and not band.grow(exit_margin).has_point(point):active_id=to_id;transition.clear()
			elif t<=0 and not band.grow(exit_margin).has_point(point):active_id=str(transition.a);transition.clear()
			else:return {"a":zone(str(transition.a)),"b":zone(to_id),"blend":smoothstep(0,1,t),"portal":transition}
	current=zone(active_id)
	for link: Dictionary in links:
		if active_id not in [str(link.a),str(link.b)] or not passage_available(link):continue
		if FixedWorldProvider.rect(link.band).has_point(point):
			transition=link.duplicate(true)
			return {"a":zone(str(link.a)),"b":zone(str(link.b)),"blend":smoothstep(0,1,portal_progress(link,point)),"portal":link}
	# Explicitly linked zones may only be entered through their connection bands.
	var chosen:=current
	for z: Dictionary in zones:
		if str(z.id)==active_id or not available(z):continue
		var linked:=false
		for link: Dictionary in links:
			if str(z.id) in [str(link.a),str(link.b)]:linked=true;break
		if linked:continue
		if FixedWorldProvider.rect(z.trigger).has_point(point) and (int(z.get("priority",0))>int(chosen.get("priority",0)) or not available(current) or not FixedWorldProvider.rect(current.trigger).grow(exit_margin).has_point(point)):chosen=z
	if not available(current):
		for z: Dictionary in zones:
			if available(z) and FixedWorldProvider.rect(z.trigger).has_point(point):chosen=z;break
	if str(chosen.id)!=active_id:
		if candidate_id!=str(chosen.id):candidate_id=str(chosen.id);candidate_age=0
		candidate_age+=delta
		if candidate_age>=enter_seconds:active_id=candidate_id;candidate_age=0
	else:candidate_id="";candidate_age=0
	return {"a":zone(active_id),"b":zone(active_id),"blend":0.0,"portal":{}}

static func portal_progress(link: Dictionary, point: Vector2) -> float:
	var band:=FixedWorldProvider.rect(link.band)
	var axis:=0 if str(link.get("axis","x"))=="x" else 1
	var t:=clampf((point[axis]-band.position[axis])/band.size[axis],0,1)
	return 1.0-t if float(link.get("direction",1))<0 else t

static func center_range(display: Rect2, half: Vector2) -> Rect2:
	# Small axes have one legal center, never a reversed clamp interval.
	var low:=display.position+half
	var high:=display.end-half
	for axis: int in 2:
		if low[axis]>high[axis]:low[axis]=display.get_center()[axis];high[axis]=low[axis]
	return Rect2(low,high-low)
