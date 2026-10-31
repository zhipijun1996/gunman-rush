class_name RunComposition
extends RefCounted
## Explicit scene assembly. No App lookup, flow state or gameplay rules here.
const PLAYER := preload("res://scenes/player/player.tscn")

static func create_player(parent: Node, session: RunSession, selection: HomeWeaponSelection) -> bool:
	# Publish the same references before entering the tree, as the original App
	# did. Parenting and ready/processing order are deliberately unchanged.
	session.player = PLAYER.instantiate()
	session.player.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(session.player)
	session.controller = session.player.get_node("Controller") as PlayerController
	if not selection.apply(session.controller):
		parent.remove_child(session.player)
		session.player.queue_free()
		session.release_player_references()
		return false
	return true

static func configure_capabilities(controller: PlayerController, use_energy: bool, grant_grapple: bool) -> bool:
	if use_energy and not controller.enable_shot_energy(): return false
	if grant_grapple: controller.traversal.grant(&"grapple")
	return true

static func attach_player_guides(player: PlayerMotor, controller: PlayerController) -> void:
	var vignette := FocusVignette.new()
	vignette.name = "FocusVignette"
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var aim_guide := DemoAimGuide.new()
	aim_guide.controller = controller
	player.add_child(aim_guide)
