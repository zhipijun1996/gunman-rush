class_name DamageResult
extends RefCounted

var request: DamageRequest
var health: ActorResourceSnapshot
var lethal := false
var hp_lost := 0.0
var barrier_absorbed := 0.0
var blocked := false
var rescued := false

