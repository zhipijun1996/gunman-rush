class_name PlayableWorldSave
extends WorldSaveService
## Gameplay slot for the continuous world. The base service owns native atomic
## writes, browser storage, envelope checksums and recovery of a valid backup.
const SLOT_PATH := "user://playable_world.json"
const START_ROOM := "P01"
const NEW_GAME := {"new_game":true}
# Only these exact document changes preserve the old entry, rest geometry,
# component IDs and saved state from ad15f82b568357e5af474605f647414396aec10b.
const V27_BUNDLE := "2c762e03fadfbea2f993deaf13f5afbbfb0d70392ef388d151329a5da61cc548"
const COMPATIBLE_ROOMS := {
	"G08": { # adds the smith on the already supported catwalk
		"from":"8853526f4fa21374780facbc068a7b525d89734e0b2fc164614e796e8dc5ecd4",
		"to":"7b647d1a769a546cea8c5a7ccb3e72184d976ec845a5a1b161fbf1e45274b06b"
	},
	"P08": { # adds the town's rest station
		"from":"a1e55553b3330031991b822526150823f540bced8da324d2e666bbadd1fea8cb",
		"to":"9062696ebfe7fea11640b685ba7415f0a6191f030610b0046b338adfa58f3b33"
	},
	"Y23": { # labels the existing prize gallery and east floor
		"from":"fbd90cf965df1583831d6162cd47042284f0223343eadcbc778bc63b07947bd7",
		"to":"fe6db0c67f25eb0135cc7ccd23d3cecaae2dcb512f5e4822f7f1abdf94f75615"
	},
}

static func accepts_previous_room(room_id: String, bundle: String, previous: String, current: String) -> bool:
	if bundle!=V27_BUNDLE or not COMPATIBLE_ROOMS.has(room_id): return false
	var pair: Dictionary=COMPATIBLE_ROOMS[room_id]
	return previous==pair.from and current==pair.to

func configure_world(save_path := SLOT_PATH, use_web := OS.has_feature("web"), slot := "local") -> void:
	save_kind = "playable_world"
	key_prefix = "gunman_rush.rebuild.world.v1."
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
