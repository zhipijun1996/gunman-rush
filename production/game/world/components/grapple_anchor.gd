class_name GrappleAnchor
extends Area2D
## Clockwork spring (bounce) and closed cradle (hang) share function silhouettes across regions.
@export var hang_enabled := false
@export_enum("clockwork", "rootbound") var material_family := "clockwork"
var clock := 0.0
var struck := 0.0
var artwork: Sprite2D
func _ready() -> void:
 collision_layer=8;collision_mask=0
 add_to_group(&"grapple_target")
 var collision:=CollisionShape2D.new()
 var circle:=CircleShape2D.new();circle.radius=12;collision.shape=circle;add_child(collision)
 artwork=Sprite2D.new();artwork.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var kind:="hang" if hang_enabled else "bounce"
 artwork.texture=load("res://assets/world_traversal/native/"+material_family+"_"+kind+".png")
 artwork.offset=Vector2(1,3) if hang_enabled else Vector2(1,-7)
 add_child(artwork)
func hook_feedback() -> void:
 struck=1.0
func _process(delta: float) -> void:
 clock+=delta;struck=maxf(0,struck-delta*3)
 if artwork!=null:
  artwork.rotation=sin(clock*1.7)*.025+sin(struck*TAU*2)*struck*.08
  artwork.modulate=Color.WHITE.lerp(Color(1.25,1.2,1.05),struck*.5)
 queue_redraw()
func _draw() -> void:
 # Small material-bound flecks, never a second neon target circle.
 if struck<=0:return
 for i:int in 5:
  var direction:=Vector2.from_angle(float(i)*TAU/5)
  draw_rect(Rect2((direction*(12+(1-struck)*13)).round(),Vector2(2,2)),Color(1,.83,.45,struck))
