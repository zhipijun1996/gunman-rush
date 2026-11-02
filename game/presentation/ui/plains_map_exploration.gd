class_name PlainsMapExploration
extends RefCounted
const CELL := 280.0
const REVEAL_RADIUS := 420.0
static func key(point: Vector2) -> String:
	return "%s:%s" % [floori(point.x/CELL),floori(point.y/CELL)]
static func revealed(state: PlainsRegionState, point: Vector2) -> bool:
	return state.explored.has(key(point))
static func reveal(state: PlainsRegionState, point: Vector2) -> void:
	if not point.is_finite(): return
	for y: int in range(floori((point.y-REVEAL_RADIUS)/CELL),floori((point.y+REVEAL_RADIUS)/CELL)+1):
		for x: int in range(floori((point.x-REVEAL_RADIUS)/CELL),floori((point.x+REVEAL_RADIUS)/CELL)+1):
			var center:=Vector2((x+0.5)*CELL,(y+0.5)*CELL)
			if center.distance_to(point)<=REVEAL_RADIUS+CELL*0.5:
				state.explored["%s:%s" % [x,y]]=true
