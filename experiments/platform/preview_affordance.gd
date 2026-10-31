extends Node
## Task-only preview presentation. Canonical game/menu already IS the full game;
## retain the bootstrap's return affordance when visiting developer laboratories.
var host: CloudPreviewBootstrap

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.banner): return
	var app := host.app
	host.banner.visible = not is_instance_valid(app) or (app.menu.visible_panel.is_empty() and app.director.state == DemoRunDirector.State.HOME and not is_instance_valid(app.home_scene))
