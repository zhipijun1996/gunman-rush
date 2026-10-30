extends Node
## Original region chest transaction/choice consumer, with original UI and grants.
var app: DemoApp
var stage: PlainsRegionStage
var scope
var specs: Array=[]
var events: Array=[]
var pending: Array=[]
var instance_key:=""
class RegionApp extends DemoApp:
	func _ready() -> void:set_process(false);set_physics_process(false)
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _draw() -> void:pass
	func _layout_region_hud() -> void:pass # Fixture has no outer-region HUD.
class RegionStage extends PlainsRegionStage:
	func _ready() -> void:assembly_ok=true;set_physics_process(false)
	func _physics_process(_delta: float) -> void:pass
	func _draw() -> void:
		for chest: Dictionary in chests:
			if not chest.claimed:draw_rect(Rect2(to_local(chest.position)-Vector2(12,12),Vector2(24,24)),Color("d6ab54"))
func setup(data: Array, host: Node2D, player: PlayerController, existing_scope, wallet: RunWallet, meta: MetaProgression, shared_region: PlainsRegionState, instance_id: String) -> Dictionary:
	if app!=null:return {"ok":false,"reason":"already_bound"}
	if player==null or existing_scope==null or wallet==null or meta==null or shared_region==null or instance_id.is_empty():return {"ok":false,"reason":"explicit_shared_region_wallet_meta_and_instance_required"}
	scope=existing_scope;specs=data.duplicate(true);instance_key=instance_id
	app=RegionApp.new();app.lifetime=scope.lifetime;app.player=player.motor;app.controller=player;app.wallet=wallet;app.meta=meta
	app.connected_region=true;app.region_state=shared_region;app.meta_persistence_enabled=false;app._run_receipt_prefix="module/"+instance_id
	app.build=BuildState.new();app.director=DemoRunDirector.new(scope.lifetime);app.director.state=DemoRunDirector.State.IN_STAGE;app.director.stage_index=1
	app.director.manifest=RunManifest.new("offline-module-region-chests")
	var exits: Array[ExitOffer]=[];app.director.manifest.append_stage(1,&"combat",&"forest",exits)
	add_child(app)
	app.reward_modal=StageRewardModal.new();app.add_child(app.reward_modal)
	app.item_toast=ItemAcquiredToast.new();app.add_child(app.item_toast)
	app.reward_modal.item_selected.connect(func(id: StringName):app._commit_region_choice(id))
	stage=RegionStage.new();stage.region_state=shared_region;app.stage=stage;app.add_child(stage)
	stage.top_level=true;stage.global_position=Vector2.ZERO
	for raw: Dictionary in specs:
		var chest: Dictionary=raw.duplicate(true);chest.id=instance_id+"/"+str(raw.id)
		chest.position=host.to_global(Vector2(raw.position[0],raw.position[1]));chest.claimed=shared_region.claimed.get(chest.id,false)
		stage.chests.append(chest)
	stage.queue_redraw()
	return {"ok":true,"consumer":"DemoApp._commit_interact/_region_interact/_claim_region_chest","interaction_radius":80,"choice":"OR","resources_reset":false,"shared_region_required":true,"outer_world_shortcuts":"UNKNOWN"}
func request_interaction() -> void:pending.append({"type":"interact"})
func request_choice(kind: String) -> void:pending.append({"type":"choose","kind":kind})
func capture() -> void:
	if app==null:return
	while not pending.is_empty():
		var command: Dictionary=pending.pop_front();var accepted:=false;var selected:=""
		var selected_index: int=app._region_chest
		var selected_id: String=str(specs[selected_index].id) if selected_index>=0 and selected_index<specs.size() else ""
		if command.type=="interact":
			var before:=app.reward_modal.opened
			if stage.nearby_chest(app.player.global_position)>=0:app._commit_interact()
			accepted=not before and app.reward_modal.opened
			if accepted:selected_id=str(specs[app._region_chest].id)
		elif command.type=="choose" and app.reward_modal.opened and app._region_offer!=null:
			for item: ItemDefinition in app._region_offer.candidates:
				var resource:=item as ResourceRewardChoice
				if resource!=null and resource.resource_kind==str(command.kind):selected=str(resource.stable_id);break
			if not selected.is_empty():accepted=app._commit_region_choice(StringName(selected))
		events.append({"frame":scope.frame,"type":"native_region_"+str(command.type),"id":selected_id,"kind":str(command.get("kind","")),"selected":selected,"accepted":accepted,"coins":app.wallet.balance,"notes":app.meta.snapshot().notes,"modal_open":app.reward_modal.opened})
	stage.queue_redraw()
func snapshot() -> Dictionary:
	if app==null:return {"bound":false}
	var observed: Array=[]
	for i: int in stage.chests.size():
		var chest: Dictionary=stage.chests[i];observed.append({"id":specs[i].id,"instance_id":chest.id,"position":[chest.position.x,chest.position.y],"claimed":chest.claimed,"resources":chest.resources.duplicate(true)})
	return {"bound":true,"consumer":"DemoApp._region_interact/_claim_region_chest","interaction_radius":80,"choice":"OR","chests":observed,"events":events.duplicate(true),"coins":app.wallet.balance,"notes":app.meta.snapshot().notes,"modal_open":app.reward_modal.opened,"resources_reset":false,"outer_world_shortcuts":"UNKNOWN"}
