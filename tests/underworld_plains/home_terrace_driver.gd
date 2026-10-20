class_name HomeTerraceDriver
extends RefCounted
## Tests only. Real Input events use the native keyboard adapter and Motor;
## neither router axes, actor transforms, resource state nor physics are edited.
var home: HomeScene
var tree: SceneTree
var trace: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var held: Dictionary={}
var ticks:=0
var errors: Array[String]=[]
func _init(scene: HomeScene) -> void:
	home=scene
	tree=scene.get_tree()
func key(code: Key,down: bool) -> void:
	if bool(held.get(code,false))==down:return
	held[code]=down
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=down
	Input.parse_input_event(event)
	events.append({"tick":ticks,"key":OS.get_keycode_string(code),"pressed":down})
func frames(count: int) -> void:
	for index: int in count:
		await tree.physics_frame
		ticks+=1
		trace.append({"tick":ticks,"position":[home.player.position.x,home.player.position.y],"velocity":[home.player.normal_velocity.x,home.player.normal_velocity.y],"floor":home.player.is_on_floor(),"axis":home.controller.router.axis,"nearest":str(home.nearest_id),"reserved":home.reserved_id,"hp":home.controller.actor_resources.health.current,"jumps":home.controller.jump_ability.used_jumps if "used_jumps" in home.controller.jump_ability else -1,"camera":[home.camera.get_screen_center_position().x,home.camera.get_screen_center_position().y]})
func release_all() -> void:
	for code: Key in held.keys():key(code,false)
func walk_to(x: float) -> bool:
	var limit:=0
	while absf(home.player.position.x-x)>4 and limit<1000:
		var right:=home.player.position.x<x
		key(KEY_A,not right)
		key(KEY_D,right)
		await frames(1)
		limit+=1
	key(KEY_D,false)
	key(KEY_A,false)
	await frames(3)
	if absf(home.player.position.x-x)>9:
		errors.append("walk failed to %.1f from %s"%[x,home.player.position])
		return false
	return true
func drop_to_floor() -> bool:
	var attempts:=0
	while home.player.position.y+18<HomeScene.FLOOR_Y-8 and attempts<4:
		key(KEY_S,true)
		await frames(2)
		key(KEY_S,false)
		await frames(40)
		attempts+=1
	await frames(3)
	var ok:=home.player.is_on_floor() and absf(home.player.position.y+18-HomeScene.FLOOR_Y)<4
	if not ok:errors.append("S down-through failed: %s"%home.player.position)
	return ok
func jump_to_tier(y: float) -> bool:
	key(KEY_SPACE,true)
	await frames(36)
	key(KEY_SPACE,false)
	await frames(12)
	var ok:=home.player.is_on_floor() and absf(home.player.position.y+18-y)<4
	if not ok:errors.append("single-jump tier %.1f failed: %s"%[y,home.player.position])
	return ok
func reach(id: StringName) -> bool:
	var foot:=home.slot_world_foot(id)
	if not foot.is_finite():errors.append("unknown slot "+str(id));return false
	if not await drop_to_floor():return false
	if foot.y==HomeScene.FLOOR_Y:return await walk_to(foot.x)
	var approach:=foot.x
	if foot.y<HomeScene.FLOOR_Y-100:
		var upper:=Rect2()
		for p: Dictionary in home.world.specification.platforms:
			var r: Array=p.rect
			if float(r[1])==foot.y and foot.x>=float(r[0]) and foot.x<=float(r[0])+float(r[2]):upper=Rect2(r[0],r[1],r[2],r[3])
		var found:=false
		for p: Dictionary in home.world.specification.platforms:
			var r: Array=p.rect
			if float(r[1])!=HomeScene.FLOOR_Y-96:continue
			var low:=maxf(upper.position.x+18,float(r[0])+18)
			var high:=minf(upper.end.x-18,float(r[0])+float(r[2])-18)
			if low<=high:approach=(low+high)*.5;found=true;break
		if not found:errors.append("no basic single-jump overlap "+str(id));return false
	if not await walk_to(approach):return false
	if not await jump_to_tier(HomeScene.FLOOR_Y-96):return false
	if foot.y<HomeScene.FLOOR_Y-100:
		if not await jump_to_tier(foot.y):return false
	return await walk_to(foot.x)
