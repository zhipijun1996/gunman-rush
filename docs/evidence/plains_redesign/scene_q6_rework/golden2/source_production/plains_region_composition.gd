class_name PlainsRegionComposition
extends Node2D
## Receding architecture and rock shoulders. Never collision or standing edges.
var compositions: Array[Dictionary] = []
var manifest: Dictionary
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var enabled_identities: Array[String] = ["windmill_plateau", "creek_well", "clock_court", "repair_gallery"]
func configure(recorded: Dictionary, slabs: Array[Rect2] = [], blocked: Array[Rect2] = []) -> void:
	manifest = recorded
	supports = slabs.duplicate()
	protected_regions = blocked.duplicate()
func _ready() -> void:
	z_index = -5
	var primary := primary_court(manifest)
	if not primary.is_empty() and "clock_court" in enabled_identities:
		var origin := Vector2(primary.position[0],primary.position[1])
		# Left shoulder continues below the visible ascent. Its root is NOT
		# claimed to stand on the one-way bridge or to have physical collision.
		_piece(primary,"stones",origin+Vector2(-355,480),650,Color(.68,.76,.74,.68),"court_left_shoulder","distant_landform_continues_below_ascent")
		_piece(primary,"stones",origin+Vector2(440,100),390,Color(.70,.77,.73,.66),"court_right_shoulder","behind_actual_east_bank")
		_piece(primary,"ruin_arch",origin+Vector2(110,125),390,Color(.79,.83,.74,.70),"court_primary_arch","single_distant_court_focus")
	for area: Dictionary in manifest.areas:
		if str(area.get("identity","")) != "repair_gallery" or "repair_gallery" not in enabled_identities: continue
		var origin := Vector2(area.position[0],area.position[1])
		_piece(area,"windmill",origin+Vector2(-30,140),280,Color(.62,.63,.49,.50),"repair_cottage","existing_open_forecourt")
		_piece(area,"banner",origin+Vector2(-200,48),215,Color(.65,.65,.53,.53),"repair_banner","existing_open_forecourt")
		_piece(area,"ivy",origin+Vector2(55,-10),130,Color(.48,.65,.51,.42),"repair_ivy","attached_to_distant_cottage")
	if "creek_well" in enabled_identities: _creek_reveal()

static func primary_court(recorded: Dictionary) -> Dictionary:
	# The first court offering a high challenge after a meadow ascent. This
	# follows real semantic connections; it consumes no random stream.
	for area: Dictionary in recorded.areas:
		if area.get("identity","") != "clock_court": continue
		for edge: Dictionary in recorded.connections:
			if str(edge.a)==str(area.id) and str(edge.b)=="deep_high": return area
	return {}

func _creek_reveal() -> void:
	var discovery: Dictionary = manifest.get("creek_discovery",{})
	if discovery.is_empty(): return
	var module_id := str(discovery.get("module",""))
	for edge: Dictionary in manifest.connections:
		if str(edge.get("recipe","")) != "controlled_ferry": continue
		if edge.get("modules",[]).size()!=1: continue
		var node: Dictionary = manifest.nodes[int(edge.modules[0])]
		if str(node.module_id)!="plains_bell_ferry_control" or str(node.id)!=module_id: continue
		var area: Dictionary = {}
		for candidate: Dictionary in manifest.areas:
			if str(candidate.id)==str(edge.a): area=candidate;break
		if area.is_empty(): continue
		var origin := Vector2(node.offset[0],node.offset[1])
		# These stand in a receding plane behind the two REAL dock banks.
		# No artificial cross-gap bottom, grass shelf or island support pillar.
		_piece(area,"stones",origin+Vector2(90,315),365,Color(.58,.73,.73,.76),"creek_entry_shoulder","behind_actual_left_dock",str(edge.id))
		_piece(area,"stones",origin+Vector2(920,315),435,Color(.61,.75,.74,.78),"creek_exit_shoulder","behind_receiving_bank_return_approach",str(edge.id))
		return

func _piece(area: Dictionary, id: String, foot: Vector2, height: float, tint: Color, role: String, root_kind: String, connection: String = "") -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Distant_"+str(area.id)+"_"+role
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
	var bounds := Rect2(sprite.position-sprite.texture.get_size()*sprite.scale*.5,sprite.texture.get_size()*sprite.scale)
	var metadata := {"area_id":area.id,"identity":area.identity,"role":role,"depth":"distant_local_architecture","asset_source":"assets/plains_v3/decor.png","source_sha256":FileAccess.get_sha256("res://assets/plains_v3/decor.png"),"asset_id":id,"collision":false,"standing_edge":false,"atlas_crop_inset_x":12 if id=="ruin_arch" else 0,"root_kind":root_kind,"root_world":[foot.x,foot.y],"display_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"connection_id":connection,"area_origin":area.position.duplicate(),"review":"pixel_aesthetics_unverified"}
	sprite.set_meta("composition",metadata)
	compositions.append(metadata)
	add_child(sprite)
