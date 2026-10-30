extends Node
const WAVE_CELLS=preload("plains_cells-d3785510bb80.gd")
## One native overlap-triggered wave. EnemyActor owns health, attack and shots.
var owner_runner
var data: Dictionary
var host: Node2D
var player: PlayerController
var scope
var cells
var fired:=false
var events: Array=[]
var sensor: Area2D
var actors: Array=[]
func setup(value: Dictionary, world: Node2D, controller: PlayerController, context, native_cells, runner) -> void:
	data=value;host=world;player=controller;scope=context;cells=native_cells;owner_runner=runner
	process_physics_priority=800
	var r: Array=data.review029_wave.rect
	sensor=Area2D.new();sensor.collision_layer=0;sensor.collision_mask=player.motor.collision_layer
	var shape:=RectangleShape2D.new();shape.size=Vector2(r[2],r[3]);var collision:=CollisionShape2D.new();collision.shape=shape
	sensor.position=Vector2(r[0]+r[2]/2.,r[1]+r[3]/2.);sensor.add_child(collision);host.add_child(sensor)
	sensor.body_entered.connect(func(body):
		if body==player.motor and not fired:call_deferred("spawn_wave"))
func spawn_wave() -> void:
	if fired:return
	fired=true;events.append({"frame":scope.frame,"type":"player_enter_spawn_wave","count":data.enemies.size()})
	var wave_cells=WAVE_CELLS.new();wave_cells.owner_runner=owner_runner;host.add_child(wave_cells)
	wave_cells.setup({"enemies":data.enemies,"latches":[]},host,player,scope)
	actors=wave_cells.enemies;cells.enemies.append_array(actors)
	# Native damage/defeat signal handlers remain attached to wave_cells.
	wave_cells.events=cells.events;wave_cells.player_damage=cells.player_damage
func _physics_process(delta: float) -> void:
	for actor: EnemyActor in actors:
		if actor.health.terminal or actor._damage_stun_remaining>0 or actor._stagger_remaining>0:continue
		var offset: float=host.to_global(Vector2(float(data.review029_wave.targetX),0)).x-actor.motor.global_position.x
		if absf(offset)>1:actor.motor.move_attack(Vector2(signf(offset)*minf(absf(offset),float(data.review029_wave.speed)*delta),0),true,delta)
func snapshot() -> Dictionary:
	return {"triggered":fired,"initially_present":false,"events":events.duplicate(true),"actors":actors.map(func(a):return {"x":a.motor.position.x,"y":a.motor.position.y,"hp":a.health.current,"dead":a.health.terminal})}
