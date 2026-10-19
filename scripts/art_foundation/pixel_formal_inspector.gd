class_name PixelFormalInspector
extends CanvasLayer
## Explicit positional art inspection, never a route completion/normal entry.
var app: DemoApp
var points: Array[Dictionary] = []
var current := -1
var caption: Label
var _wait := 0
var second_map := false

func _ready() -> void:
	layer = 25
	var row := HBoxContainer.new()
	row.position = Vector2(360,8)
	add_child(row)
	var next := Button.new()
	next.text = "ART INSPECT / NEXT"
	next.pressed.connect(advance)
	row.add_child(next)
	caption = Label.new()
	caption.text = "POSITIONED VISUAL FIXTURE / NOT TRAVERSAL"
	caption.add_theme_font_size_override("font_size",12)
	row.add_child(caption)
	var boss_button := Button.new()
	boss_button.text = "BOSS / POSITIONED"
	boss_button.position = Vector2(360,44)
	boss_button.pressed.connect(func() -> void:
		for i: int in points.size():
			if points[i].name=="boss":current=i-1;advance();return)
	add_child(boss_button)
	var enemy_button := Button.new()
	enemy_button.text = "ENEMY / POSITIONED"
	enemy_button.position = Vector2(545,44)
	enemy_button.pressed.connect(func() -> void:
		for step: int in points.size():
			var i := (current+step+1)%points.size()
			if str(points[i].name).begins_with("enemy/"):current=i-1;advance();return)
	add_child(enemy_button)
	PixelTerrainGpuProbe.run(self)

func _process(_delta: float) -> void:
	if not is_instance_valid(app.stage) or not app.stage is PlainsRegionStage: return
	if not (app.stage as PlainsRegionStage).assembly_ok: return
	if _wait<12: _wait+=1;return
	if points.is_empty():
		if second_map and app.director.stage_index!=2:
			app.director.stage_index = 2
			app._load_stage()
			_wait = 0
			return
		_collect()
		advance()

func _collect() -> void:
	var stage := app.stage as PlainsRegionStage
	points.append({"name":"spawn","position":stage.spawn})
	for area: Dictionary in stage.generated.manifest.areas:
		if str(area.role) in ["junction","merchant","challenge","creek"]:
			points.append({"name":str(area.role)+"/"+str(area.id),"position":Vector2(area.position[0],area.position[1])-Vector2(0,18)})
	for enemy: EnemyMotor in stage.enemies:
		points.append({"name":"enemy/"+str((enemy.get_node("Actor") as EnemyActor).definition.behavior_id),"position":enemy.position-Vector2(100,0)})
	points.append({"name":"boss","position":Vector2(stage.boss_arena.position.x+150,stage.boss_arena.end.y-18)})

func advance() -> void:
	if points.is_empty():return
	if not is_instance_valid(app.controller) or not is_instance_valid(app.player) or not is_instance_valid(app.stage):
		caption.text = "RUN ENDED / RELOAD FOR POSITIONED ART INSPECTION"
		return
	current = (current+1)%points.size()
	app.controller.return_to_segment(points[current].position)
	caption.text = "POSITIONED / MAP%d %s %d/%d" % [app.director.stage_index,points[current].name,current+1,points.size()]
	print("PIXEL_INSPECT ",JSON.stringify({"fixture":true,"point":points[current].name,"map":app.director.stage_index,"index":current,"parallax":(app.get_node("PixelPlainsParallax") as PixelPlainsParallax).measured_nodes()}))
