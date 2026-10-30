extends Node
## Isolated binding of the ORIGINAL game's coin/note consumer. This does not
## replace grant rules, interaction distance, health/lifetime guards or receipts.
var app: DemoApp
var stage: GeneratedDemoStage
var scope
var specs: Array=[]
var events: Array=[]
var pending_interactions:=0

class PickupApp extends DemoApp:
	func _ready() -> void:
		set_process(false);set_physics_process(false)
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _draw() -> void:pass

class PickupStage extends GeneratedDemoStage:
	func _ready() -> void:
		assembly_ok=true;exit_positions.clear();set_physics_process(false)
	func _physics_process(_delta: float) -> void:pass

func setup(data: Array, host: Node2D, player: PlayerController, existing_scope, wallet: RunWallet, meta: MetaProgression, instance_key: String) -> Dictionary:
	if app!=null:return {"ok":false,"reason":"already_bound"}
	if player==null or existing_scope==null or wallet==null:return {"ok":false,"reason":"explicit_game_services_required"}
	for raw: Dictionary in data:
		if str(raw.get("kind",""))not in ["coin","note"] or int(raw.get("amount",-1))<0:return {"ok":false,"reason":"unsupported_original_pickup"}
		if raw.kind=="note" and meta==null:return {"ok":false,"reason":"explicit_meta_required_for_notes"}
	scope=existing_scope;specs=data.duplicate(true)
	app=PickupApp.new();app.lifetime=scope.lifetime;app.player=player.motor;app.controller=player;app.wallet=wallet
	app.meta=meta if meta!=null else MetaProgression.new()
	app.meta_persistence_enabled=false;app._run_receipt_prefix="module/"+instance_key
	app.director=DemoRunDirector.new(scope.lifetime);app.director.state=DemoRunDirector.State.IN_STAGE;app.director.stage_index=1
	app.director.manifest=RunManifest.new("offline-module-pickups")
	var exits: Array[ExitOffer]=[]
	app.director.manifest.append_stage(1,&"combat",&"forest",exits)
	add_child(app)
	stage=PickupStage.new();app.stage=stage;app.add_child(stage)
	stage.top_level=true;stage.global_position=Vector2.ZERO
	for raw: Dictionary in specs:
		stage.pickups.append({"id":raw.id,"kind":raw.kind,"amount":int(raw.amount),"position":host.to_global(Vector2(raw.position[0],raw.position[1])),"claimed":false})
	stage.queue_redraw()
	return {"ok":true,"source":"DemoApp._commit_pickup","interaction_radius":46,"resources_reset":false,"meta_persistence_configured":false}

func request_interaction() -> void:
	pending_interactions+=1

func capture() -> void:
	if app==null:return
	stage.clock=maxf(0,float(scope.frame)/60.)
	# This callback runs AFTER original policy priority1000. Native _can_interact
	# still checks actual lifetime, health and pause state before any grant.
	while pending_interactions>0:
		pending_interactions-=1
		var chosen:=-1;var nearest:=INF
		for i: int in stage.pickups.size():
			var p: Dictionary=stage.pickups[i]
			if p.claimed:continue
			var distance:=app.player.global_position.distance_to(p.position)
			if distance<nearest:nearest=distance;chosen=i
		var accepted:=chosen>=0 and app._commit_pickup(chosen)
		events.append({"frame":scope.frame,"type":"original_pickup_interaction","id":str(stage.pickups[chosen].id)if chosen>=0 else"","distance":nearest if chosen>=0 else-1,"accepted":accepted,"coins":app.wallet.balance,"notes":app.meta.snapshot().notes})
	stage.queue_redraw()

func snapshot() -> Dictionary:
	if app==null:return {"bound":false}
	var observed: Array=[]
	for pickup: Dictionary in stage.pickups:
		var row: Dictionary=pickup.duplicate(true);row.position=[pickup.position.x,pickup.position.y];observed.append(row)
	return {"bound":true,"consumer":"DemoApp._commit_pickup","interaction_radius":46,"pickups":observed,"events":events.duplicate(true),"coins":app.wallet.balance,"notes":app.meta.snapshot().notes,"resources_reset":false,"meta_persistence_configured":false}
