class_name ThornForestPresentation
extends Node2D
@export var encounter: ThornForestEncounter
# Reuse the admitted root/branch identities; no extra species or generated art.
const GUARDIAN_BODY := preload("res://assets/forest_bible_v2/native/fine_32/guardian.png")
const QUEEN_BODY := preload("res://assets/forest_bible_v2/native/fine_32/queen.png")
# Source foot (36,94) maps to the existing ground foot y=48 at 1x.
const GUARDIAN_BOUNDS := Rect2(-36,-46,72,96)
# Source foot y=66 maps to y=48 at an integer uniform 2x; the painted
# queen heart y=37 then maps to -10 beside the existing UI heart y=-9.
const QUEEN_BOUNDS := Rect2(-72,-84,144,136)
var age := 0.0
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
func _process(delta: float) -> void:
	age += delta
	motion.sample(encounter,delta)
	queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var queen := (encounter.definition as ThornForestDefinition).queen
	var body := QUEEN_BODY if queen else GUARDIAN_BODY
	var bounds := QUEEN_BOUNDS if queen else GUARDIAN_BOUNDS
	var body_tint := hit_template.tint(Color.WHITE.lerp(Color("818a75"),motion.death))
	motion.draw_body(self,body,bounds,&"queen" if queen else &"guardian",body_tint)
	# Dim the authored heart in its own source domain. The unique bright cue
	# below stays on the real advertised weak_side, including a side change.
	# This mirrors the existing formal Guardian's same-source heart dimming;
	# no source pixels, actor geometry or material are edited/replaced.
	var native_heart := Rect2(32,34,9,10) if queen else Rect2(28,34,18,16)
	var uniform_scale := 2.0 if queen else 1.0
	draw_texture_rect_region(body,Rect2(bounds.position+native_heart.position*uniform_scale,native_heart.size*uniform_scale),native_heart,Color(.20,.30,.22)*body_tint)
	var heart_view := encounter.presentation_heart()
	var heart: Vector2 = heart_view.offset
	draw_circle(heart,11,Color(.16,.12,.17))
	draw_arc(heart,13,0,TAU,32,Color(1,.78,.34) if heart_view.visible else Color(.5,.4,.25),2)
	if heart_view.visible: draw_circle(heart,7+sin(age*5),Color(1,.82,.42))
	else:
		for side: int in [-1,1]: draw_line(heart+Vector2(side*9,-10),heart+Vector2(-side*9,10),Color(.4,.53,.26),4)
	var mark := encounter.presentation_ground_mark()
	if not mark.is_empty():
		var goal := to_local(mark.position)
		var width: float = mark.width
		draw_line(goal-Vector2(width*.5,1),goal+Vector2(width*.5,-1),Color(1,.65,.35),4)
		draw_arc(goal,width*.5,PI,TAU,24,Color(1,.65,.35,.8),2)
func _exit_tree() -> void:
	motion.dispose(encounter)

func synchronize_presentation() -> void:
	motion.synchronize(encounter)
