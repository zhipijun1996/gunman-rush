class_name ChimeTargetPresentation
extends Node2D
@export var actor: EnemyActor
const SHEET := preload("res://assets/enemies/chime_target/hover.png")
var clock := 0.0
var hit := 0.0
func _ready() -> void:
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.damageable.damaged.connect(func(_context: Dictionary) -> void: hit=.16)
func _process(delta: float) -> void:
	clock += delta; hit=maxf(0,hit-delta);queue_redraw()
func _draw() -> void:
	if actor==null:return
	if actor.health.terminal:
		var age:float=actor.attack_behavior.reform_age if actor.attack_behavior!=null else 0.0
		var fade:=1-clampf(age/.4,0,1)
		for i: int in 6:
			draw_rect(Rect2(Vector2.from_angle(float(i)*TAU/6)*(8+(1-fade)*18),Vector2(2,2)),Color(.88,.8,.48,fade))
		if age>1.5:
			var gather:=clampf((age-1.5)/.5,0,1)
			for i:int in 6:
				var at:=Vector2.from_angle(float(i)*TAU/6+gather*.3)*lerpf(24,4,gather)
				draw_rect(Rect2(at.round(),Vector2(2,2)),Color(.82,.9,.57,gather))
		return
	var frame:=int(clock*8)%4
	var tint:=Color(1.4,1.25,.9) if hit>0 else Color.WHITE
	draw_texture_rect_region(SHEET,Rect2(-32,-34,64,64),Rect2(frame*64,0,64,64),tint)
