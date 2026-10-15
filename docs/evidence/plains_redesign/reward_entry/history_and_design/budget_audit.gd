extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var prior=load("res://build/plains_redesign/reward_entry/baseline_generator.gd").new()
 var current:=PlainsRegionGenerator.new();var tuning:=PlayerTuning.load_default()
 var report:Dictionary={"scope":"actual generated 100-map pair; positions only content delta, not physics/fun claim","cases":[],"failures":[]}
 for map_index:int in [1,2]:
  for i:int in 50:
   var seed_value:=PlainsRegionCampaign.seed_for("two-map-corpus/%s"%i,map_index)
   var a:Dictionary=prior.generate(seed_value,tuning,false,"","intro" if map_index==1 else "advanced").manifest
   var b:Dictionary=current.generate(seed_value,tuning,false,"","intro" if map_index==1 else "advanced").manifest
   var moved:Array=[]
   for index:int in a.enemies.size():
    if a.enemies[index].position!=b.enemies[index].position:moved.append({"id":a.enemies[index].id,"behavior":a.enemies[index].behavior_id,"from":a.enemies[index].position,"to":b.enemies[index].position})
    var enemy:Dictionary=b.enemies[index].duplicate(true);enemy.position=a.enemies[index].position
    if enemy!=a.enemies[index]:report.failures.append("nonposition enemy change "+seed_value)
    b.enemies[index].position=a.enemies[index].position
   if a.enemies.size()!=b.enemies.size():report.failures.append("enemy budget changed "+seed_value)
   a.erase("manifest_hash");b.erase("manifest_hash")
   if a!=b:report.failures.append("other manifest change "+seed_value)
   report.cases.append({"seed":seed_value,"map_index":map_index,"enemy_count":a.enemies.size(),"moved":moved})
 var f:=FileAccess.open("res://build/plains_redesign/reward_entry/budget_audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(report));f.close()
 print("REWARD ENTRY CONSERVATION: ",report.cases.size()," maps, ",report.failures.size()," failures")
 quit(0 if report.failures.is_empty() else 1)
