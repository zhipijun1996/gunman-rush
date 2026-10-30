extends Node
const PAIR=preload("pair_latch_v3-33307e6c887e.gd")
var pairs: Array=[]

static func ordinary_case(source: Dictionary) -> Dictionary:
	var data:=source.duplicate(true)
	data.latches=[]
	for spec: Dictionary in source.get("latches",[]):
		if not spec.has("paired_gate"):data.latches.append(spec)
	return data

func setup(data: Dictionary, host: Node2D, player: PlayerController, scope, cells) -> void:
	pairs=[]
	for spec: Dictionary in data.get("latches",[]):
		if not spec.has("paired_gate"):continue
		var first:=Rect2(spec.gate[0],spec.gate[1],spec.gate[2],spec.gate[3])
		var second:=Rect2(spec.paired_gate[0],spec.paired_gate[1],spec.paired_gate[2],spec.paired_gate[3])
		if not first.has_area() or not second.has_area() or spec.get("initial_open","A") not in ["A","B"]:
			cells.owner_runner.setup_error="invalid_paired_gate_definition";return
		var latch=PAIR.new();latch.link_id=str(spec.id);latch.formal_presentation=true
		host.add_child(latch)
		latch.setup_pair(player,scope.lifetime,Vector2(spec.bell[0],spec.bell[1]),first,second,str(spec.get("initial_open","A")),scope)
		if spec.has("return_access"):latch.add_access_bell(Vector2(spec.return_access[0],spec.return_access[1]),false,true)
		latch.opened.connect(cells._bell_open.bind(latch,str(spec.id)))
		cells.latches.append(latch);pairs.append(latch)

func snapshot() -> Array:
	var state: Array=[]
	for latch in pairs:state.append(latch.snapshot_pair())
	return state
