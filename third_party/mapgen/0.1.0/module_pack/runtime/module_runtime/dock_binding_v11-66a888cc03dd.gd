extends RefCounted
const CELL=preload("dock_latch_v11-50dddd551653.gd")
static func masked(case:Dictionary)->Dictionary:
	var value:=case.duplicate(true);value.latches=[]
	for spec:Dictionary in case.get("latches",[]):
		if not spec.has("carrier_dock"):value.latches.append(spec)
	return value
static func install(owner,case:Dictionary)->void:
	for spec:Dictionary in case.get("latches",[]):
		if not spec.has("carrier_dock"):continue
		var latch:=CELL.new();latch.link_id=str(spec.id);latch.open_seconds=float(spec.open_seconds);latch.formal_presentation=true
		var z:Array=spec.carrier_dock.rect;latch.sensor_rect=Rect2(z[0],z[1],z[2],z[3]);latch.carrier_id=str(spec.carrier_dock.platform_id);latch.recorder=owner.cells
		owner.world.add_child(latch)
		var b:Array=spec.bell;var g:Array=spec.gate
		latch.setup(owner.controller,owner.context.lifetime,Vector2(b[0],b[1]),Rect2(g[0],g[1],g[2],g[3]));latch.configure_dock()
		latch.opened.connect(owner.cells._bell_open.bind(latch,str(spec.id)));owner.cells.latches.append(latch)
