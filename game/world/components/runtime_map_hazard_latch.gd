class_name RuntimeMapHazardLatch
extends RuntimeMapRelayLatch
## Source-authored retractable hazard bands use the existing damage policy.
## Supporting platforms and the player's resources never participate in toggling.
var bands: Array=[]
var emitters: Array[DemoContactEmitter]=[]
var extended:=true
var thorn_bands:=false
func setup_hazards(player: PlayerController,scope: DemoLifetime,policy: FrameDamagePolicy,spec: Dictionary,source_prefix: String,toggle: bool) -> void:
	direct_primary=true;repeatable=toggle;thorn_bands=not toggle
	link_id=str(spec.id);bands=spec.get("bands",spec.get("hazards",[])).duplicate(true)
	extended=bool(spec.get("initial_extended",true))
	super.setup(player,scope,RuntimeMapShotLatchAdapter.point(spec.bell),Rect2(-4096,-4096,8,8))
	gate_visual_enabled=false;gate_body.collision_layer=0;gate_shape.disabled=true;is_open=not extended
	for raw: Dictionary in bands:
		var rectangle:=RuntimeMapShotLatchAdapter.rectangle(raw.rect)
		var emitter:=DemoContactEmitter.attach(self,policy,player,StringName(source_prefix+str(raw.id)),DamageRequest.Kind.ENVIRONMENT,rectangle.size*.5)
		emitter.position=rectangle.get_center();emitter.enabled=extended;emitters.append(emitter)
	queue_redraw()
func _commit_open(request: Dictionary) -> void:
	if not request_is_current(request) or is_open and not repeatable:return
	extended=not extended if repeatable else false
	for emitter: DemoContactEmitter in emitters:emitter.enabled=extended
	is_open=not extended;_opened_at=_clock;open_count+=1;_eligible_shots.clear();_seen.clear();_play_bell();opened.emit();queue_redraw()
func restore_region_state(data: Dictionary) -> void:
	super.restore_region_state(data);extended=not is_open
	for emitter: DemoContactEmitter in emitters:emitter.enabled=extended
func restore_region_opened(_recorded: bool) -> void:pass
func _draw() -> void:
	if not is_instance_valid(controller):return
	UnderworldTerrain.draw_mechanism_bell(self,bell_position,not extended,_opened_at>=0 and _clock-_opened_at<.16)
	if not extended:return
	for raw: Dictionary in bands:
		var rectangle:=RuntimeMapShotLatchAdapter.rectangle(raw.rect)
		if thorn_bands:
			var bottom:=str(raw.id).ends_with("bottom")
			var host:=Rect2(Vector2(rectangle.position.x,rectangle.position.y-8 if bottom else rectangle.end.y),Vector2(rectangle.size.x,8))
			UnderworldHazardTiles.draw_band(self,rectangle,PlatformThornDefinition.Face.BOTTOM if bottom else PlatformThornDefinition.Face.TOP,host)
			continue
		for i: int in maxi(1,int(rectangle.size.x/16)):
			var at:=rectangle.position+Vector2(i*16+8,rectangle.size.y*.5)
			draw_circle(at,7,Color("b7a084"));draw_line(at-Vector2(9,0),at+Vector2(9,0),Color("ddc59e"),2)
