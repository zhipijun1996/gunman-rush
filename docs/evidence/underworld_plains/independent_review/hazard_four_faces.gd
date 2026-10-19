extends SceneTree
class MaterialSample extends Node2D:
 var face:=0
 var hosts:Array[Rect2]=[]
 var thorn:PlatformThornDefinition
 func _draw()->void:UnderworldHazardTiles.draw_surface(self,thorn,hosts)
func _initialize()->void:run.call_deferred()
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(640,360);view.transparent_bg=false;view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var hosts:Array[Rect2]=[Rect2(70,70,180,64),Rect2(390,70,180,64),Rect2(70,230,180,64),Rect2(390,230,180,64)]
 for i:int in 4:
  var terrain:=UnderworldTerrain.build([hosts[i]]);terrain.z_index=-10;view.add_child(terrain)
  var art:=MaterialSample.new();art.face=i;art.hosts=[hosts[i]];art.thorn=PlatformThornDefinition.new();art.thorn.face=i;art.thorn.start_offset=16;art.thorn.length=40;art.thorn.depth=24;view.add_child(art)
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 var out:="res://build/underworld_plains/independent_review/hazard_four_faces.png"
 view.get_texture().get_image().save_png(out)
 print("INDEPENDENT_HAZARD_GPU four_faces=4 source=actualUnderworldTerrain+actualUnderworldHazardTiles")
 view.queue_free();await process_frame;await process_frame;quit(0)
