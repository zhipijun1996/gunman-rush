extends RefCounted
## FINE-SPACE-05: shallow visual planting into the fine grass/soil transition.
## Original opaque source feet, physics surfaces and service anchors stay intact.
const STRUCTURE_INSET_WU := 7.0
const FLORA_INSET_WU := 3.0

static func depth(kind: String) -> float:
	return FLORA_INSET_WU if kind in ["small_flora","flowers","grass"] else STRUCTURE_INSET_WU

static func origin(foot: Vector2,source_foot: Vector2,scale_value: float,inset: float) -> Vector2:
	return (foot+Vector2(0,inset)-source_foot*scale_value).round()
