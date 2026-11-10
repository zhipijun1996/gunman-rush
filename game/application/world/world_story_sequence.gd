class_name WorldStorySequence
extends Node2D
## Authored first-visit scenes; receipts remain owned by FixedWorldState, camera by WorldCamera.
var app: FixedWorldApp
var settings: Dictionary = {}
var active := false
var finishing := false
var dialogue_active := false
var phase := "idle"
var age := 0.0
var line_index := 0
var camera_token := -1
var camera_mode := Node.PROCESS_MODE_INHERIT
var art_mode := Node.PROCESS_MODE_INHERIT
var art: PlainsRoomArt
var figure: WorldSpriteAnimation
var focus := Vector2.ZERO
var committed := false
var bars: Control
var clock_gears: Array[Sprite2D] = []
var repair_animation: WorldSpriteAnimation

func setup(application: FixedWorldApp) -> void:
 app=application;settings=app.room.story_sequence
 process_mode=Node.PROCESS_MODE_ALWAYS
 z_index=30
 if settings.is_empty():set_process(false);return
 # The six-room formal construction has no east route yet; do not direct its player into an unavailable quest.
 if settings.get("kind")=="station" and app.content.room("P-R33").is_empty():
  app.enqueue("action","station_briefing");set_process(false);return
 if settings.has("npc_point"):
  figure=WorldSpriteAnimation.new();figure.asset_id="reclaimer"
  figure.position=FixedWorldProvider.point(settings.npc_point)+Vector2(0,18);add_child(figure)
  figure.process_mode=Node.PROCESS_MODE_ALWAYS
  _place_station_figure()
 art=app.room.get_node_or_null("RegionalArt") as PlainsRoomArt
 if settings.get("kind")=="repair":
  for offset:Vector2 in [Vector2(-46,-30),Vector2(44,-10)]:
   var gear:=Sprite2D.new();gear.texture=preload("res://assets/plains_v07/native/mill_gear.png");gear.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
   gear.position=FixedWorldProvider.point(settings.effect_point)+offset;gear.z_index=-31;add_child(gear);clock_gears.append(gear)

func _place_station_figure() -> void:
 if figure==null or settings.get("kind")!="station":return
 if app.state.has("clockheart_briefed") or app.state.has("clock_P"):
  figure.hide();return
 # The gate owns the collision and permission; this actor makes its reason visible.
 var at:Vector2=FixedWorldProvider.point(settings.get("blocking_point",settings.npc_point) if app.state.value.receipts.has("station_briefing") else settings.npc_point)
 figure.position=at+Vector2(0,18)

func _process(delta: float) -> void:
 if app==null or not is_instance_valid(app.room) or not is_instance_valid(app.player):return
 if settings.get("kind")=="repair" and app.state.has("clock_P"):
  for i:int in clock_gears.size():clock_gears[i].rotation+=delta*(1 if i==0 else -1)*(.8 if not active else clampf((age-1.0)/2,0,.8))
 if not active:
  if settings.get("kind")=="repair" or app.paused or app.busy:return
  if app.state.value.receipts.has(str(settings.get("action",""))):return
  if FixedWorldProvider.rect(settings.trigger).has_point(app.player.position) and app.player.is_on_floor():begin()
  return
 if dialogue_active:return
 var previous_age:=age
 age+=delta
 if phase=="repair":
  if (age>=.4 and previous_age<.4) or (age>=.9 and previous_age<.9):GameAudio.cue_cinematic(self,&"armour")
  if age>=1.4 and not committed:
   committed=true
   GameAudio.cue_cinematic(self,&"mechanism_bell")
   (app.camera as WorldCamera).shake(2.5,.35)
  if age>=5.2:_show_lines()
 elif age>=float(settings.get("establish_seconds",1.4)):_show_lines()
 queue_redraw()

func begin() -> void:
 if active or not app._pause_world():return
 active=true;age=0;line_index=0
 phase="repair" if settings.get("kind")=="repair" else "establish"
 focus=FixedWorldProvider.point(settings.get("focus",[app.player.position.x,app.player.position.y-64]))
 camera_mode=app.camera.process_mode;app.camera.process_mode=Node.PROCESS_MODE_ALWAYS
 var display:=FixedWorldProvider.rect(settings.get("display",app.room.contract.world_geometry.bounds_world_units))
 camera_token=(app.camera as WorldCamera).begin_takeover(self,focus,display,.8)
 if art!=null:art_mode=art.process_mode;art.process_mode=Node.PROCESS_MODE_ALWAYS
 bars=Control.new();bars.mouse_filter=Control.MOUSE_FILTER_IGNORE;bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);app.ui.root.add_child(bars)
 for bottom:bool in [false,true]:
  var stripe:=ColorRect.new();stripe.color=Color(0.025,.045,.055,.85);stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE;bars.add_child(stripe)
  stripe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
  stripe.offset_top=-22 if bottom else 0;stripe.offset_bottom=0 if bottom else 22
 if figure!=null:figure.play_event()
 if phase=="repair":
  GameAudio.cue(app,&"confirm")
  for host:Node in app.room.get_children():
   if host is WorldRoomInteraction and host.action_id=="repair_P":
    repair_animation=host.animation
    if repair_animation!=null:repair_animation.process_mode=Node.PROCESS_MODE_ALWAYS;repair_animation.play_event()

func play_repair(at: Vector2) -> void:
 if settings.get("kind")!="repair" or active:return
 focus=at;begin()

func _show_lines() -> void:
 if settings.get("lines",[]).is_empty():finish();return
 dialogue_active=true;_present_line()
func _present_line() -> void:
 var panel:=app.ui.panel("dialogue",str(settings.get("speaker","守钟匠")),str(settings.lines[line_index])) as WorldDialogue
 panel.compact_actions=true
 (panel.get_child(0) as ColorRect).color=Color(.02,.04,.05,.12)
 var next:=panel.button("继续" if line_index+1<settings.lines.size() else "记住了",advance)
 var skip:=panel.button("跳过本段",finish)
 var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);panel.rows.add_child(actions)
 next.reparent(actions);skip.reparent(actions);next.size_flags_horizontal=Control.SIZE_EXPAND_FILL;skip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.focus_first()
func advance() -> void:
 if not active:return
 if not dialogue_active:_show_lines();return
 line_index+=1
 if line_index<settings.lines.size():_present_line()
 else:finish()
func finish() -> void:
 if not active or finishing:return
 finishing=true
 _finish.call_deferred()
func _finish() -> void:
 finishing=false
 if not active:return
 var action:=str(settings.get("action",""))
 if not action.is_empty() and not app.state.value.receipts.has(action):
  var candidate:=app.state.action_candidate(action,app.room.room_id,"main")
  if candidate.is_empty() or not app.state.commit(candidate,app.state.revision):
   app.status="剧情进度未保存，请重试。";return
 active=false;dialogue_active=false
 _release_view()
 app._close_panel()
 app._apply_capabilities()
 _place_station_figure()
 queue_redraw()
func _release_view() -> void:
 if is_instance_valid(app.camera):
  (app.camera as WorldCamera).end_takeover(camera_token);app.camera.process_mode=camera_mode
 if is_instance_valid(art):art.process_mode=art_mode
 if is_instance_valid(bars):bars.queue_free()
 if is_instance_valid(repair_animation):repair_animation.process_mode=Node.PROCESS_MODE_PAUSABLE
func _exit_tree() -> void:
 if active:_release_view()
func _draw() -> void:
 if not active or phase!="repair":return
 var center:=FixedWorldProvider.point(settings.get("effect_point",[0,0]))
 var spreading:=clampf((age-1.4)/3.2,0,1)
 for i:int in 32:
  var angle:=float(i)*TAU/32
  var distance:=20+spreading*(80+float(i%5)*26)
  var at:=(center+Vector2.from_angle(angle)*distance).round()
  draw_rect(Rect2(at,Vector2(2,2)),Color(1,.82,.43,(1-spreading)*.8))
 if age>=1.4:
  draw_arc(center,18+spreading*160,-PI,0,36,Color(.85,.73,.42,(1-spreading)*.4),1)
