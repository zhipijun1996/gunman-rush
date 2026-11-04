class_name RuntimeMapTurret
extends Node2D
## The module-pack's accepted-parent/authorized-child relay, using the existing
## PlayerProjectile. No ammo, recoil, health or enemy-AI implementation here.
var player: PlayerController
var lifetime: DemoLifetime
var latch: RuntimeMapRelayLatch
var definition: Dictionary
var body: StaticBody2D
var health:=HealthState.new()
var eligible: Dictionary={}
var seen: Dictionary={}
var pending: Dictionary={}
var clock:=0.0
var next_hit:=0.0
var serial:=0
var children: Array[WeakRef]=[]
var _cancelled:=false
func setup(spec: Dictionary,controller: PlayerController,scope: DemoLifetime,target: RuntimeMapRelayLatch) -> void:
	definition=spec;player=controller;lifetime=scope;latch=target;process_physics_priority=1100
	var hd:=HealthDefinition.new();hd.resource_id=&"mapgen_hit_turret";hd.max_health=1;hd.initial_current=1;health.configure(hd)
	var rect:=RuntimeMapShotLatchAdapter.rectangle(spec.rect)
	body=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=8;body.collision_mask=0
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;shape.shape=box;body.add_child(shape)
	var receiver:=Damageable.new();receiver.name="Damageable";receiver.actor_id=body.get_instance_id();receiver.faction=&"mechanism";body.add_child(receiver);add_child(body)
	receiver.bind_health(health);receiver.damage_sink=_receive
	latch.child_owner=body.get_instance_id();player.shoot_ability.shot_fired.connect(_register)
func _register(_direction: Vector2,id: int) -> void:
	if not _cancelled and lifetime.active and player.active:
		eligible[str(id)]={"token":lifetime.token(),"session":player.session_id,"weapon_epoch":player.shoot_ability.weapon_epoch,"expires":clock+player.motor.tuning.projectile_lifetime}
func _receive(hit: Dictionary) -> bool:
	var id:=str(hit.get("event_id",""));var shot: Dictionary=eligible.get(str(hit.get("shot_id",-1)),{})
	if _cancelled or shot.is_empty() or id.is_empty() or seen.has(id) or not pending.is_empty() or clock<next_hit or clock>float(shot.expires) or not lifetime.accepts(shot.token) or not player.active or player.actor_resources.health.terminal or shot.weapon_epoch!=player.shoot_ability.weapon_epoch or hit.get("source_faction",&"")!=&"player" or hit.get("source_actor_id",-1)!=player.motor.get_instance_id() or hit.get("session_id",-1)!=player.session_id or hit.get("target_actor_id",-1)!=body.get_instance_id() or hit.get("target_epoch",-1)!=health.epoch:return false
	seen[id]=true;pending=shot.duplicate();pending["parent"]=id;pending["at"]=clock+float(definition.delay);next_hit=clock+float(definition.cooldown);return true
func _physics_process(delta: float) -> void:
	clock+=delta
	for key: Variant in eligible.keys():
		if clock>float(eligible[key].expires):eligible.erase(key)
	if pending.is_empty() or clock<float(pending.at):return
	var request:=pending;pending={}
	if _cancelled or not lifetime.accepts(request.token) or not player.active or player.actor_resources.health.terminal or player.session_id!=request.session or player.shoot_ability.weapon_epoch!=request.weapon_epoch:return
	serial+=1
	var projectile:=PlayerProjectile.new();projectile.shot_id=1000000+serial;projectile.owner_id=body.get_instance_id();projectile.owner_body=body;projectile.owner_controller=player;projectile.session_id=player.session_id;projectile.weapon_epoch=request.weapon_epoch;projectile.faction=&"turret_shot";projectile.direction=RuntimeMapShotLatchAdapter.point(definition.direction);projectile.speed=float(definition.speed);projectile.lifetime=float(definition.lifetime);projectile.fired_airborne=false
	add_child(projectile);projectile.global_position=to_global(RuntimeMapShotLatchAdapter.point(definition.muzzle));latch.authorize_child(projectile,request.parent,request.token);children.append(weakref(projectile))
func cancel_pending() -> void:
	pending.clear();eligible.clear();seen.clear()
	for ref: WeakRef in children:
		var projectile: Object=ref.get_ref()
		if is_instance_valid(projectile):projectile.queue_free()
	children.clear()
func cancel() -> void:_cancelled=true;cancel_pending()
func _exit_tree() -> void:cancel()
func _draw() -> void:
	if not is_instance_valid(body):return
	var rect:=RuntimeMapShotLatchAdapter.rectangle(definition.rect)
	UnderworldTerrain.draw_mechanism_beam(self,rect)
	draw_line(body.position,RuntimeMapShotLatchAdapter.point(definition.muzzle),Color("e7c678"),8)
