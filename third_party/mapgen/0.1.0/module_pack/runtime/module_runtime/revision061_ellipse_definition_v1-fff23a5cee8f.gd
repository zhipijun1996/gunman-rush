extends ModuleMovingPlatformDefinition
var center:=Vector2(320,256)
var radii:=Vector2(160,144)
func is_valid() -> bool:
 return not platform_id.is_empty()and center.is_finite()and radii.is_finite()and radii.x>0 and radii.y>0 and size.is_finite()and size.x>0 and size.y>0 and is_finite(travel_duration)and travel_duration>0 and dwell_duration==0 and is_finite(initial_phase)and initial_phase>=0 and initial_phase<1
func period() -> float:return travel_duration
func at_time(clock: float) -> Vector2:
 var a: float=PI+TAU*fposmod(clock/period()+initial_phase,1.0);return center+Vector2(cos(a)*radii.x,sin(a)*radii.y)
func envelope() -> Rect2:return Rect2(center-radii-size*.5,radii*2+size)
