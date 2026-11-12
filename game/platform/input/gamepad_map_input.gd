class_name GamepadMapInput
extends RefCounted
## A trigger's companion digital event must never open a modal over its jump.
var _epoch:=-1
var _pending:Dictionary={}
func requested(event:InputEvent,profile:InputProfile,epoch:int,trigger_active:bool)->bool:
 if epoch!=_epoch:_epoch=epoch;_pending.clear()
 if not event is InputEventJoypadButton and not event is InputEventJoypadMotion:return false
 if not _pending.is_empty() and event.device==int(_pending.device) and trigger_active:
  _pending.trigger_seen=true
 var key:=profile.gamepad_binding(event.device,"map")
 if not event is InputEventJoypadButton or key.kind!="button" or event.button_index!=int(key.index):return false
 if event.pressed:
  if _pending.is_empty():_pending={"device":event.device,"trigger_seen":trigger_active}
  return false
 if _pending.is_empty() or int(_pending.device)!=event.device:return false
 var accept:bool=not bool(_pending.trigger_seen) and not trigger_active
 _pending.clear()
 return accept
