extends "res://tests/world/approved_draft_actions.gd"
func fixture(at:Vector2)->void:
 await ticks(30)
 print("SEGMENT_END ",Engine.get_frames_drawn())
 await super.fixture(at)
 print("SEGMENT_BEGIN ",Engine.get_frames_drawn()," ",at)
 await ticks(60)
func check(ok:bool,label:String)->void:
 super.check(ok,label)
 print("SEGMENT_CHECK ",Engine.get_frames_drawn()," ",ok," ",label)
