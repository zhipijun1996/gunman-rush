extends Node2D
@export var encounter: ThornQueenV2
const QUEEN_BODY := preload("res://assets/forest_bible_v2/native/fine_32/queen.png")
# Same 1x branch/crown body and hover foot as the existing canopy consumer.
# Painted source heart (36,37) maps to (0,-2), inside the unchanged UI heart.
const QUEEN_BOUNDS := Rect2(-36,-39,72,68)
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
func _process(delta: float) -> void:
	motion.sample(encounter,delta)
	queue_redraw()
func _draw() -> void:
	if encounter==null: return
	var body_tint := hit_template.tint(Color.WHITE.lerp(Color("8e7d86"),motion.death))
	motion.draw_body(self,QUEEN_BODY,QUEEN_BOUNDS,&"queen",body_tint)
	# Keep one visible central core; native heart is an unlit source detail.
	var native_heart := Rect2(32,34,9,10)
	draw_texture_rect_region(QUEEN_BODY,Rect2(QUEEN_BOUNDS.position+native_heart.position,native_heart.size),native_heart,Color(.20,.30,.22)*body_tint)
	draw_circle(Vector2.ZERO,7,Color("efc591") if not encounter.health.terminal else Color("8d7b6d"))
	draw_arc(Vector2.ZERO,11,0,TAU,24,Color("fae4b4") if not encounter.health.terminal else Color("837363"),1)


func _exit_tree() -> void:
	motion.dispose(encounter)

func synchronize_presentation() -> void:
	motion.synchronize(encounter)
