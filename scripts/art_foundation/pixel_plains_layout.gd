class_name PixelPlainsLayout
extends RefCounted
## One screen study. Static geometry and safe return precede visual placement.
const CELL: int = Blob47Rules.CELL
const FAMILY: StringName = &"pixel_windstone"

static func build() -> Dictionary:
	var cells: Dictionary = {}
	_fill(cells,Rect2i(0,15,11,8))
	_fill(cells,Rect2i(13,16,12,3))
	_fill(cells,Rect2i(13,19,3,4))
	_fill(cells,Rect2i(22,19,3,4))
	_fill(cells,Rect2i(16,19,1,1))
	_fill(cells,Rect2i(21,19,1,1))
	_fill(cells,Rect2i(27,15,13,8))
	# Upper branch is reachable in two ordinary jumps and drops to the court.
	_fill(cells,Rect2i(6,12,4,1))
	_fill(cells,Rect2i(14,11,4,2))
	var keepouts: Array[Rect2] = [Rect2(44,410,90,80),Rect2(300,380,180,150),Rect2(736,380,180,150),Rect2(1130,400,130,90)]
	return {"ok":true,"version":"pixel-plains-dawn-room-v1","seed":"pixel-dawn-01","cells":cells,
		"spawn":Vector2(80,462),"bounds":Rect2(0,0,1280,720),"hazards":[],"keepouts":keepouts,
		"one_way":[Rect2(576,384,128,10)],"moving":[{"rect":Rect2(704,336,96,16),"travel":Vector2(96,0),"period":4.8}],
		"sockets":[{"kind":&"enemy","position":Vector2(1056,480)},{"kind":&"endpoint","position":Vector2(1216,480)}],
		"route":[Vector2(80,462),Vector2(304,462),Vector2(464,494),Vector2(736,494),Vector2(928,462),Vector2(1216,462)],
		"production_pool":false,"required_abilities":[],"tile_family_ids":[FAMILY],"tile_size":CELL}

static func _fill(cells: Dictionary,rect: Rect2i) -> void:
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x): cells[Vector2i(x,y)] = FAMILY
