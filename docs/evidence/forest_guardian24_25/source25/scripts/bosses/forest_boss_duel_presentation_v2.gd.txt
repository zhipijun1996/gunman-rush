extends Node2D
@export var encounter: ThornForestEncounter
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var color := Color("d5d273") if encounter.core_open else Color("365347")
	draw_rect(Rect2(-36,-48,72,96),Color("3b4838"))
	draw_circle(Vector2(0,-8),19,color)
	draw_line(Vector2(-28,-35),Vector2(-62,-60),Color("7c6d43"),9)
	draw_line(Vector2(28,-35),Vector2(62,-60),Color("7c6d43"),9)
	if encounter.has_ground_mark and encounter.mode == &"pursuit_warning":
		var mark := to_local(encounter.attack_goal)
		draw_line(mark-Vector2(30,0),mark+Vector2(30,0),Color("ffbf6b"),5)
		draw_line(mark-Vector2(0,60),mark,Color("ffbf6b"),3)

	if encounter is RootbellGuardianV2 and encounter.mode == &"bell_warning":
		var duel := encounter as RootbellGuardianV2
		if is_instance_valid(duel._bell):
			var config := duel.definition as BossDuelDefinition
			var start := duel._bell.global_position
			var duration := config.bell_outbound_seconds
			var initial := (duel.attack_goal-start)/duration-Vector2(0,config.bell_gravity*duration*.5)
			draw_arc(to_local(start),config.bell_radius+8,0,TAU,32,Color("ffc276"),3)
			for index: int in 12:
				var time := duration*float(index)/12.0
				var point := start+initial*time+Vector2(0,.5*config.bell_gravity*time*time)
				draw_circle(to_local(point),3,Color("ffc276"))
