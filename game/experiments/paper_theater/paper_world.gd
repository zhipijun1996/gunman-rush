extends Node2D
## B-only regional studies: all gameplay geometry comes from the live room.
const Shapes = preload("res://game/experiments/paper_theater/paper_shapes.gd")
const Actor = preload("res://game/experiments/paper_theater/paper_actor.gd")
var app: FixedWorldApp
const Studies = preload("res://game/experiments/paper_theater/paper_studies.gd")
var profile: Dictionary
var region: String
var moving_paper: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var shapes: RefCounted
var depths: Array[Dictionary] = []
var foreground: Array[Dictionary] = []
var actors: Array[Node2D] = []
var chests: Array[Dictionary] = []
var ply_count := 0
var silhouette_count := 0
var rebuild_count := 0

func _ready() -> void:
	shapes = Shapes.new()
	region=app.room.room_id
	profile=Studies.ROOMS[region]
	match region:
		"F-R01":_forest()
		"G-R02":_city()
		_:_build_sky();_build_landscape()
	_build_terrain()
	_build_props()
	_build_gates()
	_build_actors()
	_light_mask(get_node("ContinuousTerrain"),1)
	_light_mask(get_node("WorldFixedCollage"),1)
	rebuild_count += 1
	ply_count = shapes.sheet_count

func _light_mask(node: Node, mask: int) -> void:
	if node is CanvasItem:node.light_mask = mask
	for child: Node in node.get_children():_light_mask(child,mask)

func layer(id: String, z: int, ratio: float) -> Node2D:
	var node := Node2D.new()
	node.name = id
	node.z_index = z
	add_child(node)
	if not is_equal_approx(ratio,1):depths.append({"node":node,"ratio":ratio})
	return node

func _build_sky() -> void:
	var sky := layer("PaperSky",-100,.03)
	var sky_face: Polygon2D = shapes.polygon(sky,shapes.rect_points(Rect2(-4096,-4096,10000,10000)),Color(profile.paper))
	sky_face.material.set_shader_parameter("strength",.025)
	var sun := Vector2(1000,390)
	shapes.sheet(sky,shapes.ellipse(sun,Vector2(148,144)),Color("d48869"),0,2)
	shapes.polygon(sky,PackedVector2Array([Vector2(820,280),Vector2(1110,215),Vector2(1190,250),Vector2(853,334)]),Color("ece2cb"))
	shapes.polygon(sky,PackedVector2Array([Vector2(800,455),Vector2(1170,365),Vector2(1220,404),Vector2(815,510)]),Color("ece2cb"))
	# Independent paper clouds; no painted landscape or full-screen filter.
	var air := layer("CloudCutouts",-95,.12)
	for spec: Vector3 in [Vector3(400,250,1),Vector3(1460,80,.7),Vector3(1830,510,.8)]:
		var points := PackedVector2Array()
		for i: int in 35:
			var x := -180+i*11.0
			points.append(Vector2(x,10*sin(i*.19)+5*sin(i*.7))*Vector2(spec.z,1)+Vector2(spec.x,spec.y))
		for i: int in range(34,-1,-1):
			var x := -180+i*11.0
			points.append(Vector2(x,26+7*sin(i*.23))*Vector2(spec.z,1)+Vector2(spec.x,spec.y))
		shapes.polygon(air,points,Color("f6efd9"))

func _build_landscape() -> void:
	var palettes := [Color("bbb7a3"),Color("9caba0"),Color("668880")]
	for depth: int in 3:
		var hill := layer("Ridge%d"%depth,-85+depth*8,.16+depth*.17)
		var outline := PackedVector2Array([Vector2(-3000,2200)])
		for i: int in 61:
			var x := -3000+i*130.0
			var y := 680+depth*130+105*sin(x*.0023+depth*1.5)+44*sin(x*.0051+.8*depth)
			y += 38*sin(x*.009+depth)
			outline.append(Vector2(x,y))
		outline.append(Vector2(5000,2200))
		shapes.sheet(hill,outline,palettes[depth],0,3+depth)
	var architecture := layer("DistantBellTheater",-56,.52)
	_arch(architecture,Vector2(1540,990),Vector2(250,440),Color("c3ad85"),.0,PI)
	_arch(architecture,Vector2(1540,990),Vector2(176,348),Color("e0ccb0"),.15,2.95)
	shapes.sheet(architecture,PackedVector2Array([Vector2(1190,980),Vector2(1242,472),Vector2(1284,448),Vector2(1260,986)]),Color("b6a58a"),1,5)
	shapes.sheet(architecture,PackedVector2Array([Vector2(1710,990),Vector2(1748,640),Vector2(1838,596),Vector2(1808,1000)]),Color("b5a080"),1,5)
	# A suspended bell belongs to its arch, including its visible cord.
	shapes.line(architecture,PackedVector2Array([Vector2(1540,588),Vector2(1540,670)]),Color("7f8270"),2)
	shapes.sheet(architecture,PackedVector2Array([Vector2(1517,670),Vector2(1556,670),Vector2(1578,728),Vector2(1501,737)]),Color("b48260"),2,3)
	shapes.polygon(architecture,shapes.ellipse(Vector2(1540,742),Vector2(7,9)),Color("6b7d75"),2)
	# A separate low horizon masks the architecture's foundations in its own depth.
	var apron := PackedVector2Array([Vector2(-3000,2200)])
	for i: int in 65:
		var x := -3000+i*128.0
		apron.append(Vector2(x,940+20*sin(x*.004)))
	apron.append(Vector2(5200,2200))
	shapes.polygon(architecture,apron,Color("829b8a"),3)

func _arch(parent: Node2D, foot: Vector2, size: Vector2, color: Color, start: float, end: float) -> void:
	var p := PackedVector2Array()
	for i: int in 33:
		var a := lerpf(start,end,float(i)/32)
		p.append(foot+Vector2(cos(a)*size.x,-sin(a)*size.y))
	for i: int in range(32,-1,-1):
		var a := lerpf(start,end,float(i)/32)
		p.append(foot+Vector2(cos(a)*(size.x-32),-sin(a)*(size.y-35)))
	shapes.sheet(parent,p,color,0,5)

func _forest() -> void:
	var sky:=layer("ForestPaper",-100,.07)
	shapes.polygon(sky,shapes.rect_points(Rect2(-2000,-2000,5000,5000)),Color(profile.paper))
	# A clipped crescent is a cut paper shape, not a painted forest backdrop.
	var moon: PackedVector2Array=shapes.ellipse(Vector2(630,158),Vector2(112,106),.4)
	for cut: PackedVector2Array in Geometry2D.clip_polygons(moon,shapes.ellipse(Vector2(678,128),Vector2(102,108))):
		shapes.sheet(sky,cut,Color("e8d9af"),0,3)
	for depth: int in 2:
		var grove:=layer("Grove%d"%depth,-85+depth*15,.22+depth*.24)
		var color:=Color("9ca88b") if depth==0 else Color("788b76")
		var positions:=PackedFloat32Array([-340,90,620,1260,1830]) if depth==0 else PackedFloat32Array([-160,380,1110,1790])
		for i: int in positions.size():
			var x: float=positions[i]
			var foot:=Vector2(x,650+depth*25)
			var trunk:=PackedVector2Array([foot+Vector2(-44,0),foot+Vector2(-26,-190),foot+Vector2(-50,-470),foot+Vector2(-13,-690),foot+Vector2(19,-440),foot+Vector2(28,-160),foot+Vector2(58,0)])
			shapes.sheet(grove,trunk,color,0,6)
			# One asymmetric branch carries each crown. No near-platform parallax roots.
			shapes.sheet(grove,PackedVector2Array([foot+Vector2(-17,-310),foot+Vector2(120,-450),foot+Vector2(142,-466),foot+Vector2(28,-300)]),color,0,3)
			for leaf: Vector3 in [Vector3(-90,-595,1),Vector3(85,-510,.8),Vector3(14,-710,.76)]:
				var center:=foot+Vector2(leaf.x*(.8+.17*sin(i*1.8)),leaf.y+37*sin(i*2.2+depth))
				shapes.sheet(grove,shapes.ellipse(center,Vector2(145+14*sin(i*2.7),72+7*cos(i*1.6))*leaf.z,float(i),22),color.lightened(.08),1,4)
		var bed:=PackedVector2Array([Vector2(-1600,1800),Vector2(-1600,600)])
		for i: int in 30:bed.append(Vector2(-1600+i*140,600+15*sin(i*.72+depth)))
		bed.append(Vector2(2600,1800));shapes.polygon(grove,bed,color,2)
	var canopy:=layer("SuspendedCanopy",-45,.7)
	shapes.sheet(canopy,PackedVector2Array([Vector2(-900,-600),Vector2(2000,-600),Vector2(2000,-100),Vector2(910,-10),Vector2(820,32),Vector2(722,-36),Vector2(610,-62),Vector2(430,-14),Vector2(210,-60),Vector2(30,40),Vector2(-220,-80),Vector2(-900,-55)]),Color("60775f"),0,7)

func _city() -> void:
	var wall:=layer("MachineHallBackWall",-100,1)
	shapes.polygon(wall,shapes.rect_points(Rect2(-2000,-2000,5000,5000)),Color(profile.paper))
	for spec: Rect2 in [Rect2(-80,-160,240,690),Rect2(318,-160,76,690),Rect2(780,-160,200,690)]:
		shapes.sheet(wall,shapes.rect_points(spec),Color("728881"),1,5)
	# Glazed openings are background architecture, with no false walkable lip.
	for origin: Vector2 in [Vector2(178,120),Vector2(488,70)]:
		shapes.sheet(wall,PackedVector2Array([origin,origin+Vector2(94,-12),origin+Vector2(94,160),origin+Vector2(0,170)]),Color("d6cfad"),2,6)
		shapes.line(wall,PackedVector2Array([origin+Vector2(42,-3),origin+Vector2(42,160)]),Color("8c9d8e"),3,3)
		shapes.polygon(wall,PackedVector2Array([origin+Vector2(5,166),origin+Vector2(91,156),origin+Vector2(205,370),origin+Vector2(96,375)]),Color("c5c4a4",.22),2,false)
	var mechanism:=layer("MountedClockwork",-55,1)
	var center:=Vector2(642,216)
	shapes.sheet(mechanism,shapes.ellipse(center,Vector2(128,128),.3,40),Color("687d78"),0,5)
	shapes.sheet(mechanism,shapes.ellipse(center,Vector2(110,110),.5,40),Color("b3ae87"),1,4)
	shapes.polygon(mechanism,shapes.ellipse(center,Vector2(91,91),.1,40),Color("8a9a8b"),2)
	for i: int in 12:
		var angle:=TAU*i/12
		shapes.line(mechanism,PackedVector2Array([center+Vector2.from_angle(angle)*98,center+Vector2.from_angle(angle)*106]),Color("506b67"),2,3)
	shapes.line(mechanism,PackedVector2Array([center+Vector2(-10,4),center,center+Vector2(8,-67)]),Color("475f5c"),5,4)
	shapes.line(mechanism,PackedVector2Array([center,center+Vector2(45,28)]),Color("475f5c"),4,4)
	for item: Vector3 in [Vector3(105,335,49),Vector3(790,95,45)]:
		var gear:=Node2D.new();gear.position=Vector2(item.x,item.y);mechanism.add_child(gear)
		var teeth:=PackedVector2Array()
		for i: int in 48:teeth.append(Vector2.from_angle(TAU*i/48)*item.z*(1.0 if i%4 in [1,2] else .86))
		shapes.sheet(gear,teeth,Color("9d9470"),3,4)
		shapes.polygon(gear,shapes.ellipse(Vector2.ZERO,Vector2.ONE*item.z*.56),Color("6a827a"),4)
		shapes.polygon(gear,shapes.ellipse(Vector2.ZERO,Vector2.ONE*6),Color("bdab7e"),5)
		moving_paper.append({"node":gear,"speed":.055 if item.x<400 else -.04})
	shapes.line(mechanism,PackedVector2Array([Vector2(106,384),Vector2(106,428),Vector2(185,428)]),Color("667c76"),9,0)

func _build_gates() -> void:
	var host:=layer("ActualClosedDoors",4,1)
	for door: Dictionary in app.room.doors:
		if door.get("front_door",false) or door.get("npc_guard",false):continue
		var at:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		var r:=Rect2(at-Vector2(16,96),Vector2(32,96)) if door.direction in ["left","right"] else Rect2(at-Vector2(64,16),Vector2(128,32))
		var gate:=Node2D.new();host.add_child(gate)
		shapes.sheet(gate,shapes.rect_points(r),Color(profile.terrain).lightened(.1),0,3)
		shapes.line(gate,PackedVector2Array([r.position,r.end]),Color(profile.lip),2,1)
		shapes.line(gate,PackedVector2Array([Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y)]),Color(profile.lip),2,1)
		gates.append({"node":gate,"id":door.id})

func _build_terrain() -> void:
	var terrain := layer("ContinuousTerrain",-2,1)
	var solids: Array[Rect2] = []
	for i: int in app.room.platforms.size():
		if i not in app.room.one_way_indices:solids.append(app.room.platforms[i])
	solids.append_array(WorldRoomSpace.exterior_fill(app.room.contract.world_geometry,app.room.doors))
	var outlines: Array[PackedVector2Array] = shapes.union_rectangles(solids)
	for row: Dictionary in app.room.terrain_polygons:
		var p := PackedVector2Array()
		for pair: Array in row.points:p.append(FixedWorldProvider.point(pair))
		outlines.append(p)
	silhouette_count = outlines.size()
	for p: PackedVector2Array in outlines:
		shapes.sheet(terrain,p,Color(profile.terrain),0,6)
		# Two nonperiodic pigment strata are clipped to the continuous silhouette.
		# They cannot spill into a gap or introduce a second collision surface.
		for band: int in 2:
			var field := PackedVector2Array([Vector2(-1000,2200)])
			for k: int in 35:
				var x := -1000+k*120.0
				field.append(Vector2(x,float(profile.ground)-250+band*105+17*sin(x*.006+band*3)+9*sin(x*.019)))
			field.append(Vector2(3200,2200))
			for cut: PackedVector2Array in Geometry2D.intersect_polygons(p,field):
				shapes.polygon(terrain,cut,Color(profile.strata[band]),0)
		# The narrow landing lip follows only exposed upward-facing edges.
		for i: int in p.size():
			var a := p[i]
			var b := p[(i+1)%p.size()]
			if b.x-a.x > 8 and absf(a.y-b.y) < .1:
				shapes.polygon(terrain,PackedVector2Array([a,b,b+Vector2(0,5),a+Vector2(0,5)]),Color(profile.lip),1)
		var blocker := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = p
		blocker.occluder = poly
		terrain.add_child(blocker)
	for i: int in app.room.one_way_indices:
		var r: Rect2 = app.room.platforms[i]
		# One-way sheets are explicitly thin; their top is the exact collision top.
		var p := PackedVector2Array([r.position,Vector2(r.end.x,r.position.y)])
		for k: int in range(12,-1,-1):
			var t := float(k)/12
			p.append(Vector2(lerpf(r.position.x,r.end.x,t),r.position.y+12+4*sin(k*1.7+i)))
		shapes.sheet(terrain,p,Color(profile.platform),2,4)
		shapes.line(terrain,PackedVector2Array([r.position,Vector2(r.end.x,r.position.y)]),Color("f3dfad"),1.5,3)
	var hazards := layer("HazardPaper",2,1)
	for strip: Dictionary in app.room.spike_strips:
		var r := FixedWorldProvider.rect(strip.bounds)
		var p := PackedVector2Array([r.position+Vector2(0,r.size.y)])
		var count := maxi(2,int(r.size.x/12))
		for i: int in count:
			var x := r.position.x+r.size.x*i/count
			p.append(Vector2(x,r.end.y-3))
			p.append(Vector2(x+r.size.x/count*.48,r.position.y))
			p.append(Vector2(x+r.size.x/count,r.end.y-3))
		p.append(r.end)
		shapes.sheet(hazards,p,Color("aa4d42"),0,2)
		shapes.line(hazards,PackedVector2Array([Vector2(r.position.x,r.end.y-2),r.end-Vector2(0,2)]),Color("e9ad82"),2,1)

func _build_props() -> void:
	var fixed := layer("WorldFixedCollage",-12,1)
	var near := layer("AttachedForeground",5,1)
	var anchors: Array[Vector3] = []
	if region=="P-R04":
		shapes.sheet(fixed,PackedVector2Array([Vector2(1859,1209),Vector2(1859,1010),Vector2(1885,997),Vector2(1885,1209)]),Color("8d9a7b"),0,3)
		_plant(fixed,Vector2(350,1088),72,Color("7e9874"),false)
		_plant(fixed,Vector2(1870,928),94,Color("7f9676"),false)
		anchors=[Vector3(394,928,34),Vector3(1838,928,43),Vector3(1170,1216,31)]
	elif region=="F-R01":
		for foot: Vector2 in [Vector2(88,576),Vector2(1000,576)]:
			shapes.sheet(fixed,PackedVector2Array([foot+Vector2(-30,0),foot+Vector2(-12,-75),foot+Vector2(-20,-280),foot+Vector2(3,-370),foot+Vector2(18,-230),foot+Vector2(12,-70),foot+Vector2(39,0)]),Color("586653"),0,5)
			_plant(fixed,foot+Vector2(20,0),100,Color("748365"),false)
		anchors=[Vector3(470,160,28),Vector3(120,576,39),Vector3(990,576,46)]
	else:
		anchors=[Vector3(184,448,29),Vector3(742,448,33)]
	for spec: Vector3 in anchors:
		var group:=Node2D.new();near.add_child(group)
		var foot:=Vector2(spec.x,spec.y)
		if region=="G-R02":
			shapes.sheet(group,PackedVector2Array([foot+Vector2(-7,0),foot+Vector2(-4,-spec.z),foot+Vector2(4,-spec.z-3),foot+Vector2(7,-8),foot+Vector2(16,-2)]),Color("806e55"),0,2)
		else:_plant(group,foot,spec.z,Color(profile.plant),true)
		foreground.append({"node":group,"anchor":foot,"height":spec.z})
	# Chest proxies follow their live committed state; no decorative fake pickups.
	for host: WorldRoomInteraction in app.room.interaction_hosts:
		if host.visual != "chest":continue
		var proxy := Node2D.new()
		proxy.position = host.position+Vector2(0,18)
		proxy.z_index = 1
		add_child(proxy)
		shapes.sheet(proxy,PackedVector2Array([Vector2(-16,0),Vector2(-16,-21),Vector2(14,-21),Vector2(18,-3),Vector2(15,0)]),Color("b7824c"),0,2)
		shapes.line(proxy,PackedVector2Array([Vector2(-15,-12),Vector2(15,-12)]),Color("f2d8a3"),2,1)
		var lock: Polygon2D = shapes.polygon(proxy,shapes.rect_points(Rect2(-2,-14,5,7)),Color("345b58"),2)
		var lid := Node2D.new()
		lid.position = Vector2(-16,-21)
		proxy.add_child(lid)
		shapes.sheet(lid,PackedVector2Array([Vector2.ZERO,Vector2(30,0),Vector2(31,5),Vector2(0,5)]),Color("c69c65"),3,1)
		chests.append({"lid":lid,"lock":lock,"action":host.action_id})

func _plant(parent: Node2D, root: Vector2, height: float, color: Color, near: bool) -> void:
	var stem := PackedVector2Array([root+Vector2(-3,2),root+Vector2(2,-height),root+Vector2(5,-height*.72),root+Vector2(3,2)])
	shapes.sheet(parent,stem,color,0,1.5 if near else 2)
	for i: int in 5:
		var y := -height*(.24+i*.15)
		var side := -1.0 if i%2==0 else 1.0
		var a := root+Vector2(2,y)
		var length := height*(.37-i*.045)
		var p := PackedVector2Array([a,a+Vector2(side*length,-height*.25),a+Vector2(side*(length+5),-height*.11),a+Vector2(side*length*.55,1)])
		shapes.sheet(parent,p,color.lightened(.035*i),1,1)

func _build_actors() -> void:
	var hero := Actor.new()
	hero.app = app
	hero.shapes = shapes
	hero.motor = app.player
	hero.z_index = 3
	add_child(hero)
	actors.append(hero)
	for enemy: EnemyActor in app.room.enemies.values():
		var proxy := Actor.new()
		proxy.app = app
		proxy.shapes = shapes
		proxy.motor = enemy.motor
		proxy.enemy = enemy
		proxy.z_index = 2
		add_child(proxy)
		actors.append(proxy)

func _process(delta: float) -> void:
	if not is_instance_valid(app.player):return
	var camera_at := app.camera.get_screen_center_position()
	for row: Dictionary in moving_paper:row.node.rotation += delta*float(row.speed)
	for row: Dictionary in gates:row.node.visible=not bool(app.room.door_open.get(row.id,false))
	for chest: Dictionary in chests:
		var opened: bool = app.state.value.receipts.has(chest.action)
		chest.lid.rotation = -.8 if opened else 0.0
		chest.lock.visible = not opened
	for row: Dictionary in depths:
		row.node.position = (camera_at-(profile.reference as Vector2))*(1-float(row.ratio))
	for row: Dictionary in foreground:
		var distance: Vector2 = app.player.position-row.anchor
		var alpha := .3 if absf(distance.x)<34 and absf(distance.y)<float(row.height)+28 else 1.0
		row.node.modulate.a = move_toward(row.node.modulate.a,alpha,delta*5)
