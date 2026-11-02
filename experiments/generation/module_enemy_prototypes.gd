class_name ModuleEnemyPrototypes
extends Node2D
## Explicit candidate encounter; not part of the formal random pool or save schema.
var actors:Array[EnemyActor]=[]
func setup(lab:ModuleLab)->void:
	for index:int in 2:
		var identity := &"candidate_crosswind_moth" if index else &"candidate_lure_guard"
		var motor := EnemyFactory.create_candidate(identity,&"lab")
		if motor == null:
			push_error("Registered Lab enemy candidate could not be created")
			return
		var actor := motor.get_node("Actor") as EnemyActor
		var receiver := actor.damageable
		motor.get_node("Presentation").free()
		var art:=PrototypeEnemyPresentation.new();art.actor=actor;art.moth=index==1;motor.add_child(art)
		motor.position=Vector2(430+index*360,582-index*147)
		add_child(motor)
		var id:=StringName("candidate_enemy_%s"%index)
		lab.policy.bind_damageable(id,receiver,actor.health)
		actor.bind_encounter(lab.controller,lab.policy,lab.lifetime,id,[])
		var contact:=DemoContactEmitter.new();contact.policy=lab.policy;contact.controller=lab.controller;contact.source_id=id;contact.half_size=actor.definition.collision_size/2;motor.add_child(contact)
		actor.defeated.connect(func(_actor:EnemyActor)->void:contact.enabled=false)
		actors.append(actor)
	var label:=Label.new();label.position=Vector2(190,255);label.add_theme_font_size_override("font_size",15)
	label.text="CANDIDATES / not in formal pool\nGUARD: bait lunge then shoot open recovery, or recoil behind.\nMOTH: read two locked lanes; change height between volleys.\nNo final art / balance / player approval claimed."
	add_child(label)
