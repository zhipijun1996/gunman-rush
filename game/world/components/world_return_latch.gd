class_name WorldReturnLatch
extends WorldRoomInteraction
## Reward-side lever: collision follows only its own committed permanent fact.
@export var return_steps: Array[Rect2] = []
@export var closed_panels: Array[Rect2] = []
@export var metal_hatch := false
var closed_terrain: UnderworldTerrain
var opened_bodies: Array[StaticBody2D] = []
var closed_bodies: Array[StaticBody2D] = []
var hatch_opening := 0.0
var hatch_target := 0.0
var hatch_initialized := false

func bind(value: FixedWorldState) -> void:
	super.bind(value)
	for rect: Rect2 in return_steps: opened_bodies.append(_body(rect,true))
	for rect: Rect2 in closed_panels: closed_bodies.append(_body(rect,false))
	if not metal_hatch:
		closed_terrain=UnderworldTerrain.build(closed_panels);add_child(closed_terrain)
	_refresh(0)

func _body(rect: Rect2,one_way: bool) -> StaticBody2D:
	var body:=StaticBody2D.new()
	body.position=rect.get_center()
	body.collision_mask=0
	var shape:=RectangleShape2D.new();shape.size=rect.size
	var collision:=CollisionShape2D.new();collision.name="CollisionShape2D";collision.shape=shape
	collision.one_way_collision=one_way
	if one_way:body.add_to_group("one_way_platform")
	body.add_child(collision);add_child(body)
	return body

func _refresh(revision: int) -> void:
	super._refresh(revision)
	var opened: bool=state.has(action_id)
	hatch_target=1.0 if opened else 0.0
	if not hatch_initialized:
		hatch_opening=hatch_target;hatch_initialized=true
	for body: StaticBody2D in opened_bodies:body.set_deferred("collision_layer",1 if opened else 0)
	for body: StaticBody2D in closed_bodies:body.set_deferred("collision_layer",0 if opened else 1)
	if closed_terrain!=null:closed_terrain.visible=not opened
	queue_redraw()

func _process(delta: float) -> void:
	if metal_hatch and hatch_opening!=hatch_target:
		hatch_opening=move_toward(hatch_opening,hatch_target,delta*3.5)
		queue_redraw()

func _draw() -> void:
	if state==null:return
	if metal_hatch:
		for rect: Rect2 in closed_panels:
			draw_set_transform(rect.position,hatch_opening*PI*.5)
			UnderworldTerrain.draw_moving(self,Rect2(Vector2.ZERO,rect.size))
		draw_set_transform(Vector2.ZERO)
	if state.has(action_id):
		for rect: Rect2 in return_steps:UnderworldTerrain.draw_one_way(self,rect)
