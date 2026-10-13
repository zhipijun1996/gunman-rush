class_name ModuleEnemyPrototypes
extends Node2D
## Explicit candidate encounter; not part of the formal random pool or save schema.
var actors:Array[EnemyActor]=[]
func setup(lab:ModuleLab)->void:
	for index:int in 2:
		var motor:EnemyMotor=preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
		var actor:EnemyActor=motor.get_node("Actor")
		actor.definition=load("res://resources/enemies/plains_sentry.tres" if index else "res://resources/enemies/plains_charger.tres").duplicate(true)
		actor.definition.stable_id=&"candidate_crosswind_moth" if index else &"candidate_lure_guard"
		actor.definition.aerial=index==1
		actor.definition.collision_size=Vector2(32,36)
		actor.definition.patrol_half_width=120
		actor.definition.telegraph_duration=.8
		actor.definition.attack_duration=1.1 if index else .65
		actor.definition.recovery_duration=1.1
		actor.definition.activation_range=360
		var receiver:=PrototypeEnemyDamageable.new()
		receiver.guard=index==0
		motor.get_node("Damageable").free();receiver.name="Damageable";motor.add_child(receiver);actor.damageable=receiver
		motor.get_node("Presentation").free()
		var art:=PrototypeEnemyPresentation.new();art.actor=actor;art.moth=index==1;motor.add_child(art)
		motor.position=Vector2(430+index*360,582-index*147)
		add_child(motor)
		var id:=StringName("candidate_enemy_%s"%index)
		lab.policy.bind_damageable(id,receiver,actor.health)
		actor.attack_behavior=PrototypeMothBehavior.new() if index else EnemyAttackBehavior.new()
		actor.add_child(actor.attack_behavior)
		actor.attack_behavior.configure(actor,lab.controller,lab.policy,lab.lifetime,id,[])
		var contact:=DemoContactEmitter.new();contact.policy=lab.policy;contact.controller=lab.controller;contact.source_id=id;contact.half_size=actor.definition.collision_size/2;motor.add_child(contact)
		actor.defeated.connect(func(_actor:EnemyActor)->void:contact.enabled=false)
		actors.append(actor)
	var label:=Label.new();label.position=Vector2(190,255);label.add_theme_font_size_override("font_size",15)
	label.text="CANDIDATES / not in formal pool\nGUARD: bait lunge then shoot open recovery, or recoil behind.\nMOTH: read two locked lanes; change height between volleys.\nNo final art / balance / player approval claimed."
	add_child(label)
