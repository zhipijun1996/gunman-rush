extends ShotLatch
var child_requests: Dictionary={}
var child_owner: int=-1
var emitters: Array[DemoContactEmitter]=[]
var hazard_rects: Array=[]
var events: Array=[]
var scope
func setup_thorns(player: PlayerController,context,bell: Vector2,access: Vector2,hazards: Array) -> void:
 scope=context;link_id='target-bell';formal_presentation=true;super.setup(player,context.lifetime,bell,Rect2(-4096,-4096,8,8));gate_visual_enabled=false;gate_body.collision_layer=0;gate_shape.disabled=true;add_access_bell(access,false,false)
 for spec: Dictionary in hazards:
  var r: Array=spec.rect;var emitter:=DemoContactEmitter.new();emitter.controller=player;emitter.policy=context.policy;emitter.kind=DamageRequest.Kind.ENVIRONMENT;emitter.source_id=StringName("module/"+str(get_parent().instance_key).uri_encode()+"/"+str(spec.id).uri_encode());emitter.position=Vector2(r[0]+r[2]/2.,r[1]+r[3]/2.);emitter.half_size=Vector2(r[2]/2.,r[3]/2.);add_child(emitter);emitters.append(emitter);hazard_rects.append(Rect2(r[0],r[1],r[2],r[3]))
 opened.connect(_retract)
func _retract() -> void:
 for emitter: DemoContactEmitter in emitters:emitter.enabled=false
 events.append({'type':'native_thorns_retracted','frame':scope.frame,'open_count':open_count,'platform_removed':false});queue_redraw()
func _draw() -> void:
 super._draw()
 if is_open:return
 for r: Rect2 in hazard_rects:
  var points:=PackedVector2Array()
  for i: int in range(0,int(r.size.x),12):points.append(Vector2(r.position.x+i,r.end.y));points.append(Vector2(r.position.x+i+6,r.position.y));points.append(Vector2(r.position.x+i+12,r.end.y))
  draw_polyline(points,Color('c1a770'),2)

func authorize_child(projectile: PlayerProjectile,parent: String,token: DemoToken) -> void:
 child_requests[str(projectile.shot_id)]={'token':token,'parent':parent,'session':projectile.session_id,'expires':_clock+projectile.lifetime,'weapon_epoch':projectile.weapon_epoch}
func _receive_projectile(hit: Dictionary) -> bool:
 if hit.get('source_faction',&'')==&'player':return super._receive_projectile(hit)
 var child: Dictionary=child_requests.get(str(hit.get('shot_id',-1)),{})
 if child.is_empty() or _cancelled or is_open or not _pending.is_empty() or not lifetime.accepts(child.token) or _clock>child.expires or not controller.active or controller.actor_resources.health.terminal or child.session!=controller.session_id or child.weapon_epoch!=controller.shoot_ability.weapon_epoch or hit.get('source_faction',&'')!=&'turret_shot' or hit.get('source_actor_id',-1)!=child_owner or hit.get('session_id',-1)!=controller.session_id or hit.get('target_actor_id',-1)!=receiver.actor_id or hit.get('target_epoch',-1)!=health.epoch:return false
 var id:=str(hit.get('event_id',''))
 if id.is_empty() or _seen.has(id):return false
 _seen[id]=true;_pending={'id':id,'token':child.token,'session':controller.session_id,'health_epoch':health.epoch,'request_epoch':_request_epoch};child_requests.erase(str(hit.shot_id));return true
