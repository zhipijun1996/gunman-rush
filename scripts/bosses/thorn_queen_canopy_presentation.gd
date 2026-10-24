class_name ThornQueenCanopyPresentation
extends Node2D
@export var encounter: ThornQueenCanopyEncounter
var hit_template: EnemyHitTemplate
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	set_process(true)
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if encounter==null or encounter.definition==null: return
	var color := Color("dbbfa4")
	var half := encounter.definition.collision_size*.5
	if not ForestBibleActors.draw_boss_body(self, encounter):
		draw_colored_polygon(PackedVector2Array([Vector2(-half.x,5),Vector2(-18,-15),Vector2(-12,-half.y),Vector2(0,-19),Vector2(12,-half.y),Vector2(18,-15),Vector2(half.x,5),Vector2(10,half.y),Vector2(-10,half.y)]),hit_template.tint(Color("704c64")))
		draw_circle(Vector2.ZERO,9,color)
		for index: int in 3: draw_line(Vector2(-14+14*index,-18),Vector2(-22+22*index,-36),color,3,true)
	if not encounter.active: return
	# Living knots retain their original collisions/health; expose the remaining
	# cut decision at gameplay scale rather than relying on two-pixel dots.
	for knot: ThornQueenWeaveKnot in encounter.knots:
		if not is_instance_valid(knot) or knot.health.terminal: continue
		var label_at := to_local(knot.global_position)+Vector2(-13,-23)
		draw_rect(Rect2(label_at+Vector2(-3,-15),Vector2(34,20)),Color("282331"))
		draw_string(ThemeDB.fallback_font,label_at,"%s/2"%int(knot.health.current),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff1cd"))
	if encounter.motion_mode=="migration_preview":
		var path := encounter.motion_path()
		for index: int in path.size()-1:
			var first := to_local(path[index]);var last := to_local(path[index+1])
			draw_line(first,last,Color("e7c38e"),2,true)
			var direction := (last-first).normalized()
			draw_line(last,last-direction.rotated(.5)*12,Color("e7c38e"),2,true)
			draw_line(last,last-direction.rotated(-.5)*12,Color("e7c38e"),2,true)
