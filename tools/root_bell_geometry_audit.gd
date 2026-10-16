extends SceneTree
func _initialize() -> void:
 var rows: Array = []
 var corpus := ["v3-root-bell-pilot-%s", "plains-redesign-%s"]
 for prefix: String in corpus:
  for i: int in 10:
   for map_index: int in [1,2]:
    var root := prefix % i
    var g := PlainsRegionGenerator.new()
    g.root_bell_mode = "v2"
    var generated := g.generate(PlainsRegionCampaign.seed_for(root,map_index),PlayerTuning.load_default(),false,"","intro" if map_index==1 else "advanced")
    for node: Dictionary in generated.manifest.nodes:
     if node.module_id != "region_connection":continue
     var facts := PlainsRootBellEncounterV2.inspect(generated.manifest,node,PlainsRegionGenerator.definition)
     var has_guard: bool = generated.manifest.enemies.any(func(e: Dictionary)->bool:return e.get("area","")==node.id and str(e.id).begins_with("plains/enemy/lane/"))
     rows.append({"root_seed":root,"map_index":map_index,"module":node.id,"guard":has_guard,"facts":facts})
 var file := FileAccess.open("res://build/production_repair/ecology/geometry_audit.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "));file.close()
 print("ECOLOGY GEOMETRY AUDIT: ",rows.size())
 quit()
