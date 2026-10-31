class_name EnemyFeedback01DeathAudio
extends RefCounted
## Selects timbre for the existing EnemyActor defeat cue; never starts audio.
const STREAM: AudioStream = preload("res://assets/audio/enemy_feedback_01/death_burst.wav")
const OWNER_META := &"enemy_feedback_01_death_audio_owner"
var _owner: WeakRef
var _previous_owner: WeakRef
var _origin: Node
var _previous: Variant
var _had_previous := false
var _fallback: Variant
var _had_fallback := false

func configure(origin: Node) -> void:
	dispose()
	_origin = origin
	_previous_owner = origin.get_meta(OWNER_META) as WeakRef if origin.has_meta(OWNER_META) else null
	_owner = weakref(self)
	origin.set_meta(OWNER_META, _owner)
	var value: Variant = origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META, {})
	var overrides: Dictionary = value.duplicate() if value is Dictionary else {}
	_had_previous = overrides.has(&"enemy_defeat")
	_previous = overrides.get(&"enemy_defeat")
	var predecessor := _previous_owner.get_ref() as EnemyFeedback01DeathAudio if _previous_owner != null else null
	var inherited: bool = predecessor != null and predecessor._origin == origin and _previous == STREAM
	_fallback = predecessor._fallback if inherited else _previous
	_had_fallback = predecessor._had_fallback if inherited else _had_previous
	overrides[&"enemy_defeat"] = STREAM
	origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META, overrides)

func dispose() -> void:
	if is_instance_valid(_origin) and _origin.get_meta(OWNER_META, null) == _owner:
		var previous := _previous_owner.get_ref() as EnemyFeedback01DeathAudio if _previous_owner != null else null
		var predecessor_live: bool = previous != null and previous._origin == _origin
		var value: Variant = _origin.get_meta(GameAudio.CUE_STREAM_OVERRIDES_META, {})
		if value is Dictionary and value.get(&"enemy_defeat") == STREAM:
			var overrides: Dictionary = value.duplicate()
			if predecessor_live and _had_previous: overrides[&"enemy_defeat"] = _previous
			elif _had_fallback: overrides[&"enemy_defeat"] = _fallback
			else: overrides.erase(&"enemy_defeat")
			if overrides.is_empty(): _origin.remove_meta(GameAudio.CUE_STREAM_OVERRIDES_META)
			else: _origin.set_meta(GameAudio.CUE_STREAM_OVERRIDES_META, overrides)
		if predecessor_live: _origin.set_meta(OWNER_META, _previous_owner)
		else: _origin.remove_meta(OWNER_META)
	_origin = null
	_owner = null
	_previous_owner = null
	_previous = null
	_had_previous = false
	_fallback = null
	_had_fallback = false
