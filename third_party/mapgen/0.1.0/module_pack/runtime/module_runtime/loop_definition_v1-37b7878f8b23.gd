extends ModuleMovingPlatformDefinition
## NEW trajectory Cell. Actor/body implementation remains the original one.
@export var points:=PackedVector2Array()

func is_valid() -> bool:
	if platform_id.is_empty() or points.size()<4 or points[0]!=points[-1]:return false
	if not size.is_finite() or size.x<=0 or size.y<=0:return false
	if not is_finite(travel_duration) or travel_duration<=0 or dwell_duration!=0:return false
	if not is_finite(initial_phase) or initial_phase<0 or initial_phase>=1:return false
	var distinct: Dictionary={}
	var area:=0.0
	for i: int in range(points.size()-1):
		if not points[i].is_finite() or not points[i+1].is_finite():return false
		if points[i].distance_to(points[i+1])<=.00001:return false
		distinct[points[i]]=true
		area+=points[i].cross(points[i+1])
	return distinct.size()>=3 and absf(area)>.00001

func period() -> float:
	return travel_duration

func at_time(clock: float) -> Vector2:
	var lengths:=PackedFloat64Array()
	var total:=0.0
	for i: int in range(points.size()-1):
		var length: float=points[i].distance_to(points[i+1])
		lengths.append(length);total+=length
	var remaining: float=fposmod(clock/period()+initial_phase,1.0)*total
	for i: int in range(lengths.size()):
		if remaining<=lengths[i] or i==lengths.size()-1:
			return points[i].lerp(points[i+1],remaining/lengths[i])
		remaining-=lengths[i]
	return points[0]

func envelope() -> Rect2:
	var low:=points[0]
	var high:=points[0]
	for point: Vector2 in points:
		low=low.min(point);high=high.max(point)
	return Rect2(low-size*.5,high-low+size)
