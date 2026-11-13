extends Node
## B-only three-region entrance; formal entry/content remain untouched.
const World = preload("res://game/experiments/paper_theater/paper_world.gd")
const Studies = preload("res://game/experiments/paper_theater/paper_studies.gd")
var app: FixedWorldApp
var paper: Node2D
var mode := "B"
var selected_room := "P-R04"
var ready_for_play := false
var switching := false
var controls: CanvasLayer
var description: Label
var original_art: PlainsRoomArt
var initial_room: FixedWorldRoom

func _ready() -> void:
 var args: Dictionary = {}
 if OS.has_feature("web"):
  var raw: Variant = JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(location.search)))")
  if raw is String:args=JSON.parse_string(raw)
 else:
  for arg: String in OS.get_cmdline_user_args():
   if arg.begins_with("--") and "=" in arg:
    var pair:=arg.trim_prefix("--").split("=",true,1)
    args[pair[0]]=pair[1]
 selected_room=str(args.get("room","P-R04"))
 if not Studies.ROOMS.has(selected_room):selected_room="P-R04"
 mode="0" if str(args.get("paper","B"))=="0" else "B"
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.save_path="user://paper_theater_unused.json"
 app.save_profile="paper_theater_unused"
 app.settings_path="user://paper_theater_settings.json"
 add_child(app)
 _build_controls()
 await open_study(selected_room)

func _build_controls() -> void:
 controls=CanvasLayer.new();controls.layer=50;add_child(controls)
 var panel:=PanelContainer.new();panel.position=Vector2(16,73)
 var style:=StyleBoxFlat.new();style.bg_color=Color("f0e6ce",.94)
 style.content_margin_left=10;style.content_margin_right=10
 style.content_margin_top=8;style.content_margin_bottom=8
 style.border_color=Color("b8b39b");style.set_border_width_all(1)
 panel.add_theme_stylebox_override("panel",style);controls.add_child(panel)
 var rows:=VBoxContainer.new();panel.add_child(rows)
 var title:=Label.new();title.text="失序之钟 / B · 三域纸艺剧场"
 title.add_theme_color_override("font_color",Color("244d4c"));rows.add_child(title)
 var regions:=HBoxContainer.new();rows.add_child(regions)
 for id: String in Studies.ROOMS:
  var button:=Button.new();button.text=str(Studies.ROOMS[id].name)
  button.custom_minimum_size=Vector2(112,40);button.focus_mode=Control.FOCUS_NONE
  button.pressed.connect(open_study.bind(id));regions.add_child(button)
 var modes:=HBoxContainer.new();rows.add_child(modes)
 for spec: Array in [["B 抽象拼贴","B"],["0 当前美术","0"]]:
  var button:=Button.new();button.text=spec[0];button.custom_minimum_size=Vector2(172,36)
  button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(set_mode.bind(spec[1]));modes.add_child(button)
 description=Label.new();description.add_theme_font_size_override("font_size",15)
 description.add_theme_color_override("font_color",Color("45665c"));rows.add_child(description)
 var retry:=Button.new();retry.text="重置当前样房";retry.focus_mode=Control.FOCUS_NONE
 retry.custom_minimum_size.y=34;retry.pressed.connect(restart);rows.add_child(retry)

func open_study(id: String) -> void:
 if switching or not Studies.ROOMS.has(id):return
 switching=true;ready_for_play=false
 while app.busy:await get_tree().physics_frame
 var invincible:=app.review.invincible
 _remove_paper()
 var accepted: bool=await app.review.begin(id,"","base",invincible)
 if not accepted:
  description.text="样房装载失败 / "+id;switching=false;return
 selected_room=id;initial_room=app.room
 original_art=app.room.get_node("RegionalArt") as PlainsRoomArt
 set_mode(mode)
 ready_for_play=true;switching=false
 print("PAPER LAB READY room=",id," mode=",mode," zoom=",app.camera.zoom," save=MemorySave")

func _remove_paper() -> void:
 if is_instance_valid(paper):remove_child(paper);paper.queue_free()
 paper=null

func set_mode(value: String) -> void:
 mode="0" if value=="0" else "B"
 if not is_instance_valid(initial_room):return
 _remove_paper()
 app.room.visible=mode=="0";app.player.visible=mode=="0"
 original_art.set_process(mode=="0");original_art.ambient.visible=mode=="0"
 if mode=="B":
  paper=World.new();paper.app=app;add_child(paper)
 description.text=selected_room+" / "+str(Studies.ROOMS[selected_room].brief)
 if is_instance_valid(app.controller):app.controller.router.clear(&"paper_mode_switch")

func _unhandled_key_input(event: InputEvent) -> void:
 if not ready_for_play or not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode==KEY_0:set_mode("0")
 elif event.physical_keycode==KEY_B:set_mode("B")
 elif event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
  open_study(["P-R04","F-R01","G-R02"][event.physical_keycode-KEY_1])

func _process(_delta: float) -> void:
 if ready_for_play and app.room!=initial_room:
  ready_for_play=false
  if is_instance_valid(paper):paper.hide()
  restart.call_deferred()

func restart() -> void:
 await open_study(selected_room)
