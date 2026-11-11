extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R01")
 var joined:=false
 for child:Node in app.room.get_children():
  if child is UnderworldTerrain:
   var source:=child.core_layer.tile_set.get_source(0) as TileSetAtlasSource
   if source.texture==PlainsMillTerrainMaterial.ATLAS:
    joined=UnderworldTerrain._contains(child.union_pieces,Vector2(2100,400)) and UnderworldTerrain._contains(child.union_pieces,Vector2(2160,400))
 check(joined,"old-well sill and actual boundary wall share one continuous masonry surface")
 var art:=app.room.get_node("RegionalArt")
 var doors:=0
 for node:Node in art.get_children():
  if node is Sprite2D and node.texture.resource_path.ends_with("building_threshold.png"):doors+=1
 check(doors==0,"side passage has no frontal facade or automatic entrance")
 check(app.room.platforms.has(Rect2(2064,32,80,256)),"visible overhead masonry has real collision")
 check(app.room.art_placements.any(func(p:Dictionary)->bool:return p.get("tile_rect",[])==[2064,288,112,96]),"enclosed passage rear wall stops at its ceiling and floor")
 check(app.room.masonry_platform_indices==[9],"main street remains plains material")
 check(5 in app.room.one_way_indices and app.room.platforms[5]==Rect2(1888,384,176,12),"station approach is a thin pass-through deck ending at the actual sill")
 var source:=load("res://game/world/regions/P/rooms/P-R01.tscn").instantiate() as FixedWorldRoom
 var draft:=WorldRoomDraft.extract(source)
 check(WorldRoomDraft.apply(source,draft).is_empty(),"material region survives the existing scene codec")
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
