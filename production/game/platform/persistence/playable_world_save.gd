class_name PlayableWorldSave
extends WorldSaveService
## Gameplay slot for the continuous world. The base service owns native atomic
## writes, browser storage, envelope checksums and recovery of a valid backup.
const SLOT_PATH := "user://playable_world_v29.json"
const START_ROOM := "P01"
const NEW_GAME := {"new_game":true}
func configure_world(save_path := SLOT_PATH, use_web := OS.has_feature("web"), slot := "local") -> void:
	save_kind = "playable_world"
	key_prefix = "gunman_rush.rebuild.world.v29."
	configure(save_path,use_web,slot)

func accepts_payload(payload: Dictionary) -> bool:
	if payload==NEW_GAME: return true
	if payload_validator.is_valid(): return super.accepts_payload(payload)
	# Startup chooses the document before its OrdinaryRoomSession exists.
	return FixedWorldState.new().valid(payload)

func load_profile() -> Dictionary:
	var result := super.load_profile()
	if result.get("accepted",false):
		blocked = false
		if result.payload==NEW_GAME:
			return {"accepted":true,"payload":{},"revision":0}
		if not result.payload.is_empty() and result.get("envelope_content")!=result.payload.get("content_version"):
			blocked=true
			status="room_content_save_version_mismatch"
			return {"accepted":false,"reason":status}
	return result

func startup_room() -> Dictionary:
	var saved := load_profile()
	if not saved.accepted: return {"ok":false,"error":saved.reason}
	var exists := not (saved.payload as Dictionary).is_empty()
	return {"ok":true,"has_save":exists,"room":saved.payload.room if exists else START_ROOM}

## Called after explicit new-game confirmation. Replace the active slot with
## a durable fresh-start marker. Failure leaves the previous game in place.
func reset_world() -> bool:
	if path.is_empty() or not profile_id.is_valid_identifier(): return false
	var previous_version := content_version
	var previous_block := blocked
	content_version = "playable_world_new_game".sha256_text()
	blocked = false
	var replaced := commit(NEW_GAME,1)
	content_version = previous_version
	if not replaced: blocked = previous_block
	return replaced
