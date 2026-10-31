extends Node2D
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color=Color("2233cc")
	bg.size=Vector2(1280,720)
	add_child(bg)
	var actor := PlayerMotor.new()
	var fg := UnderworldForeground.new()
	fg._world=self
	fg._actor=actor
	add_child(fg)
	fg.set_process(false)
	var pic := Image.create(1024,512,false,Image.FORMAT_RGBA8)
	pic.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.centered=false
	sprite.texture=ImageTexture.create_from_image(pic)
	var mat := ShaderMaterial.new()
	mat.shader=UnderworldForeground.ART_SHADER
	mat.set_shader_parameter("art_size",Vector2(1024,512))
	sprite.material=mat
	fg.add_child(sprite)
	fg._protect=[Rect2(320,180,200,160)]
	fg._residents={"fixture":{"sprite":sprite,"bounds":Rect2(64,64,1024,512),"position":Vector2(64,64),"alpha":1.0,"root_gate":1.0,"admitted":true}}
	fg._render_receipt(Vector2.ZERO,Vector2(1280,720))
	for i: int in 3: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var scale := Vector2(image.get_size())/Vector2(1280,720)
	var samples: Dictionary={}
	for key: String in ["inside","left","right"]:
		var point: Vector2={"inside":Vector2(400,250),"left":Vector2(200,250),"right":Vector2(640,250)}[key]*scale
		samples[key]=image.get_pixelv(Vector2i(point)).to_html(false)
	var result := {"scope":"isolated GPU fixture, actual production _render_receipt and unchanged shader; not gameplay","render_target":[image.get_width(),image.get_height()],"samples":samples,"screen_origin":[get_viewport().get_screen_transform().origin.x,get_viewport().get_screen_transform().origin.y],"stretch_scale":[get_viewport().get_stretch_transform().get_scale().x,get_viewport().get_stretch_transform().get_scale().y],"pass":samples.inside=="2233cc" and samples.left!="2233cc" and samples.right!="2233cc"}
	JavaScriptBridge.eval("window.PROBE_RESULT="+JSON.stringify(result))
	actor.free()
