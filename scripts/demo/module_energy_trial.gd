class_name ModuleEnergyTrial
extends Node2D
## Explicit development fixture; uses actual shot, damage, reward and build owners.
var lab: ModuleLab
var build:=BuildState.new()
var rewards:=RewardService.new()
var modal: StageRewardModal
var toast: ItemAcquiredToast
var offer: RewardOffer
var drone: EnemyMotor
var _hud: Label
var claimed:=false
var _choice_token: DemoToken
func setup(owner_lab: ModuleLab) -> void:
	lab=owner_lab
	build.configure(lab.controller);rewards.configure(lab.lifetime,build)
	drone=preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
	var actor:=drone.get_node("Actor") as EnemyActor
	actor.definition=actor.definition.duplicate(true)
	actor.definition.health_definition=actor.definition.health_definition.duplicate(true)
	actor.definition.health_definition.max_health=20;actor.definition.health_definition.initial_current=20
	drone.position=Vector2(650,550);add_child(drone)
	actor.set_physics_process(false) # Stationary training target, not a new combat AI.
	lab.policy.bind_damageable(&"energy_training_target",actor.damageable,actor.health)
	var items: Array[ItemDefinition]=[preload("res://resources/items/efficient_grip.tres"),preload("res://resources/items/echo_magazine.tres")]
	offer=rewards.create_offer(&"practice_energy_choice",items,&"practice_energy_fixture")
	modal=StageRewardModal.new();add_child(modal);modal.item_selected.connect(_choose)
	toast=ItemAcquiredToast.new();add_child(toast)
	_hud=Label.new();_hud.position=Vector2(170,225);_hud.add_theme_font_size_override("font_size",17);_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_hud)
func _process(_delta: float) -> void:
	_hud.text="ENERGY & ITEMS / TRAINING DRONE HP %.0f\nShots spend energy. Real hits refill it. Air hits return one round.\nPractice item is a fixture; no Run or permanent reward." % (drone.get_node("Actor") as EnemyActor).health.current
func show_choice() -> void:
	if claimed or modal.opened or not lab.ready_for_play: return
	lab.controller.router.clear("practice_choice");lab.controller.air_focus_ability.stop();get_tree().paused=true
	_choice_token=lab.lifetime.token()
	modal.show_offer(offer,"Practice only / discarded on Retry or Home")
func _choose(id: StringName) -> void:
	if claimed or not modal.opened or not lab.lifetime.accepts(_choice_token): return
	var request:=RewardClaimRequest.new();request.token=_choice_token;request.offer_id=offer.offer_id;request.option_id=id;request.claim_id=&"practice_energy_claim"
	if not rewards.claim(request).accepted(): return
	claimed=true;modal.close()
	for item: ItemDefinition in offer.candidates:
		if item.stable_id==id: toast.show_item(item)
	lab.controller.router.clear("practice_choice_close");get_tree().paused=false
