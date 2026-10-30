extends SceneTree
func _initialize() -> void: run.call_deferred()
func fields(properties: Array[Dictionary]) -> Array[String]:
	var result: Array[String]=[]
	for property: Dictionary in properties:
		if str(property.name) in ["trail","_visual_trail","_trail"]:result.append(str(property.name))
	return result
func run() -> void:
	var rows: Array=[]
	for path: String in ["res://scripts/combat/player_projectile.gd","res://scripts/art_foundation/pixel_plains_projectile.gd","res://scripts/dev/player_presentation_01/weapon_projectile.gd","res://scripts/underworld_plains/underworld_projectile_visual.gd"]:
		var script:=load(path) as GDScript
		var node:=script.new() as Node2D
		var old:=fields(node.get_property_list())
		var next:=fields(script.get_script_property_list())
		var times: Dictionary={}
		for mode: String in ["node","script"]:
			var start:=Time.get_ticks_usec()
			for i: int in 100:
				fields(node.get_property_list() if mode=="node" else script.get_script_property_list())
			times[mode]=float(Time.get_ticks_usec()-start)/100.0
		rows.append({"path":path,"base":script.get_instance_base_type(),"dynamic":node.has_method(&"_get_property_list"),"node_properties":node.get_property_list().size(),"script_properties":script.get_script_property_list().size(),"old":old,"next":next,"mean_usec":times})
		node.free()
	FileAccess.open("res://build/mobile_web_fps_04/actions/property-inspection-01.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print(JSON.stringify(rows))
	quit.call_deferred()
