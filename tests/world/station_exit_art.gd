extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R01")
 var joined:=false
 for child:Node in app.room.find_children("*", "UnderworldTerrain", true, false):
  if child is UnderworldTerrain:
   var source:=child.core_layer.tile_set.get_source(0) as TileSetAtlasSource
   if source.texture==TerrainMaterialRegistry.appearance("mill_masonry").tileset.get_source(0).texture:
    joined=UnderworldTerrain._contains(child.union_pieces,Vector2(2160,400))
 check(joined,"actual boundary wall keeps its masonry surface")
 var art:=app.room.get_node("RegionalArt")
 var doors:=0
 for node:Node in art.get_children():
  if node is Sprite2D and node.texture.resource_path.ends_with("building_threshold.png"):doors+=1
 check(doors==0,"side passage has no frontal facade or automatic entrance")
 check(not app.room.platforms.has(Rect2(2064,32,80,256)),"no added tower volume protrudes into the approach")
 check(app.room.art_placements.any(func(p:Dictionary)->bool:return p.has("tile_rect") and FixedWorldProvider.rect(p.tile_rect)==Rect2(2144,288,32,96)),"enclosed passage rear wall stops at its ceiling and floor")
 check(app.room.masonry_platform_indices.is_empty(),"main street remains plains material")
 check(5 in app.room.one_way_indices and app.room.platforms[5]==Rect2(1888,384,256,12),"station approach is a thin pass-through deck ending at the actual sill")
 var source:=load("res://game/world/regions/P/rooms/P-R01.tscn").instantiate() as FixedWorldRoom
 var draft:=WorldRoomDocument.read(source.document_ref)
 source.free()
 var restored:=WorldRoomDocument.instantiate(draft)
 source=restored.get("room")
 check(not restored.has("error"),"material region survives the existing scene codec")
 check(source.art_placements.any(func(p:Dictionary)->bool:return p.has("masonry_region")),"authored boundary material remains in room data")
 source.free()
 var state:=app.state.value.duplicate(true)
 state.flags.append("clockheart_briefed");app.state.commit(state,app.state.revision);app.room.refresh_doors(app.state,app.content)
 await fixture(Vector2(2000,366))
 app.controller.router.request_action(&"drop_through");await ticks(25)
 check(app.player.position.y>404,"station approach accepts the formal drop-through action")
 await ticks(140)
 check(app.player.is_on_floor() and absf(app.player.position.y-1198)<6,"drop from approach returns safely to the lower town landing")
 await WorldAudioLifecycle.drain_world(app)
 print("STATION EXIT ART: ",failures," failures");quit(failures)
