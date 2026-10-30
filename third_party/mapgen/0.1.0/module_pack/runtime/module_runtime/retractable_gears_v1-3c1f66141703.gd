extends ShotLatch
## Reuse original projectile eligibility/lifetime and DemoContactEmitter damage.
## One receiver changes both authored hazard bands; support platforms never move.
var bands: Array=[]
var emitters: Array[DemoContactEmitter]=[]
var extended:=true
var events: Array=[]
var frame_source

func configure(spec: Dictionary, host: Node2D, player: PlayerController, scope) -> void:
	link_id=str(spec.id);frame_source=scope;motion_mode=true
	bands=spec.bands.duplicate(true);extended=bool(spec.get("initial_extended",true))
	host.add_child(self)
	# Receiver setup needs a gate node; its zero-collision local placeholder is
	# disabled before any physics step. No external/hidden supporting geometry.
	setup(player,scope.lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(Vector2(spec.bell[0],spec.bell[1]),Vector2.ONE))
	gate_visual_enabled=false;gate_body.collision_layer=0;gate_shape.disabled=true
	for raw: Dictionary in bands:
		var r:=Rect2(raw.rect[0],raw.rect[1],raw.rect[2],raw.rect[3])
		var emitter:=DemoContactEmitter.new();emitter.controller=player;emitter.policy=scope.policy
		emitter.kind=DamageRequest.Kind.ENVIRONMENT;emitter.source_id=StringName("module/"+str(host.instance_key).uri_encode()+"/"+str(raw.id).uri_encode())
		emitter.position=r.get_center();emitter.half_size=r.size/2;emitter.enabled=extended
		host.add_child(emitter);emitters.append(emitter)
	queue_redraw()

func _commit_open(request: Dictionary) -> void:
	# Same guard as the existing reusable paired-latch Cell. Original receiver
	# alone validates and schedules the actual eligible projectile hit.
	if request.is_empty() or request.get("request_epoch",-1)!=_request_epoch or _cancelled or not is_inside_tree() or not lifetime.accepts(request.token) or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id!=request.session or health.epoch!=request.health_epoch:return
	extended=not extended
	for emitter: DemoContactEmitter in emitters:emitter.enabled=extended
	is_open=not extended;_opened_at=_clock;open_count+=1;_eligible_shots.clear();_seen.clear()
	events.append({"frame":frame_source.frame,"type":"gears_toggle","id":link_id,"extended":extended,"band_count":emitters.size(),"accepted_projectile_id":str(request.id)})
	_play_bell();opened.emit();queue_redraw()

func snapshot_gears() -> Dictionary:
	return {"id":link_id,"extended":extended,"band_enabled":emitters.map(func(e):return e.enabled),"toggle_count":open_count,"events":events.duplicate(true)}

func _draw() -> void:
	if not is_instance_valid(controller):return
	UnderworldTerrain.draw_mechanism_bell(self,bell_position,not extended,_opened_at>=0 and _clock-_opened_at<.16)
	for raw: Dictionary in bands:
		var r:=Rect2(raw.rect[0],raw.rect[1],raw.rect[2],raw.rect[3])
		draw_rect(r,Color("ba6547") if extended else Color(0.35,0.35,0.35,0.25),false,2)
		if extended:
			for i: int in int(r.size.x/16):
				var x:=r.position.x+i*16+8
				draw_circle(Vector2(x,r.get_center().y),7,Color("b7a084"))
				draw_line(Vector2(x-10,r.get_center().y),Vector2(x+10,r.get_center().y),Color("ddc59e"),2)
