class_name PlainsRegionComposition
extends Node2D
## Low-contrast local middle distance, deliberately behind gameplay silhouettes.
## No collision, grass standing edge or gameplay authority in this subtree.
const ROCK := preload("res://assets/plains_v8/painted_limestone_material.png")
const WOOD := preload("res://assets/plains_v3/terrain/brass_wood_bridge.png")
var compositions: Array[Dictionary] = []
var manifest: Dictionary
var enabled_identities: Array[String] = ["windmill_plateau", "creek_well", "clock_court", "repair_gallery"]
func configure(recorded: Dictionary) -> void: manifest = recorded
func _ready() -> void:
	z_index = -5
	for area: Dictionary in manifest.areas:
		var identity := str(area.get("identity",""))
		if identity not in enabled_identities: continue
		var origin := Vector2(area.position[0],area.position[1])
		# Existing painted series, placed in a visibly receding local layer.
		# These roots extend behind the actual foreground rock, never make ledges.
		if identity == "clock_court":
			_backdrop(area, "ruin_arch", origin+Vector2(205,165), 360, Color(.62,.71,.67,.42))
		elif identity == "repair_gallery":
			_backdrop(area, "windmill", origin+Vector2(-30,140), 280, Color(.62,.63,.49,.50))
			_backdrop(area, "banner", origin+Vector2(-200,48), 215, Color(.65,.65,.53,.53))
			_backdrop(area, "ivy", origin+Vector2(55,-10), 130, Color(.48,.65,.51,.42))
		elif identity == "creek_well":
			_backdrop(area, "ivy", origin+Vector2(-250,-40), 205, Color(.42,.62,.56,.33))

func _backdrop(area: Dictionary, id: String, foot: Vector2, height: float, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Distant_"+str(area.id)+"_"+id
	sprite.texture = PlainsV3Assets.texture("decor.json",id)
	if id == "windmill" and area.identity == "repair_gallery":
		var cropped := (sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		cropped.region = Rect2(cropped.region.position+Vector2(0,210),Vector2(460,380))
		sprite.texture = cropped
	if id == "ruin_arch":
		var cropped := (sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		cropped.region = cropped.region.grow_individual(-12,0,-12,0)
		sprite.texture = cropped
	var scale_value := height/sprite.texture.get_height()
	sprite.scale = Vector2.ONE*scale_value
	sprite.position = foot-Vector2(0,height*.5)
	sprite.modulate = tint
	sprite.set_meta("composition",{"area_id":area.id,"identity":area.identity,"depth":"distant_local_architecture","asset_source":"assets/plains_v3/decor.png","source_sha256":FileAccess.get_sha256("res://assets/plains_v3/decor.png"),"asset_id":id,"collision":false,"standing_edge":false,"atlas_crop_inset_x":12 if id=="ruin_arch" else 0})
	compositions.append(sprite.get_meta("composition"))
	add_child(sprite)
