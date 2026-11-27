class_name WorldSaveService
extends MetaSaveService
## Independent slot and envelope. Meta/Run payloads are never read or converted.
const WORLD_SCHEMA := 2
var content_version := ""
var save_kind := "ordinary_room"
var key_prefix := "gunman_rush.rebuild.room.v1."
var payload_validator: Callable

func make_envelope(payload: Dictionary, revision: int) -> Dictionary:
	return {"schema_version":WORLD_SCHEMA,"kind":save_kind,"content_version":content_version,
		"profile_id":profile_id,"profile_revision":revision,"payload":payload.duplicate(true)}

func web_storage_key() -> String:
	return key_prefix + profile_id

func _decode(encoded: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(encoded) != OK: return {"accepted":false,"reason":"invalid_save"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return {"accepted":false,"reason":"invalid_save"}
	if parsed.get("kind") != save_kind or parsed.get("profile_id") != profile_id:
		return {"accepted":false,"reason":"profile_mismatch"}
	if parsed.get("schema_version") != WORLD_SCHEMA:
		return {"accepted":false,"reason":"future_schema"}
	if not parsed.get("payload") is Dictionary or not parsed.get("profile_revision") is float or float(parsed.profile_revision) < 1 or floorf(parsed.profile_revision) != parsed.profile_revision:
		return {"accepted":false,"reason":"invalid_save"}
	var unsigned: Dictionary = parsed.duplicate(true)
	unsigned.erase("checksum")
	if parsed.get("checksum") != canonical_json(unsigned).sha256_text():
		return {"accepted":false,"reason":"invalid_save"}
	if str(parsed.get("content_version", "")).length() != 64:
		return {"accepted":false,"reason":"future_content"}
	if not accepts_payload(parsed.payload):
		return {"accepted":false,"reason":"invalid_world_payload"}
	return {"accepted":true,"payload":parsed.payload,"revision":int(parsed.profile_revision),"envelope_content":parsed.content_version,"content_changed":parsed.content_version != content_version}

func accepts_payload(payload: Dictionary) -> bool:
	return not payload_validator.is_valid() or bool(payload_validator.call(payload))
