extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R01")
 var joined:=false
 for child:Node in app.room.get_children():
  if child is UnderworldTerrain:
   var source:=child.core_layer.tile_set.get_source(0) as TileSetAtlasSource
   if source.texture==PlainsMillTerrainMaterial.ATLAS:
    joined=UnderworldTerrain._contains(child.union_pieces,Vector2(2000,400)) and UnderworldTerrain._contains(child.union_pieces,Vector2(2160,400))
 check(joined,"old-well bank and actual boundary wall share one continuous masonry surface")
 var art:=app.room.get_node("RegionalArt")
 var doors:=0
 for node:Node in art.get_children():
  if node is Sprite2D and node.texture.resource_path.ends_with("building_threshold.png"):doors+=1
 check(doors==1,"one doorway, no extra automatic entrance or floating apron")
 check(app.room.masonry_platform_indices==[5],"main street remains plains material")
 var source:=load("res://game/world/regions/P/rooms/P-R01.tscn").instantiate() as FixedWorldRoom
 var draft:=WorldRoomDraft.extract(source)
 check(WorldRoomDraft.apply(source,draft).is_empty(),"material region survives the existing scene codec")
 check(source.art_placements.any(func(p:Dictionary)->bool:return p.has("masonry_region")),"authored boundary material remains in room data")
 source.free();await WorldAudioLifecycle.drain_world(app)
 print("STATION EXIT ART: ",failures," failures");quit(failures)
