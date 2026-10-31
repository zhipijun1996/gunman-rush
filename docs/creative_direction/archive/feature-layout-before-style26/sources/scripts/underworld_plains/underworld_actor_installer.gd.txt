extends RefCounted
## One-way orchestration, loaded only when an actual stage installs its actors.
static func install(stage: Node2D) -> Dictionary:
	stage.set_meta("underworld_formal_style",true)
	var counts := {"enemies":0,"bosses":0}
	for child: Node in stage.get_children():
		if child is EnemyMotor:
			var actor := child.get_node_or_null("Actor") as EnemyActor
			if actor == null: continue
			if EnemyPresentationBinding.replace(actor, &"underworld"):
				counts.enemies += 1
		for presentation: Node in child.get_children():
			if presentation is BellstriderPresentation or presentation is WindkeeperPresentation or presentation is WindkeeperPressurePresentation:
				presentation.queue_redraw()
				counts.bosses += 1
	return counts

