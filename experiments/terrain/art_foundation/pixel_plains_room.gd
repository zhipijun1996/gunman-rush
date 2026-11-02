class_name PixelPlainsRoom
extends WindchimeLab
## Reuses corrected sample lifecycle and real mechanics, never the retired art.
const STONE := preload("res://assets/pixel_plains/stone_blob47.svg")
var hud: Control
var effects_active:=true
var light_active:=true

func _ready() -> void:
	seed_text = "pixel-dawn-01"
	super._ready()
	camera.zoom = Vector2(.5,.5)
	camera.position = Vector2(640,360)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _make_layout() -> Dictionary:return PixelPlainsLayout.build()
func _make_backdrop() -> WindchimeBackdrop:return PixelPlainsBackdrop.new()
func _make_actor_visual() -> WindchimeActorVisual:return PixelPlainsActor.new()
func _make_enemy_visual() -> WindchimeEnemyVisual:return PixelPlainsEnemy.new()
func _make_projectile_visual() -> WindchimeProjectileVisual:return PixelPlainsProjectile.new()

func _install_world() -> void:
	terrain = Blob47Terrain.build(layout.cells,seed_text,STONE,PixelPlainsLayout.FAMILY)
	# Quiet interior weighting. All three real variants exist and remain usable.
	for cell: Vector2i in layout.cells:
		var h := posmod((seed_text+":stone:"+str(cell)).hash(),8)
		terrain.set_cell(cell,0,Blob47Rules.atlas_coords(Blob47Rules.mask_at(layout.cells,cell),0 if h<6 else h-5))
	_world.add_child(terrain)
	Blob47Terrain.add_collision(_world,layout.cells)
	for rect: Rect2 in layout.one_way:
		var platform := PixelPlainsPlatform.new()
		platform.position=rect.position
		platform.bounds=Rect2(0,0,rect.size.x,10)
		platform.one_way=true
		_world.add_child(platform)
	for item: Dictionary in layout.moving:
		var platform := PixelPlainsPlatform.new()
		platform.position=item.rect.position
		platform.bounds=Rect2(Vector2.ZERO,item.rect.size)
		platform.travel=item.travel
		platform.period=item.period
		_world.add_child(platform)
	decoration=PixelPlainsDecoration.new()
	var keepouts: Array[Rect2]=[]
	keepouts.assign(layout.keepouts)
	decoration.configure(layout.cells,keepouts,seed_text)
	_world.add_child(decoration)
	scenery=PixelPlainsScenery.new()
	_world.add_child(scenery)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer=15
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var status := PixelPlainsHUD.new()
	status.room=self
	layer.add_child(status)
	_catalog=Panel.new()
	_catalog.position=Vector2(74,61)
	_catalog.size=Vector2(492,242)
	var skin:=StyleBoxFlat.new()
	skin.bg_color=Color("111e2b")
	skin.border_color=Color("6e9180")
	skin.set_border_width_all(1)
	_catalog.add_theme_stylebox_override("panel",skin)
	layer.add_child(_catalog)
	_catalog.hide()
	for i: int in Blob47Rules.catalog_masks().size():
		var mask: int=Blob47Rules.catalog_masks()[i]
		var at:=Blob47Rules.atlas_coords(mask)
		var t:=AtlasTexture.new()
		t.atlas=STONE
		t.region=Rect2(Vector2(at*Blob47Rules.PITCH+Vector2i.ONE*Blob47Rules.GUTTER),Vector2.ONE*Blob47Rules.SOURCE_SIZE)
		t.filter_clip=true
		var icon:=TextureRect.new()
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.texture=t
		icon.position=Vector2(13+i%12*39,18+i/12*52)
		icon.size=Vector2(32,32)
		_catalog.add_child(icon)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and (player.position.y>800 or player.position.x< -50 or player.position.x>1330):restart()

func set_effects(value: bool) -> void:
	effects_active=value
	(decoration as PixelPlainsDecoration).effects_enabled=value
	(scenery as PixelPlainsScenery).effects_enabled=value
	(backdrop as PixelPlainsBackdrop).effects_enabled=value
	decoration.queue_redraw()

func set_light(value: bool) -> void:
	light_active=value
	(scenery as PixelPlainsScenery).light_enabled=value
	(backdrop as PixelPlainsBackdrop).light_enabled=value

func restart() -> void:
	super.restart()
	set_effects(effects_active)
	set_light(light_active)
