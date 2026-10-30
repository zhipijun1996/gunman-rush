extends Node2D
## Absorbs an eligible real parent impact; original PlayerProjectile owns the child sweep.
var player: PlayerController
var scope
var latch
var definition: Dictionary
var body: StaticBody2D
var health:=HealthState.new()
var eligible: Dictionary={}
var seen: Dictionary={}
var pending: Dictionary={}
var events: Array=[]
var clock:=0.
var next_hit:=0.
var serial:=0
func setup(spec: Dictionary,controller: PlayerController,context,receiver) -> void:
 definition=spec;player=controller;scope=context;latch=receiver;process_physics_priority=1100
 var hd:=HealthDefinition.new();hd.resource_id=&'approved_hit_turret';hd.max_health=1;hd.initial_current=1;health.configure(hd)
 body=StaticBody2D.new();var r: Array=spec.rect;body.position=Vector2(r[0]+r[2]/2.,r[1]+r[3]/2.);body.collision_layer=8;body.collision_mask=0
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(r[2],r[3]);shape.shape=rect;body.add_child(shape)
 var target:=Damageable.new();target.name='Damageable';target.actor_id=body.get_instance_id();target.faction=&'mechanism';body.add_child(target);add_child(body);target.bind_health(health);target.damage_sink=_receive
 latch.child_owner=body.get_instance_id();player.shoot_ability.shot_fired.connect(_register)
func _register(_direction: Vector2,id: int) -> void:
 eligible[str(id)]={'token':scope.lifetime.token(),'session':player.session_id,'weapon_epoch':player.shoot_ability.weapon_epoch,'expires':clock+player.motor.tuning.projectile_lifetime}
func _receive(hit: Dictionary) -> bool:
 var id:=str(hit.get('event_id',''));var shot: Dictionary=eligible.get(str(hit.get('shot_id',-1)),{})
 if shot.is_empty() or id.is_empty() or seen.has(id) or not pending.is_empty() or clock<next_hit or clock>shot.expires or not scope.lifetime.accepts(shot.token) or not player.active or player.actor_resources.health.terminal or shot.weapon_epoch!=player.shoot_ability.weapon_epoch or hit.get('source_faction',&'')!=&'player' or hit.get('source_actor_id',-1)!=player.motor.get_instance_id() or hit.get('session_id',-1)!=player.session_id or hit.get('target_actor_id',-1)!=body.get_instance_id() or hit.get('target_epoch',-1)!=health.epoch:return false
 seen[id]=true;pending=shot.duplicate();pending.parent=id;pending.at=clock+float(definition.delay);next_hit=clock+float(definition.cooldown);events.append({'type':'turret_parent_accepted','frame':scope.frame,'parent':id});return true
func _physics_process(delta: float) -> void:
 clock+=delta
 if pending.is_empty() or clock<pending.at:return
 var request:=pending;pending={}
 if not scope.lifetime.accepts(request.token) or not player.active or player.actor_resources.health.terminal or player.session_id!=request.session or player.shoot_ability.weapon_epoch!=request.weapon_epoch:return
 serial+=1
 var projectile:=PlayerProjectile.new();projectile.shot_id=1000000+serial;projectile.owner_id=body.get_instance_id();projectile.owner_body=body;projectile.owner_controller=player;projectile.session_id=player.session_id;projectile.weapon_epoch=request.weapon_epoch;projectile.faction=&'turret_shot';projectile.direction=Vector2(definition.direction[0],definition.direction[1]);projectile.speed=definition.speed;projectile.lifetime=definition.lifetime;projectile.fired_airborne=false
 get_parent().add_child(projectile);projectile.global_position=to_global(Vector2(definition.muzzle[0],definition.muzzle[1]));latch.authorize_child(projectile,request.parent,request.token)
 events.append({'type':'turret_child_emitted','frame':scope.frame,'child':projectile.shot_id,'parent':request.parent,'direction':definition.direction,'muzzle':definition.muzzle,'extra_recoil':false,'ammo_refund':false})
func _draw() -> void:
 if not is_instance_valid(body):return
 draw_rect(Rect2(body.position-Vector2(22,24),Vector2(44,48)),Color('627c72'));draw_line(body.position,Vector2(definition.muzzle[0],definition.muzzle[1]),Color('e7c678'),8)
