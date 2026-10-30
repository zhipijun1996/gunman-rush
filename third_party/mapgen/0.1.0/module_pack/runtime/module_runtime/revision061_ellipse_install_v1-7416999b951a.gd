extends RefCounted
const DEFINITION=preload('revision061_ellipse_definition_v1-fff23a5cee8f.gd')
static func from_raw(raw: Dictionary):
 var d=DEFINITION.new();d.platform_id=StringName(raw.platform_id);d.size=Vector2(raw.size[0],raw.size[1]);d.center=Vector2(raw.ellipse_center[0],raw.ellipse_center[1]);d.radii=Vector2(raw.ellipse_radii[0],raw.ellipse_radii[1]);d.travel_duration=float(raw.ellipse_period);d.dwell_duration=0;d.initial_phase=float(raw.initial_phase);d.start=Vector2(raw.start[0],raw.start[1]);d.finish=Vector2(raw.finish[0],raw.finish[1]);return d
static func install(definition: PlatformingModuleDefinition,data: Dictionary) -> void:
 for i: int in data.get('moving_platforms',[]).size():
  var raw: Dictionary=data.moving_platforms[i]
  if raw.get('trajectory_kind','')=='clockwise_ellipse/v1':definition.ferries[i]=from_raw(raw)
