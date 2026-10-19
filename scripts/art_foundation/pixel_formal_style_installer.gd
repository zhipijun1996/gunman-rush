extends RefCounted
## One-way orchestration; the drawing helper never statically depends on this script.
static func install(stage: Node2D) -> Dictionary:
	stage.set_meta("pixel_formal_style",true)
	var counts := {"enemies":0,"bosses":0,"pickup_layers":0}
	_install_latches(stage)
	for child: Node in stage.get_children():
		if child is EnemyMotor:
			var actor := child.get_node_or_null("Actor") as EnemyActor
			if actor == null: continue
			var old := child.get_node_or_null("Presentation")
			if old is PixelPlainsEnemy: continue
			if old != null:
				child.remove_child(old)
				old.queue_free()
			var art := PixelPlainsEnemy.new()
			art.name = "Presentation"
			art.actor = actor
			child.add_child(art)
			counts.enemies += 1
		elif child is PlainsStageVisual:
			child.set_pixel_style(true)
			counts.pickup_layers += 1
		for presentation: Node in child.get_children():
			if presentation is BellstriderPresentation or presentation is WindkeeperPresentation:
				presentation.pixel_style = true
				presentation.queue_redraw()
				counts.bosses += 1
	return counts

static func _install_latches(node: Node) -> void:
	if node is ShotLatch: node.refresh_pixel_presentation()
	for child: Node in node.get_children(): _install_latches(child)

