extends RefCounted
## Prepare the slow-aim overlay before its first visible frame.
## Temporary isolated render work only; no registry, gameplay state or cache.

static func prepare_focus(owner: Node, source: ShaderMaterial, tint: Color, opacity: float, edge_width: float) -> void:
	var viewport := _viewport("FocusShaderWarmup")
	if viewport == null: return
	var quad := FocusQuad.new()
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("strength", 1.0)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("opacity", clampf(opacity, 0.0, 1.0))
	material.set_shader_parameter("edge_width", clampf(edge_width, 0.01, 0.49))
	quad.material = material
	viewport.add_child(quad)
	_submit(owner, viewport)

static func _viewport(view_name: String) -> SubViewport:
	if DisplayServer.get_name() == "headless": return null
	var viewport := SubViewport.new()
	viewport.name = view_name
	viewport.size = Vector2i(16, 16)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return viewport

static func _submit(owner: Node, viewport: SubViewport) -> void:
	owner.add_child(viewport)
	# Same bounded cleanup as Focus V3; global post-draw is not a per-view receipt.
	RenderingServer.frame_post_draw.connect(viewport.queue_free, CONNECT_ONE_SHOT)

# No Controls: existing Foreground UI protection must not track warmup geometry.
class FocusQuad extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 16, 16), Color.WHITE)
