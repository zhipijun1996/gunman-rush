extends RefCounted
## Sample the same terrain rays and attenuation that drive the light flowers.
static func update(zone: Node2D, bounds: Rect2, image: Image, texture: ImageTexture, had_lights: bool) -> bool:
	var room := zone.get_parent() as FixedWorldRoom
	if room == null: return false
	var network := WorldLightNetwork.of(room)
	network.controller = zone.controller
	var pixel_size := bounds.size/Vector2(image.get_size())
	var lights := network.active_sources(["local_light","equipped_light"])
	if lights.is_empty():
		if not had_lights: return false
		image.fill(Color.BLACK)
		texture.update(image)
		return false
	var dirty := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var at := zone.to_global(bounds.position+(Vector2(x,y)+Vector2(0.5,0.5))*pixel_size)
			var illumination := network.sample_sources(at,lights)
			var value := roundi(illumination*255)
			if image.get_pixel(x,y).r8 != value:
				image.set_pixel(x,y,Color8(value,0,0)); dirty = true
	if dirty: texture.update(image)
	return true
