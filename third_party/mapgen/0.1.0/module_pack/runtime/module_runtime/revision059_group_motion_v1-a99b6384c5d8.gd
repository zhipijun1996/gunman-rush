extends ShotLatch
## One accepted original shot, two original clocks; never snap or retime.
var targets: Array[ModuleMovingPlatform]=[]
var events: Array=[]
var scope
func bind_group(platforms: Array[ModuleMovingPlatform],clock_source) -> void:
 scope=clock_source;targets=platforms
 for p: ModuleMovingPlatform in targets:p.bind_bell_control()
 motion_target=targets[0];motion_mode=true;gate_visual_enabled=false
 gate_body.collision_layer=0;gate_shape.disabled=true
func _commit_open(request: Dictionary) -> void:
 if request.is_empty() or request.get('request_epoch',-1)!=_request_epoch or _cancelled or not is_inside_tree() or not lifetime.accepts(request.token) or not controller.active or controller.actor_resources.health.terminal or controller.session_id!=request.session or health.epoch!=request.health_epoch:return
 var running:=not targets[0].motion_running;var before: Array=[]
 for p: ModuleMovingPlatform in targets:before.append({'id':str(p.definition.platform_id),'clock':p.motion_clock,'position':[p.position.x,p.position.y]})
 for p: ModuleMovingPlatform in targets:p.set_motion_running(running)
 is_open=running;_opened_at=_clock;open_count+=1;_eligible_shots.clear();_seen.clear()
 events.append({'type':'atomic_group_motion','frame':scope.frame,'cause':request.id,'running':running,'before':before});_play_bell();opened.emit();queue_redraw()
