extends "res://tests/all_weapons_runner.gd"
## Re-run every original all-weapons assertion in the real Underworld branch.
## Original fixtures explicitly initialize resources; this is not natural-route
## acquisition or live player's earned-energy evidence.
func fixture(at: Vector2 = Vector2(100,500)) -> void:
	await super.fixture(at)
	world.set_meta("underworld_formal_style",true)
	controller.shoot_ability.shot_fired.connect(_install_actual_skin)
func _install_actual_skin(_direction: Vector2,_serial: int) -> void:
	for shot: PlayerProjectile in controller.shoot_ability.get_projectiles():
		if is_instance_valid(shot.presentation): continue
		var skin:=PixelPlainsProjectile.new()
		skin.projectile=shot;shot.presentation=skin;shot.add_child(skin)
		check(UnderworldProjectileVisual.enabled(shot),"actual formal projectile skin selects Underworld branch")
