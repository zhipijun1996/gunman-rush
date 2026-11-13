extends SceneTree
func _initialize() -> void: run.call_deferred()
func own(node: Node, scene: Node) -> void:
 for child: Node in node.get_children():child.owner=scene;own(child,scene)
func run() -> void:
 root.size=Vector2i(1280,720)
 var scene: Node2D=load("res://game/presentation/experiments/depth_lab/static_orchard.tscn").instantiate()
 root.add_child(scene)
 while not scene.ready_to_capture:await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://build/static-orchard")
 assert(scene.find_children("*","Node3D",true,false).is_empty())
 assert(root.get_texture().get_image().get_size()==Vector2i(1280,720))
 var image:=root.get_texture().get_image()
 var report:={"renderer":"Godot Node2D / TerrainComposer","viewport":[1280,720],"hero_height_wu":44,"config_sha256":FileAccess.get_sha256("res://config/art/orchard_static.json"),"root_connector_sha256":FileAccess.get_sha256("res://assets/depth_lab_2d/native/root_bank.png"),"terrain_materials":[],"formal_gameplay_verified":false}
 for group:Dictionary in scene.terrain.groups:
  if group.material_id not in report.terrain_materials:report.terrain_materials.append(group.material_id)
 var record:=FileAccess.open("res://build/static-orchard/capture.json",FileAccess.WRITE);record.store_string(JSON.stringify(report,"\t"));record.close()
 assert(image.save_png("res://build/static-orchard/current.png")==OK)
 var frozen:Node=scene.duplicate();frozen.set_script(null);own(frozen,frozen)
 var packed:=PackedScene.new();assert(packed.pack(frozen)==OK);assert(ResourceSaver.save(packed,"res://build/static-orchard/editable.tscn")==OK)
 frozen.free();scene.queue_free();await process_frame
 print("STATIC ORCHARD CAPTURE: real 2D frame and editable scene saved");quit()
